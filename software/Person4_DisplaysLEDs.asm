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

; (This is Person 4's slice of RocketGame.asm. It leans on the shared
; variables, Zero and One from the Person 5 section, so assemble the
; full RocketGame.asm to run it.)

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
