; ============================================================
; Person 5 - Rocket Game: Main Loop & Integration
;
; Push-your-luck rocket game for SCOMP on the DE10-Lite.
; You start with 100 credits and every round costs a 10 credit
; stake. The rocket climbs through 30 payout steps. Cash out
; before it crashes (or the clock runs out) and you keep the
; payout. Crash first and you lose your stake. Hit 0 credits
; and you're bankrupt.
;
; HOW TO PLAY (switches on the board)
;   SW0  Launch the rocket (flip it up)
;   SW1  Cash out (flip it up)
;   SW2  Pause. Up = paused, down = running again
;   SW3  Play again after a round ends (flip it up)
;   Tip: every switch counts when it gets flipped UP, so flip a
;   switch back down before using it again.
;
; WHAT THE BOARD SHOWS
;   LEDs        10 LED thermometer, 1 more LED every 3 steps
;   HEX3..HEX0  current payout during a round, bank between rounds
;   HEX5..HEX4  time left in tenths of a second (60 = 6.0 sec)
;   Both HEX ports show normal decimal numbers.
;
; HOW THIS FILE IS PUT TOGETHER
;   Person 5 - main loop and game states      (this part)
;   Person 1 - timer API         (0x070 / 0x071)
;   Person 2 - payout table + random crash point
;   Person 3 - switch reading / edge detection / pause
;   Person 4 - LEDs, HEX displays, animations
;
; Build: scasm RocketGame.asm  ->  RocketGame.mif
; ============================================================

        ORG     0

; ------------------------------------------------------------
; Power up. Set the bank and stake, clear everything else.
; ------------------------------------------------------------
MainInit:
        LOAD    InitialBank
        STORE   BankedCredits
        LOAD    InitialStake
        STORE   CurrentStake
        LOAD    Zero
        STORE   GamePaused
        STORE   CrashFlag
        STORE   CurrentValueIdx
        STORE   CurrentMoney
        STORE   LastStepTick
        STORE   NewPresses

        ; Remember where the switches are right now. That way a
        ; switch that is already up at power-up doesn't count as
        ; a "press" and start the game by itself.
        IN      Switches
        STORE   PrevSwitches

        CALL    Timer_LoadDuration

; ------------------------------------------------------------
; Waiting at the pad. Show the bank and wait for SW0.
; ------------------------------------------------------------
WaitLaunch:
        CALL    Display_ShowBank
        LOAD    Zero
        OUT     LEDs

WaitLaunchLoop:
        CALL    Inputs_Poll
        CALL    Inputs_CheckStart
        JZERO   WaitLaunchLoop

        ; Launch! Fresh table, fresh crash point, fresh 6 seconds.
        CALL    Table_Init
        CALL    Table_GenCrashThreshold
        CALL    Timer_LoadDuration
        LOAD    DefaultDuration
        STORE   LastStepTick            ; first step is measured from 6.0 sec
        CALL    Timer_Start

        ; Put the starting numbers on the board right away
        CALL    Timer_PollStatus
        CALL    Display_UpdateHEX
        CALL    Display_UpdateLEDMoney

; ------------------------------------------------------------
; The round. This loop runs over and over until you cash out,
; crash, or the timer hits 0.
; ------------------------------------------------------------
GameLoop:
        CALL    Inputs_Poll
        CALL    Inputs_CheckPause

        ; If we're paused, just sit here and keep watching SW2
        LOAD    GamePaused
        JPOS    GameLoop

        ; Did the player cash out?
        CALL    Inputs_CheckCashOut
        JPOS    StateCashOut

        ; Ask the timer how much time is left
        CALL    Timer_PollStatus

        ; Timer ran all the way down = bust
        LOAD    TimerDoneFlag
        JPOS    StateBustTimeout

        ; Did we reach the secret crash step?
        CALL    Table_CheckCrash
        LOAD    CrashFlag
        JPOS    StateBustCrash

        ; Pacing. We want one payout step every 2 tenths of a
        ; second (60 ticks / 30 steps). So we only step once the
        ; timer has dropped 2 ticks below where the last step happened.
        LOAD    LastStepTick
        SUB     PaceInterval
        SUB     RemainingTicks
        JNEG    GameLoop                ; not enough time has passed yet

        CALL    Table_StepNext
        LOAD    RemainingTicks
        STORE   LastStepTick
        CALL    Display_UpdateLEDMoney
        CALL    Display_UpdateHEX
        JUMP    GameLoop

