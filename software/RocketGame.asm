; ============================================================
; Person 5 - Rocket Game: Main Loop & Integration
;
; Push-your-luck survival rocket game for SCOMP, driven by our
; pausable countdown timer peripheral (0x070 / 0x071).
;
; This is the merged build. It contains:
;   Person 5 - state machine, pacing, integration
;   Person 1 - timer API                 (0x070 / 0x071)
;   Person 2 - 30-step payout table + crash cutoff
;   Person 3 - switch edge detection / pause interlock
;   Person 4 - LED thermometer + HEX displays
;
; Person 5 integration changes:
;   1. Pacing: the payout index now advances one step every 2
;      deciseconds (60 ticks / 30 steps) instead of every loop
;      iteration. LastStepTick anchors the last step; a new step
;      is taken once the timer has dropped 2 ticks below it.
;      The loop keeps polling switches while it waits, so SW1/SW2
;      stay responsive between steps.
;   2. Finished Person 2's Table_StepNext indexed fetch with a
;      compare cascade (SCOMP has no indexed addressing) and
;      pinned the index at 29 so a round cannot run off the table.
;   3. Inputs_CheckPauseToggle writes the timer port directly
;      instead of CALLing Timer_Pause/Timer_Resume. SCOMP keeps a
;      single return register (no call stack), so a CALL made from
;      inside another CALLed routine would return to the wrong
;      instruction and hang.
;   4. Person 2's payout cascade and LFSR crash cutoff are taken
;      verbatim from Person2_MultiplierTable.asm (Tony's version).
;   5. Person 4's animation delays are CALLed from inside the
;      animations, so the state machine tail-jumps into an
;      animation instead of CALLing it. Same single-return-register
;      rule as (3): a nested CALL would lose the way back to the
;      main loop.
;
; Build: scasm RocketGame.asm   ->  RocketGame.mif
; ============================================================

        ORG     0

; Init bankroll, stake, and round state
MainInit:
        LOAD    InitialBank
        STORE   BankedCredits
        LOAD    InitialStake
        STORE   CurrentStake
        LOAD    P5_Zero
        STORE   GamePaused
        STORE   CrashFlag
        STORE   CurrentValueIdx
        STORE   CurrentMoney
        STORE   LastStepTick
        CALL    Timer_LoadDuration

; Wait for SW0 press to launch
WaitLaunch:
        LOAD    BankedCredits
        OUT     Hex2_3
        LOAD    P5_Zero
        OUT     LEDs

        CALL    Inputs_Poll
        CALL    Inputs_CheckStart
        JZERO   WaitLaunch

        ; Launch!
        CALL    Table_Init
        CALL    Table_GenCrashThreshold
        CALL    Timer_LoadDuration
        LOAD    DefaultDuration
        STORE   LastStepTick
        CALL    Timer_Start

        ; Show the loaded clock and the first payout right away
        CALL    Timer_PollStatus
        CALL    Display_UpdateHEX
        CALL    Display_UpdateLEDMoney

; Running loop
GameLoop:
        CALL    Inputs_Poll
        CALL    Inputs_CheckPauseToggle

        ; If paused, don't advance
        LOAD    GamePaused
        JPOS    GameLoop

        ; Check cash out
        CALL    Inputs_CheckCashOut
        JPOS    StateCashOut

        ; Read timer peripheral status
        CALL    Timer_PollStatus

        ; Timeout check (DONE bit set)
        LOAD    TimerDoneFlag
        JPOS    StateBustTimeout

        ; Random crash check
        CALL    Table_CheckCrash
        LOAD    CrashFlag
        JPOS    StateBustCrash

        ; Pacing: step once the timer is 2 ticks below the anchor
        LOAD    LastStepTick
        SUB     PaceInterval
        SUB     RemainingTicks
        JPOS    PaceStep
        JZERO   PaceStep
        JUMP    GameLoop

PaceStep:
        CALL    Table_StepNext
        LOAD    RemainingTicks
        STORE   LastStepTick
        CALL    Display_UpdateLEDMoney
        CALL    Display_UpdateHEX
        JUMP    GameLoop

; Cash out: bank profit and freeze timer
StateCashOut:
        CALL    Timer_Pause
        LOAD    BankedCredits
        ADD     CurrentMoney
        STORE   BankedCredits
        JUMP    Display_AnimCashOut    ; animation jumps back to StateReplay

; Bust: forfeit stake and freeze timer
StateBustTimeout:
StateBustCrash:
        CALL    Timer_Pause
        LOAD    BankedCredits
        SUB     CurrentStake
        STORE   BankedCredits
        JUMP    Display_AnimCrash      ; animation jumps to BustAfterCrash

BustAfterCrash:
        ; Check if bankrupt
        LOAD    BankedCredits
        JPOS    StateReplay
        JZERO   StateBankrupt
        JUMP    StateBankrupt

; Wait for SW3 to start new round
StateReplay:
        CALL    Inputs_Poll
        CALL    Inputs_CheckReset
        JZERO   StateReplay

        LOAD    P5_Zero
        STORE   GamePaused
        CALL    Timer_Reset
        JUMP    WaitLaunch

; Out of money
StateBankrupt:
        CALL    Display_AnimBankrupt
Halt:
        JUMP    Halt

; Shared RAM variables (team contract - do not rename)
BankedCredits:   DW     100
CurrentStake:    DW     10
CurrentValueIdx: DW     0
CurrentMoney:    DW     0
CrashThreshold:  DW     24
RemainingTicks:  DW     0
TimerDoneFlag:   DW     0
GamePaused:      DW     0
CrashFlag:       DW     0
PRNG_Seed:       DW     &HACE1

InitialBank:     DW     100
InitialStake:    DW     10

; Person 5 pacing / integration constants
LastStepTick:    DW     0       ; Timer value at the last payout step
PaceInterval:    DW     2       ; Deciseconds per step (60 ticks / 30)
P5_Zero:         DW     0

; ============================================================
; Person 1 - Timer API Interface
;
;   0x070 (TimerValue):   write loads duration (in 0.1s ticks)
;                         read gets remaining deciseconds
;   0x071 (TimerControl): write 0 = pause, 1 = start, 2 = reset
;                         read bit 0 = running, bit 1 = done
; ============================================================

TimerValue:      EQU     &H070
TimerControl:    EQU     &H071

TimerDoneMask:   DW      &H0002
TimerRunMask:    DW      &H0001

CmdPause:        DW      0
CmdStart:        DW      1
CmdReset:        DW      2

DefaultDuration: DW      60      ; 6.0 seconds (60 deciseconds)

; Load round duration into 0x070 (resets timer and clears DONE)
Timer_LoadDuration:
        LOAD    DefaultDuration
        OUT     TimerValue
        RETURN

; Start countdown
Timer_Start:
        LOAD    CmdStart
        OUT     TimerControl
        RETURN

; Pause countdown (stops hardware tick counter)
Timer_Pause:
        LOAD    CmdPause
        OUT     TimerControl
        RETURN

; Resume countdown
Timer_Resume:
        LOAD    CmdStart
        OUT     TimerControl
        RETURN

; Reset to loaded duration
Timer_Reset:
        LOAD    CmdReset
        OUT     TimerControl
        RETURN

; Read live time into RemainingTicks and check if timer hit 0
Timer_PollStatus:
        IN      TimerValue
        STORE   RemainingTicks

        IN      TimerControl
        AND     TimerDoneMask
        JZERO   TimerNotDone
        LOAD    P1_One
        STORE   TimerDoneFlag
        RETURN

TimerNotDone:
        LOAD    P1_Zero
        STORE   TimerDoneFlag
        RETURN

P1_Zero: DW      0
P1_One:  DW      1

; ============================================================
; Person 2 - Multiplier Table & Crash Engine
;
; Manages the 30-step payout table and random crash check.
; SCOMP doesn't have multiply/divide instructions, so all 30
; payout values are precomputed in RAM to avoid runtime math.
; ============================================================
; Reset table index to 0 and load starting money
Table_Init:
        LOAD    P2_Zero
        STORE   CurrentValueIdx
        STORE   CrashFlag
        LOAD    Value_00
        STORE   CurrentMoney
        RETURN

; Pick a cutoff from 8 through 30 once per launch. Since payouts stop
; at index 29, a cutoff of 30 lets the hardware timer end the round.
Table_GenCrashThreshold:
        LOAD    PRNG_Seed
        JZERO   P2_RestoreSeed
        JUMP    P2_AdvanceLfsr

P2_RestoreSeed:
        LOAD    P2_DefaultSeed ; zero is a locked state for the LFSR

P2_AdvanceLfsr:
        ; Left-shift Galois LFSR. Apply feedback if the old MSB was set.
        JNEG    P2_ApplyFeedback
        SHIFT   1
        JUMP    P2_SampleLfsr

P2_ApplyFeedback:
        SHIFT   1
        XOR     P2_LfsrMask

P2_SampleLfsr:
        STORE   PRNG_Seed
        AND     P2_SampleMask
        SUB     P2_SampleCount
        JNEG    P2_AcceptSample
        JUMP    Table_GenCrashThreshold ; discard 23..31, then draw again

P2_AcceptSample:
        ADD     P2_SampleCount
        ADD     P2_MinCrash
        STORE   CrashThreshold
        RETURN

; Check if current step reached the crash threshold
Table_CheckCrash:
        LOAD    CurrentValueIdx
        SUB     CrashThreshold
        JPOS    SetCrashed
        JZERO   SetCrashed
        RETURN

SetCrashed:
        LOAD    P2_One
        STORE   CrashFlag
        RETURN

; Advance one step and hold the final payout at index 29.
Table_StepNext:
        LOAD    CurrentValueIdx
        SUB     P2_LastIndex
        JNEG    P2_AdvanceStep
        RETURN

P2_AdvanceStep:
        LOAD    CurrentValueIdx
        ADD     P2_One
        STORE   CurrentValueIdx

        ; Lab 8 SCOMP has no indirect load. Count down the index to
        ; select a direct load from the payout table.
        SUB     P2_One
        JZERO   P2_Pay01
        SUB     P2_One
        JZERO   P2_Pay02
        SUB     P2_One
        JZERO   P2_Pay03
        SUB     P2_One
        JZERO   P2_Pay04
        SUB     P2_One
        JZERO   P2_Pay05
        SUB     P2_One
        JZERO   P2_Pay06
        SUB     P2_One
        JZERO   P2_Pay07
        SUB     P2_One
        JZERO   P2_Pay08
        SUB     P2_One
        JZERO   P2_Pay09
        SUB     P2_One
        JZERO   P2_Pay10
        SUB     P2_One
        JZERO   P2_Pay11
        SUB     P2_One
        JZERO   P2_Pay12
        SUB     P2_One
        JZERO   P2_Pay13
        SUB     P2_One
        JZERO   P2_Pay14
        SUB     P2_One
        JZERO   P2_Pay15
        SUB     P2_One
        JZERO   P2_Pay16
        SUB     P2_One
        JZERO   P2_Pay17
        SUB     P2_One
        JZERO   P2_Pay18
        SUB     P2_One
        JZERO   P2_Pay19
        SUB     P2_One
        JZERO   P2_Pay20
        SUB     P2_One
        JZERO   P2_Pay21
        SUB     P2_One
        JZERO   P2_Pay22
        SUB     P2_One
        JZERO   P2_Pay23
        SUB     P2_One
        JZERO   P2_Pay24
        SUB     P2_One
        JZERO   P2_Pay25
        SUB     P2_One
        JZERO   P2_Pay26
        SUB     P2_One
        JZERO   P2_Pay27
        SUB     P2_One
        JZERO   P2_Pay28

P2_Pay29: LOAD  Value_29
          JUMP  P2_StorePayout
P2_Pay28: LOAD  Value_28
          JUMP  P2_StorePayout
P2_Pay27: LOAD  Value_27
          JUMP  P2_StorePayout
P2_Pay26: LOAD  Value_26
          JUMP  P2_StorePayout
P2_Pay25: LOAD  Value_25
          JUMP  P2_StorePayout
P2_Pay24: LOAD  Value_24
          JUMP  P2_StorePayout
P2_Pay23: LOAD  Value_23
          JUMP  P2_StorePayout
P2_Pay22: LOAD  Value_22
          JUMP  P2_StorePayout
P2_Pay21: LOAD  Value_21
          JUMP  P2_StorePayout
P2_Pay20: LOAD  Value_20
          JUMP  P2_StorePayout
P2_Pay19: LOAD  Value_19
          JUMP  P2_StorePayout
P2_Pay18: LOAD  Value_18
          JUMP  P2_StorePayout
P2_Pay17: LOAD  Value_17
          JUMP  P2_StorePayout
P2_Pay16: LOAD  Value_16
          JUMP  P2_StorePayout
P2_Pay15: LOAD  Value_15
          JUMP  P2_StorePayout
P2_Pay14: LOAD  Value_14
          JUMP  P2_StorePayout
P2_Pay13: LOAD  Value_13
          JUMP  P2_StorePayout
P2_Pay12: LOAD  Value_12
          JUMP  P2_StorePayout
P2_Pay11: LOAD  Value_11
          JUMP  P2_StorePayout
P2_Pay10: LOAD  Value_10
          JUMP  P2_StorePayout
P2_Pay09: LOAD  Value_09
          JUMP  P2_StorePayout
P2_Pay08: LOAD  Value_08
          JUMP  P2_StorePayout
P2_Pay07: LOAD  Value_07
          JUMP  P2_StorePayout
P2_Pay06: LOAD  Value_06
          JUMP  P2_StorePayout
P2_Pay05: LOAD  Value_05
          JUMP  P2_StorePayout
P2_Pay04: LOAD  Value_04
          JUMP  P2_StorePayout
P2_Pay03: LOAD  Value_03
          JUMP  P2_StorePayout
P2_Pay02: LOAD  Value_02
          JUMP  P2_StorePayout
P2_Pay01: LOAD  Value_01

P2_StorePayout:
        STORE   CurrentMoney
        RETURN

P2_DefaultSeed: DW      &HACE1
P2_LfsrMask:    DW      &H002D
P2_SampleMask:  DW      &H001F
P2_SampleCount: DW      23
P2_MinCrash:    DW      8
P2_Zero:        DW      0
P2_One:         DW      1
P2_LastIndex:   DW      29

; Precomputed 30-step payout table (wager = 10, climbs to 500)
Value_00: DW  10
Value_01: DW  11
Value_02: DW  12
Value_03: DW  14
Value_04: DW  16
Value_05: DW  18
Value_06: DW  21
Value_07: DW  24
Value_08: DW  28
Value_09: DW  32
Value_10: DW  37
Value_11: DW  43
Value_12: DW  50
Value_13: DW  58
Value_14: DW  67
Value_15: DW  77
Value_16: DW  88
Value_17: DW  101
Value_18: DW  115
Value_19: DW  131
Value_20: DW  149
Value_21: DW  169
Value_22: DW  191
Value_23: DW  216
Value_24: DW  244
Value_25: DW  275
Value_26: DW  310
Value_27: DW  350
Value_28: DW  400
Value_29: DW  500

; ============================================================
; Person 3 - Switch Controls & Debounce
;
; Reads switch inputs from address 0x000:
;   SW0: Launch / Start
;   SW1: Cash Out
;   SW2: Pause / Resume (writes 0 / 1 to the timer control port)
;   SW3: Replay / New Round
; ============================================================

Switches:        EQU     &H000

SW0_StartMask:   DW      &H0001
SW1_CashOutMask: DW      &H0002
SW2_PauseMask:   DW      &H0004
SW3_ResetMask:   DW      &H0008

PrevSwitches:    DW      0
CurrSwitches:    DW      0
NewPresses:      DW      0

; Poll switches and detect rising edges so held switches don't repeat
Inputs_Poll:
        IN      Switches
        STORE   CurrSwitches

        LOAD    CurrSwitches
        JZERO   ClearEdge

        LOAD    PrevSwitches
        JPOS    NoEdge

        LOAD    CurrSwitches
        STORE   PrevSwitches
        STORE   NewPresses
        RETURN

ClearEdge:
        LOAD    P3_Zero
        STORE   PrevSwitches
        STORE   NewPresses
        RETURN

NoEdge:
        LOAD    P3_Zero
        STORE   NewPresses
        RETURN

; Returns AC = 1 if Cash Out was pressed and game is not paused
Inputs_CheckCashOut:
        LOAD    GamePaused
        JPOS    BlockCashOut

        LOAD    NewPresses
        AND     SW1_CashOutMask
        JPOS    HitCashOut
        LOAD    P3_Zero
        RETURN

HitCashOut:
        LOAD    P3_One
        RETURN

BlockCashOut:
        LOAD    P3_Zero
        RETURN

; Handles SW2 pause/resume toggle.
; The timer port is written here directly: Timer_Pause/Timer_Resume
; cannot be CALLed from inside this routine because SCOMP has only
; one return register and no call stack.
Inputs_CheckPauseToggle:
        LOAD    NewPresses
        AND     SW2_PauseMask
        JZERO   NoPauseChange

        LOAD    GamePaused
        JZERO   PauseNow

        ; Unpause:
        LOAD    P3_Zero
        STORE   GamePaused
        LOAD    CmdStart
        OUT     TimerControl
        RETURN

PauseNow:
        LOAD    P3_One
        STORE   GamePaused
        LOAD    CmdPause
        OUT     TimerControl
        RETURN

NoPauseChange:
        RETURN

; Check SW0 (Launch)
Inputs_CheckStart:
        LOAD    NewPresses
        AND     SW0_StartMask
        JPOS    StartFired
        LOAD    P3_Zero
        RETURN

StartFired:
        LOAD    P3_One
        RETURN

; Check SW3 (New round / reset)
Inputs_CheckReset:
        LOAD    NewPresses
        AND     SW3_ResetMask
        JPOS    ResetFired
        LOAD    P3_Zero
        RETURN

ResetFired:
        LOAD    P3_One
        RETURN

P3_Zero: DW 0
P3_One:  DW 1

; ============================================================
; Person 4 - LEDs & HEX Displays
;
;   0x001 (LEDs):    10 LEDs act as a thermometer for current money
;                    (1 LED every 3 steps, up to 10 LEDs at step 27-29)
;   0x004 (Hex0_1):  Remaining deciseconds from timer API
;   0x005 (Hex2_3):  Current money / bank balance
; ============================================================
LEDs:           EQU     &H001
Hex0_1:         EQU     &H004
Hex2_3:         EQU     &H005

; Update 10-LED thermometer based on CurrentValueIdx (0..29)
Display_UpdateLEDMoney:
        LOAD    CurrentValueIdx
        SUB     Step27
        JPOS    L10
        JZERO   L10

        LOAD    CurrentValueIdx
        SUB     Step24
        JPOS    L9
        JZERO   L9

        LOAD    CurrentValueIdx
        SUB     Step21
        JPOS    L8
        JZERO   L8

        LOAD    CurrentValueIdx
        SUB     Step18
        JPOS    L7
        JZERO   L7

        LOAD    CurrentValueIdx
        SUB     Step15
        JPOS    L6
        JZERO   L6

        LOAD    CurrentValueIdx
        SUB     Step12
        JPOS    L5
        JZERO   L5

        LOAD    CurrentValueIdx
        SUB     Step9
        JPOS    L4
        JZERO   L4

        LOAD    CurrentValueIdx
        SUB     Step6
        JPOS    L3
        JZERO   L3

        LOAD    CurrentValueIdx
        SUB     Step3
        JPOS    L2
        JZERO   L2

        LOAD    Bar1
        OUT     LEDs
        RETURN

L10:    LOAD    Bar10
        OUT     LEDs
        RETURN
L9:     LOAD    Bar9
        OUT     LEDs
        RETURN
L8:     LOAD    Bar8
        OUT     LEDs
        RETURN
L7:     LOAD    Bar7
        OUT     LEDs
        RETURN
L6:     LOAD    Bar6
        OUT     LEDs
        RETURN
L5:     LOAD    Bar5
        OUT     LEDs
        RETURN
L4:     LOAD    Bar4
        OUT     LEDs
        RETURN
L3:     LOAD    Bar3
        OUT     LEDs
        RETURN
L2:     LOAD    Bar2
        OUT     LEDs
        RETURN

; Output time and money to HEX digits
Display_UpdateHEX:
        LOAD    RemainingTicks
        OUT     Hex0_1
        LOAD    CurrentMoney
        OUT     Hex2_3
        RETURN

; Cash out flash (all LEDs lit)
Display_AnimCashOut:
        LOAD    Bar10
        OUT     LEDs
        CALL    Delay
        LOAD    P4_Zero
        OUT     LEDs
        CALL    Delay
        LOAD    Bar10
        OUT     LEDs
        CALL    Delay
        JUMP    StateReplay            ; tail back to the main loop

; Crash strobe (alternating pattern)
Display_AnimCrash:
        LOAD    Hazard1
        OUT     LEDs
        CALL    Delay
        LOAD    Hazard2
        OUT     LEDs
        CALL    Delay
        LOAD    Hazard1
        OUT     LEDs
        CALL    Delay
        LOAD    Hazard2
        OUT     LEDs
        CALL    Delay
        JUMP    BustAfterCrash         ; tail back to the main loop

; Bankrupt (all LEDs off, clear HEX)
Display_AnimBankrupt:
        LOAD    P4_Zero
        OUT     LEDs
        OUT     Hex0_1
        OUT     Hex2_3
        RETURN

Delay:
        LOAD    OuterLoops
        STORE   OuterCount
OuterLoop:
        LOAD    InnerLoops
        STORE   InnerCount
InnerLoop:
        LOAD    InnerCount
        SUB     One
        STORE   InnerCount
        JPOS    InnerLoop

        LOAD    OuterCount
        SUB     One
        STORE   OuterCount
        JPOS    OuterLoop
        RETURN

; Inner * Outer = 1 million        
OuterLoops: DW 100
InnerLoops: DW 10000
OuterCount: DW 0
InnerCount: DW 1
One:        DW  1

Bar1:       DW  &H0001
Bar2:       DW  &H0003
Bar3:       DW  &H0007
Bar4:       DW  &H000F
Bar5:       DW  &H001F
Bar6:       DW  &H003F
Bar7:       DW  &H007F
Bar8:       DW  &H00FF
Bar9:       DW  &H01FF
Bar10:      DW  &H03FF

Hazard1:    DW  &H02AA
Hazard2:    DW  &H0155

Step3:      DW  3
Step6:      DW  6
Step9:      DW  9
Step12:     DW  12
Step15:     DW  15
Step18:     DW  18
Step21:     DW  21
Step24:     DW  24
Step27:     DW  27
P4_Zero:    DW  0
