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

; (This is Person 1's slice of RocketGame.asm. It leans on the shared
; variables, Zero and One from the Person 5 section, so assemble the
; full RocketGame.asm to run it.)

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
