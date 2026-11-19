; ============================================================
; Person 3 - Switch Controls & Debounce
;
; Reads switch inputs from address 0x000:
;   SW0: Launch / Start
;   SW1: Cash Out
;   SW2: Pause / Resume (calls Timer_Pause or Timer_Resume)
;   SW3: Replay / New Round
;
; TODO for Person 3:
; - Test switch debouncing on the DE10-Lite
; - Make sure Cash Out is locked when GamePaused = 1
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

; Handles SW2 pause/resume toggle
Inputs_CheckPauseToggle:
        LOAD    NewPresses
        AND     SW2_PauseMask
        JZERO   NoPauseChange

        LOAD    GamePaused
        JZERO   PauseNow

        ; Unpause:
        LOAD    P3_Zero
        STORE   GamePaused
        CALL    Timer_Resume
        RETURN

PauseNow:
        LOAD    P3_One
        STORE   GamePaused
        CALL    Timer_Pause
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
