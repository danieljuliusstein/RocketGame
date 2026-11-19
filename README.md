# Rocket Game — ECE 2031 SCOMP Project Demo

A push-your-luck survival rocket game for the SCOMP processor on the Altera DE10-Lite FPGA.

This is the software demo for our custom countdown timer peripheral (`0x070` / `0x071`) built in the `PausableCountdownTimerAPI` repo.

## How the Game Works

There is no "win" screen. You try to grow your bankroll without crashing out:
1. **Launch (SW0):** Starts the round, loads 6.0 seconds into the hardware timer, and begins the 30-value multiplier climb.
2. **LEDs (0x001):** The 10 LEDs act as a thermometer for current payout (1 LED lights up every 3 steps).
3. **Cash Out (SW1):** Locks in your current earnings, stops the timer, and banks the money.
4. **Pause (SW2):** Calls the timer API to freeze hardware countdown and pauses the value climb.
5. **Replay (SW3):** Prepares for the next launch.
6. **Crash / Timeout:** If the timer reaches 0 or you hit the random crash cutoff, you lose your stake.
7. **Bankruptcy:** If bank hits 0, you're out of money and the game halts.

## Team Files

Each person has their own file in `software/` to work in:

| Person | File | Focus |
| :--- | :--- | :--- |
| **Person 1** | [`software/Person1_TimerAPI.asm`](software/Person1_TimerAPI.asm) | Timer API (`0x070`/`0x071`): load, start, pause, resume, reset, poll status. |
| **Person 2** | [`software/Person2_MultiplierTable.asm`](software/Person2_MultiplierTable.asm) | 30-step payout table in RAM, step lookup, LFSR PRNG crash cutoff. |
| **Person 3** | [`software/Person3_SwitchControls.asm`](software/Person3_SwitchControls.asm) | Switch reading (`0x000`), edge detection/debounce, pause interlock. |
| **Person 4** | [`software/Person4_DisplaysLEDs.asm`](software/Person4_DisplaysLEDs.asm) | 10-LED thermometer (`0x001`), HEX time/money displays, win/crash flash. |
| **Person 5** | [`software/RocketGame.asm`](software/RocketGame.asm) | Main loop, pacing, game state transitions, merging everyone's routines. |

## Build Workflow

1. Each person tests their subroutines.
2. Person 5 pastes the subroutines into `software/RocketGame.asm`.
3. Assemble with `scasm RocketGame.asm` to create `RocketGame.mif`.
4. Point `SCOMP.vhd` in Quartus to `RocketGame.mif` (or copy it to `SCOMP.mif`) and compile.