; ------------------------------------------------------------
; Cash out: freeze the clock and bank the profit.
; Profit = payout - stake. So cashing out on the very first
; step just gets your stake back (no free money).
; ------------------------------------------------------------
StateCashOut:
        CALL    Timer_Pause
        LOAD    BankedCredits
        ADD     CurrentMoney
        SUB     CurrentStake
        STORE   BankedCredits
        CALL    Display_AnimCashOut
        JUMP    StateReplay

; ------------------------------------------------------------
; Bust (crash or timeout): freeze the clock and lose the stake.
; ------------------------------------------------------------
StateBustTimeout:
StateBustCrash:
        CALL    Timer_Pause
        LOAD    BankedCredits
        SUB     CurrentStake
        STORE   BankedCredits
        CALL    Display_AnimCrash

        ; Out of money? Then it's game over.
        LOAD    BankedCredits
        JPOS    StateReplay
        JUMP    StateBankrupt

; ------------------------------------------------------------
; Round is over. Show the bank and wait for SW3 to go again.
; ------------------------------------------------------------
StateReplay:
        CALL    Display_ShowBank

StateReplayLoop:
        CALL    Inputs_Poll
        CALL    Inputs_CheckReset
        JZERO   StateReplayLoop

        LOAD    Zero
        STORE   GamePaused
        CALL    Timer_Reset
        JUMP    WaitLaunch

; ------------------------------------------------------------
; Bankrupt. Show 0 and flash the hazard lights forever.
; Press the reset button on the board to start over.
; ------------------------------------------------------------
StateBankrupt:
        CALL    Display_ShowBank        ; bank is 0 or less, so this shows 0000
        CALL    Display_AnimBankrupt
Halt:
        JUMP    Halt

; ------------------------------------------------------------
; Shared variables. Everybody's code reads and writes these,
; so please don't rename them.
; ------------------------------------------------------------
BankedCredits:   DW     100             ; money in the bank
CurrentStake:    DW     10              ; what a round costs you
CurrentValueIdx: DW     0               ; which payout step we're on (0..29)
CurrentMoney:    DW     0               ; payout at the current step
CrashThreshold:  DW     24              ; the step where the rocket blows up
RemainingTicks:  DW     0               ; time left in tenths of a second
TimerDoneFlag:   DW     0               ; 1 when the timer hit 0
GamePaused:      DW     0               ; 1 when SW2 has us paused
CrashFlag:       DW     0               ; 1 when we reached the crash step
PRNG_Seed:       DW     &HACE1          ; random number state (never 0)

InitialBank:     DW     100
InitialStake:    DW     10

; Pacing stuff
LastStepTick:    DW     0               ; timer value at the last payout step
PaceInterval:    DW     2               ; tenths of a second per step

; Plain numbers everybody shares
Zero:            DW     0
One:             DW     1

; ============================================================
; Person 1 - Timer API Interface
;
; This talks to our pausable countdown timer in the hardware:
;   0x070 (TimerValue):   write = load a new time (tenths of a sec)
;                         read  = time remaining
;   0x071 (TimerControl): write 0 = pause, 1 = start/resume, 2 = reset
;                         read  = status. bit 0 = running, bit 1 = done
;
; Quick facts:
;   - Every routine here is allowed to change AC.
;   - Timer_PollStatus fills in RemainingTicks and TimerDoneFlag
;     (DONE is 0 or 1) so the rest of the code never touches the
;     hardware directly.
; ============================================================

TimerValue:      EQU     &H070
TimerControl:    EQU     &H071

TimerDoneMask:   DW      &H0002          ; DONE is bit 1 of the status

CmdPause:        DW      0
CmdStart:        DW      1
CmdReset:        DW      2

DefaultDuration: DW      60              ; 6.0 seconds

; Load the round time. This also clears DONE and leaves the timer paused.
Timer_LoadDuration:
        LOAD    DefaultDuration
        OUT     TimerValue
        RETURN

; Start the countdown
Timer_Start:
        LOAD    CmdStart
        OUT     TimerControl
        RETURN

; Freeze the countdown. The time left stays put.
Timer_Pause:
        LOAD    CmdPause
        OUT     TimerControl
        RETURN

; Unfreeze the countdown from where it stopped
Timer_Resume:
        LOAD    CmdStart
        OUT     TimerControl
        RETURN

