# Rocket Game — ECE 2031 SCOMP Project Demo

A push-your-luck survival rocket game for the SCOMP processor on the Altera DE10-Lite FPGA.

This is the software demo for our custom countdown timer peripheral (`0x070` / `0x071`) built in the `PausableCountdownTimerAPI` repo.

## How the Game Works

There is no "win" screen. You start with 100 credits, every round costs a 10 credit stake, and you try to grow your bank without crashing out:
1. **Launch (SW0):** Starts the round, loads 6.0 seconds into the hardware timer, and begins the 30-step payout climb (one step every 0.2 sec).
2. **LEDs (0x001):** The 10 LEDs act as a thermometer for the current payout (1 more LED every 3 steps).
3. **HEX displays:** `HEX3..HEX0` (0x004) show the payout during a round and the bank between rounds. `HEX5..HEX4` (0x005) show time left in tenths of a second. Both are decimal.
4. **Cash Out (SW1):** Stops the timer and banks your profit (payout minus stake).
5. **Pause (SW2):** Up = paused (hardware timer freezes and the climb stops, cash out is blocked). Down = running again.
6. **Replay (SW3):** Starts the next round after a cash out or crash.
7. **Crash / Timeout:** If the timer reaches 0 or you hit the random crash step (somewhere from step 8 to 30), you lose your stake.
8. **Bankruptcy:** If the bank hits 0, the LEDs flash forever. Press the board's reset button to start over.

Launch, Cash Out and Replay fire when you flip the switch **up**, so flip a switch back down before using it again.

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

`software/RocketGame.asm` is the finished, merged game. The `Person*.asm` files are the same code split up by person so everyone can read their own part.

1. Assemble `RocketGame.asm` with `scasm` to create `RocketGame.mif`.
2. Put `RocketGame.asm` and `RocketGame.mif` in the Quartus project folder.
3. Make sure `SCOMP.vhd` has `init_file => "RocketGame.mif"`.
4. Compile in Quartus, program the DE10-Lite, and play.
