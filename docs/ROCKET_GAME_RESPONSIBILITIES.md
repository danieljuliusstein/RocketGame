# Rocket Multiplier Game — Team Notes & Roles

Application demo for the custom countdown timer peripheral (`0x070` / `0x071`).

## Game Loop

Push-your-luck survival game:
- Start with 100 credits. Each round stakes 10 credits.
- SW0 launches the rocket and starts the hardware timer (loaded with 60 deciseconds).
- Game steps through 30 precomputed payout values in RAM.
- 10 LEDs show the money level as a thermometer (1 LED every 3 steps).
- SW1 cashes out: locks in profit, pauses timer, banks money.
- SW2 toggles pause: writes `0` to `0x071` to freeze hardware countdown, writes `1` to resume.
- If timer expires (`DONE = 1`) or current step hits the random crash index, you bust and lose the stake.
- SW3 resets for the next round.
- If bank hits 0, you're bankrupt (all LEDs off, game locks).

## Shared Variables (RAM Contract)

Do not rename these so our files merge cleanly:

```asm
BankedCredits:   DW 100     ; Total bankroll
CurrentStake:    DW 10      ; Current round wager
CurrentValueIdx: DW 0       ; Step index (0 to 29)
CurrentMoney:    DW 0       ; Current payout looked up from table
CrashThreshold:  DW 24      ; Random crash cutoff (8 to 30)
RemainingTicks:  DW 0       ; Deciseconds read from 0x070
TimerDoneFlag:   DW 0       ; Bit 1 of 0x071 (1 = expired)
GamePaused:      DW 0       ; 0 = active, 1 = paused
CrashFlag:       DW 0       ; 1 = crashed, 0 = safe
PRNG_Seed:       DW &HACE1  ; LFSR seed
```

## Team Responsibilities

### Person 1: Timer API (`software/Person1_TimerAPI.asm`)
- Subroutines: `Timer_LoadDuration`, `Timer_Start`, `Timer_Pause`, `Timer_Resume`, `Timer_Reset`, `Timer_PollStatus`.
- Addresses: `0x070` (value/load), `0x071` (control/status).
- Checks: make sure `Timer_PollStatus` reads deciseconds from `0x070` and extracts bit 1 (`DONE`) from `0x071`.

### Person 2: Multiplier Table & Crash (`software/Person2_MultiplierTable.asm`)
- Subroutines: `Table_Init`, `Table_GenCrashThreshold`, `Table_CheckCrash`, `Table_StepNext`.
- 30-word payout table in RAM (10 up to 500).
- 16-bit LFSR to generate random crash cutoff between 8 and 30.

### Person 3: Switch Inputs (`software/Person3_SwitchControls.asm`)
- Subroutines: `Inputs_Poll`, `Inputs_CheckStart`, `Inputs_CheckCashOut`, `Inputs_CheckPauseToggle`, `Inputs_CheckReset`.
- Reads `0x000` with rising-edge detection so switches don't re-trigger every clock cycle.
- Blocks Cash Out while paused.

### Person 4: Displays & LEDs (`software/Person4_DisplaysLEDs.asm`)
- Subroutines: `Display_UpdateLEDMoney`, `Display_UpdateHEX`, `Display_AnimCashOut`, `Display_AnimCrash`, `Display_AnimBankrupt`.
- Maps steps 0..29 to the 10 LEDs (`0x001`).
- Writes time to `HEX0_1` (`0x004`) and money to `HEX2_3` (`0x005`).

### Person 5: Integration & Main Loop (`software/RocketGame.asm`)
- Owns main state machine (`WaitLaunch` -> `Running` -> `CashOut` / `Bust` -> `Replay`).
- Handles game pacing so the 30 values step at timer intervals (not instantly).
- Pastes routines from Persons 1-4 into `RocketGame.asm` and runs `scasm`.
