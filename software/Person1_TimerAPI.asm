; ============================================================
; Person 1 - Timer API Interface
;
; Connects SCOMP to our pausable countdown peripheral:
;   0x070 (TimerValue):   write loads duration (in 0.1s ticks)
;                         read gets remaining deciseconds
;   0x071 (TimerControl): write 0 = pause, 1 = start, 2 = reset
;                         read bit 0 = running, bit 1 = done
;
; TODO for Person 1:
; - Verify register reads/writes on the actual DE10-Lite board
; - Make sure Timer_PollStatus extracts DONE (bit 1) correctly
; - Confirm that pausing mid-countdown holds time without losing ticks
; 
; Integration
; - RocketGame.asm defines RemainingTicks and TimerDoneFlag
; - Timer_LoadDuration takes no input and loads 60 ticks
; - All Timer routines may overwrite AC
; - Timer_PollStatus updates both shared variables and returns the 
;   normalized DONE flag (0 or 1) in AC
;
; Verification
; - Quartus load/pause/readback test passed with 60 ticks
; - Simulation showed count holding at 3 during pause, continuing after
;   resume, and returning to 4 after reset
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
