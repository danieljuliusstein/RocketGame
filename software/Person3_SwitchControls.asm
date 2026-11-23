; ============================================================
; Person 3 - Switch Controls & Debounce
;
; Reads switch inputs from address 0x000:
;   SW0: Launch / Start
;   SW1: Cash Out
;   SW2: Pause / Resume (writes 0 / 1 to the timer control port)
;   SW3: Replay / New Round
;
; TODO for Person 3:
; - Test switch debouncing on the DE10-Lite
; ============================================================

Switches:        EQU     &H000

SW0_StartMask:   DW      &H0001
SW1_CashOutMask: DW      &H0002
SW2_PauseMask:   DW      &H0004
SW3_ResetMask:   DW      &H0008
P3_SwMask:       DW      &H000F ; SW0-SW3

PrevSwitches:    DW      0
CurrSwitches:    DW      0
NewPresses:      DW      0

P3_DebounceCount: DW     20000   ; settle loop length, currently ~20ms
P3_DelayCount:    DW     0


; Poll switches and detect rising edges so held switches don't repeat
Inputs_Poll:
        IN      Switches
        AND     P3_SwMask

        ; Checks if anything changed
        XOR     PrevSwitches
        JZERO   P3_NoChange

        ; Debounce logic
        ; Only runs when something changed
        ; Waits ~20 ms for things to settle before re-reading
        LOAD    P3_DebounceCount
        STORE   P3_DelayCount
P3_DebounceWait:
        LOAD    P3_DelayCount
        SUB     P3_One
        STORE   P3_DelayCount
        JPOS    P3_DebounceWait

        ; This is needed bc the game only uses 4 switches
        ; Without the mask any other change would also trigger debounce
        IN      Switches
        AND     P3_SwMask
        STORE   CurrSwitches

        XOR     PrevSwitches
        AND     CurrSwitches
        STORE   NewPresses

        LOAD    CurrSwitches
        STORE   PrevSwitches
        RETURN

P3_NoChange:
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

; Handles SW2 pause/resume toggle
Inputs_CheckPauseToggle:
        LOAD    NewPresses
        AND     SW2_PauseMask
        JZERO   NoPauseChange

        LOAD    GamePaused
        JZERO   PauseNow

        ; Unpause
        LOAD    P3_Zero
        STORE   GamePaused
        LOAD    CmdStart
        OUT     TimerControl
        RETURN

PauseNow:
        ; Updated to write to the timer port directly
        LOAD    P3_One
        STORE   GamePaused
        LOAD    CmdPause
        OUT     TimerControl
        RETURN


NoPauseChange:
        RETURN

; Check SW0 (Launch)
Inputs_CheckStart:
        ; Start is ignored while paused
        LOAD    GamePaused
        JPOS    StartBlocked

        LOAD    NewPresses
        AND     SW0_StartMask
        JPOS    StartFired

StartBlocked:
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