; Put the timer back to the full time (it stays paused)
Timer_Reset:
        LOAD    CmdReset
        OUT     TimerControl
        RETURN

; Read the time left and check whether the timer is done
Timer_PollStatus:
        IN      TimerValue
        STORE   RemainingTicks

        IN      TimerControl
        AND     TimerDoneMask
        JZERO   TimerNotDone
        LOAD    One
        STORE   TimerDoneFlag
        RETURN

TimerNotDone:
        LOAD    Zero
        STORE   TimerDoneFlag
        RETURN

; ============================================================
; Person 2 - Multiplier Table & Crash Engine
;
; SCOMP can't multiply or divide, so all 30 payouts are already
; worked out and stored in RAM below. Each step just looks one
; up. This part also picks the secret random step where the
; rocket crashes.
; ============================================================

; Go back to step 0 with the starting payout
Table_Init:
        LOAD    Zero
        STORE   CurrentValueIdx
        STORE   CrashFlag
        LOAD    Value_00
        STORE   CurrentMoney
        RETURN

; Pick the crash step once per launch. It lands somewhere from 8
; through 30. The payouts stop at step 29, so a pick of 30 means
; the rocket survives and the timer ends the round instead.
; This uses an LFSR (a scrambled shift register) as the random source.
Table_GenCrashThreshold:
        LOAD    PRNG_Seed
        JZERO   P2_RestoreSeed
        JUMP    P2_AdvanceLfsr

P2_RestoreSeed:
        LOAD    P2_DefaultSeed          ; an LFSR stuck at 0 never moves, so fix that

