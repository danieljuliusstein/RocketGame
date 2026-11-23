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
