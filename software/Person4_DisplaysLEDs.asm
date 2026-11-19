; ============================================================
; Person 4 - LEDs & HEX Displays
;
; Manages board visual feedback:
;   0x001 (LEDs):    10 LEDs act as a thermometer for current money
;                    (1 LED every 3 steps, up to 10 LEDs at step 27-29)
;   0x004 (Hex0_1):  Remaining deciseconds from timer API
;   0x005 (Hex2_3):  Current money / bank balance
;
; TODO for Person 4:
; - Add short delay loops to win and crash animations so flashes are visible
; - Confirm HEX format matches Lab 8 HEX decoder
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
        RETURN

; Crash strobe (alternating pattern)
Display_AnimCrash:
        LOAD    Hazard1
        OUT     LEDs
        RETURN

; Bankrupt (all LEDs off, clear HEX)
Display_AnimBankrupt:
        LOAD    P4_Zero
        OUT     LEDs
        OUT     Hex0_1
        OUT     Hex2_3
        RETURN

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
