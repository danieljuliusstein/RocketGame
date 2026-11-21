; ============================================================
; Person 2 - Multiplier Table & Crash Engine
;
; Manages the 30-step payout table and random crash check.
; SCOMP doesn't have multiply/divide instructions, so we precompute
; all 30 payout values in RAM to avoid runtime math.
;
; TODO for Person 2:
; - Finish Table_StepNext lookup (need a clean way to load
;   ValueTable[CurrentValueIdx] in SCOMP)
; - Tune the LFSR PRNG seed and range so crashes feel fair
; ============================================================

; Reset table index to 0 and load starting money
Table_Init:
        LOAD    P2_Zero
        STORE   CurrentValueIdx
        STORE   CrashFlag
        LOAD    Value_00
        STORE   CurrentMoney
        RETURN

; Pick a cutoff from 8 through 30 once per launch. Since payouts stop
; at index 29, a cutoff of 30 lets the hardware timer end the round.
Table_GenCrashThreshold:
        LOAD    PRNG_Seed
        JZERO   P2_RestoreSeed
        JUMP    P2_AdvanceLfsr

P2_RestoreSeed:
        LOAD    P2_DefaultSeed ; zero is a locked state for the LFSR

P2_AdvanceLfsr:
        ; Left-shift Galois LFSR. Apply feedback if the old MSB was set.
        JNEG    P2_ApplyFeedback
        SHIFT   1
        JUMP    P2_SampleLfsr

P2_ApplyFeedback:
        SHIFT   1
        XOR     P2_LfsrMask

P2_SampleLfsr:
        STORE   PRNG_Seed
        AND     P2_SampleMask
        SUB     P2_SampleCount
        JNEG    P2_AcceptSample
        JUMP    Table_GenCrashThreshold ; discard 23..31, then draw again

P2_AcceptSample:
        ADD     P2_SampleCount
        ADD     P2_MinCrash
        STORE   CrashThreshold
        RETURN

; Check if current step reached the crash threshold
Table_CheckCrash:
        LOAD    CurrentValueIdx
        SUB     CrashThreshold
        JPOS    SetCrashed
        JZERO   SetCrashed
        RETURN

SetCrashed:
        LOAD    P2_One
        STORE   CrashFlag
        RETURN

; Advance to next step (0..29) and update CurrentMoney
Table_StepNext:
        LOAD    CurrentValueIdx
        ADD     P2_One
        STORE   CurrentValueIdx
        ; TODO: implement indexed table fetch for CurrentMoney
        RETURN

P2_DefaultSeed: DW      &HACE1
P2_LfsrMask:    DW      &H002D
P2_SampleMask:  DW      &H001F
P2_SampleCount: DW      23
P2_MinCrash:    DW      8
P2_Zero:        DW      0
P2_One:         DW      1

; Precomputed 30-step payout table (wager = 10, climbs to 500)
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
