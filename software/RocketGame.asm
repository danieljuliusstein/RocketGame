; ============================================================
; Person 5 - Main Game Loop & Integration
;
; Push-your-luck survival rocket game for SCOMP.
; Loops through 30 values using our custom timer at 0x070/0x071.
; Cash out before crashing or timing out. If bank hits 0, bankrupt.
;
; TODO for Person 5:
; - Add pacing check so values advance with timer ticks (not instantly)
; - Paste tested subroutines from Persons 1-4 into the bottom slots
; - Assemble with scasm to produce RocketGame.mif
; ============================================================

        ORG     0

; Init bankroll and stake
MainInit:
        LOAD    InitialBank
        STORE   BankedCredits
        LOAD    InitialStake
        STORE   CurrentStake
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
        CALL    Timer_Start

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

        ; Next value in table
        CALL    Table_StepNext

        ; Refresh LEDs and HEX
        CALL    Display_UpdateLEDMoney
        CALL    Display_UpdateHEX

        JUMP    GameLoop

; Cash out: bank profit and freeze timer
StateCashOut:
        CALL    Timer_Pause
        LOAD    BankedCredits
        ADD     CurrentMoney
        STORE   BankedCredits
        CALL    Display_AnimCashOut
        JUMP    StateReplay

; Bust: forfeit stake and freeze timer
StateBustTimeout:
StateBustCrash:
        CALL    Timer_Pause
        LOAD    BankedCredits
        SUB     CurrentStake
        STORE   BankedCredits
        CALL    Display_AnimCrash

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

        CALL    Timer_Reset
        JUMP    WaitLaunch

; Out of money
StateBankrupt:
        CALL    Display_AnimBankrupt
Halt:
        JUMP    Halt

; Shared RAM variables
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
P5_Zero:         DW     0

; ============================================================
; Subroutine slots - paste teammates' tested routines below:
; ============================================================

; [Person 1 - Timer API routines]
; (Timer_LoadDuration, Timer_Start, Timer_Pause, Timer_Resume, Timer_Reset, Timer_PollStatus)

; [Person 2 - Table & Crash routines]
; (Table_Init, Table_GenCrashThreshold, Table_CheckCrash, Table_StepNext)

; [Person 3 - Switch Input routines]
; (Inputs_Poll, Inputs_CheckCashOut, Inputs_CheckPauseToggle, Inputs_CheckStart, Inputs_CheckReset)

; [Person 4 - Display & Animation routines]
; (Display_UpdateLEDMoney, Display_UpdateHEX, Display_AnimCashOut, Display_AnimCrash, Display_AnimBankrupt)
