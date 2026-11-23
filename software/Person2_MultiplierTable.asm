; ============================================================
; Person 2 - Multiplier Table & Crash Engine
;
; SCOMP can't multiply or divide, so all 30 payouts are already
; worked out and stored in RAM below. Each step just looks one
; up. This part also picks the secret random step where the
; rocket crashes.
; ============================================================

; (This is Person 2's slice of RocketGame.asm. It leans on the shared
; variables, Zero and One from the Person 5 section, so assemble the
; full RocketGame.asm to run it.)

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
