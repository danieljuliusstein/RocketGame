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

; (This is Person 3's slice of RocketGame.asm. It leans on the shared
; variables, Zero and One from the Person 5 section, so assemble the
; full RocketGame.asm to run it.)

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