P2_AdvanceLfsr:
        ; Shift left. If the bit that fell off the top was a 1,
        ; flip some bits too (that's the feedback).
        JNEG    P2_ApplyFeedback
        SHIFT   1
        JUMP    P2_SampleLfsr

P2_ApplyFeedback:
        SHIFT   1
        XOR     P2_LfsrMask

P2_SampleLfsr:
        STORE   PRNG_Seed
        AND     P2_SampleMask           ; keep 5 bits = 0..31
        SUB     P2_SampleCount
        JNEG    P2_AcceptSample
        JUMP    Table_GenCrashThreshold ; got 23..31, throw it out and roll again

P2_AcceptSample:
        ADD     P2_SampleCount          ; undo the subtract, now it's 0..22
        ADD     P2_MinCrash             ; shift up to 8..30
        STORE   CrashThreshold
        RETURN

; Did we get to the crash step? Sets CrashFlag if yes.
Table_CheckCrash:
        LOAD    CurrentValueIdx
        SUB     CrashThreshold
        JPOS    SetCrashed
        JZERO   SetCrashed
        RETURN

SetCrashed:
        LOAD    One
        STORE   CrashFlag
        RETURN

; Move up one step and grab the new payout. Stops at step 29
; so a round can never run off the end of the table.
Table_StepNext:
        LOAD    CurrentValueIdx
        SUB     P2_LastIndex
        JNEG    P2_AdvanceStep
        RETURN

P2_AdvanceStep:
        LOAD    CurrentValueIdx
        ADD     One
        STORE   CurrentValueIdx

        ; SCOMP can't load from "table + index", so we count the
        ; index down to find which Value_xx to load directly.
        SUB     One
        JZERO   P2_Pay01
        SUB     One
        JZERO   P2_Pay02
        SUB     One
        JZERO   P2_Pay03
        SUB     One
        JZERO   P2_Pay04
        SUB     One
        JZERO   P2_Pay05
        SUB     One
        JZERO   P2_Pay06
        SUB     One
        JZERO   P2_Pay07
        SUB     One
        JZERO   P2_Pay08
        SUB     One
        JZERO   P2_Pay09
        SUB     One
        JZERO   P2_Pay10
        SUB     One
        JZERO   P2_Pay11
        SUB     One
        JZERO   P2_Pay12
        SUB     One
        JZERO   P2_Pay13
        SUB     One
        JZERO   P2_Pay14
        SUB     One
        JZERO   P2_Pay15
        SUB     One
        JZERO   P2_Pay16
        SUB     One
        JZERO   P2_Pay17
        SUB     One
        JZERO   P2_Pay18
        SUB     One
        JZERO   P2_Pay19
        SUB     One
        JZERO   P2_Pay20
        SUB     One
        JZERO   P2_Pay21
        SUB     One
        JZERO   P2_Pay22
        SUB     One
        JZERO   P2_Pay23
        SUB     One
        JZERO   P2_Pay24
        SUB     One
        JZERO   P2_Pay25
        SUB     One
        JZERO   P2_Pay26
        SUB     One
        JZERO   P2_Pay27
        SUB     One
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

P2_DefaultSeed: DW      &HACE1          ; backup seed if the LFSR ever hits 0
P2_LfsrMask:    DW      &H002D          ; which bits get flipped by the feedback
P2_SampleMask:  DW      &H001F          ; keeps the low 5 bits
P2_SampleCount: DW      23              ; 23 usable values (0..22)
P2_MinCrash:    DW      8               ; earliest possible crash step
P2_LastIndex:   DW      29              ; last step in the table

; The 30 payouts (stake of 10 climbing up to 500)
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
; Person 3 - Switch Controls
;
; Reads the switches at 0x000:
;   SW0  Launch
;   SW1  Cash out
;   SW2  Pause (up = paused, down = running)
;   SW3  Play again
;
; Launch, cash out and play again fire ONCE when you flip the
; switch up, so holding one up doesn't repeat it. Each switch is
; tracked on its own, so leaving SW0 up won't block SW1.
; ============================================================

Switches:        EQU     &H000

SW0_StartMask:   DW      &H0001
SW1_CashOutMask: DW      &H0002
SW2_PauseMask:   DW      &H0004
SW3_ResetMask:   DW      &H0008

PrevSwitches:    DW      0              ; switches last time we looked
CurrSwitches:    DW      0              ; switches right now
NewPresses:      DW      0              ; switches that just went up this time

; Read the switches and work out which ones were JUST flipped up
Inputs_Poll:
        IN      Switches
        STORE   CurrSwitches
        XOR     PrevSwitches            ; 1 = this switch changed
        AND     CurrSwitches            ; ...and it's up now, so it was just pressed
        STORE   NewPresses
        LOAD    CurrSwitches
        STORE   PrevSwitches            ; remember for next time
        RETURN

; Returns AC = 1 if cash out was pressed. Blocked while paused.
Inputs_CheckCashOut:
        LOAD    GamePaused
        JPOS    BlockCashOut

        LOAD    NewPresses
        AND     SW1_CashOutMask
        JPOS    HitCashOut
        LOAD    Zero
        RETURN

HitCashOut:
        LOAD    One
        RETURN

BlockCashOut:
        LOAD    Zero
        RETURN

; Follow SW2. Up = paused, down = running. The timer is only told
; when SW2 actually changes, so we don't spam it every loop.
Inputs_CheckPause:
        LOAD    CurrSwitches
        AND     SW2_PauseMask
        JZERO   WantRunning

        ; SW2 is up, so we want to be paused
        LOAD    GamePaused
        JPOS    PauseDone               ; already paused, nothing to do
        LOAD    One
        STORE   GamePaused
        CALL    Timer_Pause
        RETURN

WantRunning:
        ; SW2 is down, so we want to be running
        LOAD    GamePaused
        JZERO   PauseDone               ; already running, nothing to do
        LOAD    Zero
        STORE   GamePaused
        CALL    Timer_Resume

PauseDone:
        RETURN

; Returns AC = 1 if SW0 (launch) was just pressed
Inputs_CheckStart:
        LOAD    NewPresses
        AND     SW0_StartMask
        JPOS    StartFired
        LOAD    Zero
        RETURN

StartFired:
        LOAD    One
        RETURN

; Returns AC = 1 if SW3 (play again) was just pressed
Inputs_CheckReset:
        LOAD    NewPresses
        AND     SW3_ResetMask
        JPOS    ResetFired
        LOAD    Zero
        RETURN

ResetFired:
        LOAD    One
        RETURN

; ============================================================
; Person 4 - LEDs & HEX Displays
;
;   0x001 (LEDs):      10 LEDs act as a thermometer for the payout
;                      (1 more LED every 3 steps, all 10 at step 27+)
;   0x004 (HexMoney):  HEX3..HEX0, payout in a round / bank otherwise
;   0x005 (HexTime):   HEX5..HEX4, time left in tenths of a second
;
; The HEX displays just show raw hex digits. So before we send a
; number out we turn it into BCD (each hex digit holds one decimal
; digit). That way 500 shows up as "0500" and not "01F4".
;
; Every delay here uses the board's 10 Hz timer at 0x002.
; ============================================================

LEDs:           EQU     &H001
Timer:          EQU     &H002           ; board timer, counts every 0.1 sec
HexMoney:       EQU     &H004
HexTime:        EQU     &H005

; Light up the thermometer. Start with 1 LED, then add another
; for every 3 steps we've climbed.
Display_UpdateLEDMoney:
        LOAD    CurrentValueIdx
        STORE   LedWork
        LOAD    One
        STORE   LedBar                  ; first LED is always on

LedLoop:
        LOAD    LedWork
        SUB     Three
        JNEG    LedDone                 ; less than 3 steps left, we're done
        STORE   LedWork
        LOAD    LedBar
        SHIFT   1
        ADD     One                     ; slide left and add one more LED
        STORE   LedBar
        JUMP    LedLoop

LedDone:
        LOAD    LedBar
        OUT     LEDs
        RETURN

; Show the payout and the time left during a round
Display_UpdateHEX:
        LOAD    CurrentMoney
        CALL    Display_ToBCD
        OUT     HexMoney
        LOAD    RemainingTicks
        CALL    Display_ToBCD
        OUT     HexTime
        RETURN

; Show the bank on the big display and blank the time display
Display_ShowBank:
        LOAD    BankedCredits
        JPOS    ShowBankNumber
        LOAD    Zero                    ; never show a negative number
ShowBankNumber:
        CALL    Display_ToBCD
        OUT     HexMoney
        LOAD    Zero
        OUT     HexTime
        RETURN

; Turn a number (0..9999) in AC into BCD and hand it back in AC.
; We just subtract 1000s, then 100s, then 10s, and count how many.
Display_ToBCD:
        STORE   BcdWork
        LOAD    Zero
        STORE   BcdOut

BcdThousands:
        LOAD    BcdWork
        SUB     Num1000
        JNEG    BcdHundreds
        STORE   BcdWork
        LOAD    BcdOut
        ADD     Bcd1000
        STORE   BcdOut
        JUMP    BcdThousands

BcdHundreds:
        LOAD    BcdWork
        SUB     Num100
        JNEG    BcdTens
        STORE   BcdWork
        LOAD    BcdOut
        ADD     Bcd100
        STORE   BcdOut
        JUMP    BcdHundreds

BcdTens:
        LOAD    BcdWork
        SUB     Num10
        JNEG    BcdOnes
        STORE   BcdWork
        LOAD    BcdOut
        ADD     Bcd10
        STORE   BcdOut
        JUMP    BcdTens

BcdOnes:
        LOAD    BcdOut
        ADD     BcdWork                 ; whatever is left is the ones digit
        RETURN

; Cash out flash: all LEDs blink on, off, on
Display_AnimCashOut:
        LOAD    Bar10
        OUT     LEDs
        CALL    Delay
        LOAD    Zero
        OUT     LEDs
        CALL    Delay
        LOAD    Bar10
        OUT     LEDs
        CALL    Delay
        RETURN

; Crash flash: the LEDs alternate in a hazard pattern
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
        RETURN

; Bankrupt: same hazard flash but it never stops
Display_AnimBankrupt:
BankruptLoop:
        LOAD    Hazard1
        OUT     LEDs
        CALL    Delay
        LOAD    Hazard2
        OUT     LEDs
        CALL    Delay
        JUMP    BankruptLoop

; Wait about 0.3 seconds. Writing to the board timer resets it
; to 0, then we wait until it has counted up to DelayTicks.
Delay:
        OUT     Timer
DelayWait:
        IN      Timer
        SUB     DelayTicks
        JNEG    DelayWait
        RETURN

DelayTicks: DW  3                       ; 3 ticks of 0.1 sec = 0.3 sec

; Scratch space for the LED bar and the BCD converter
LedWork:    DW  0
LedBar:     DW  0
BcdWork:    DW  0
BcdOut:     DW  0

Three:      DW  3
Num1000:    DW  1000
Num100:     DW  100
Num10:      DW  10
Bcd1000:    DW  &H1000
Bcd100:     DW  &H0100
Bcd10:      DW  &H0010

Bar10:      DW  &H03FF                  ; all 10 LEDs on
Hazard1:    DW  &H02AA                  ; every other LED
Hazard2:    DW  &H0155                  ; the other every other LED
