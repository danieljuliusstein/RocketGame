# Rocket Game — ECE 2031 SCOMP Project Demo

A push-your-luck survival multiplier game built for the Georgia Tech ECE 2031 SCOMP processor on the Altera DE10-Lite FPGA board.

This application serves as the interactive demonstration for the custom memory-mapped **`PausableCountdownTimerAPI`** peripheral (`TIMER_VALUE` at `0x070`, `TIMER_CONTROL` at `0x071`).

---

## 1. Game Concept: Push-Your-Luck Survival

There is **no arbitrary "Win" condition** in this game. Players either cash out to bank their earnings, or push their luck until they crash out and **lose all their money (Bankruptcy / Game Over)**:

1. **The Round:** 
   - Player wagers a stake of credits.
   - Pressing **SW0 (Launch)** loads the round duration into the hardware timer peripheral (`0x070`) and starts the countdown (`0x071 <= 1`).
   - The game sequentially steps through an array of **30 increasing values** (rising multiplier/money).
2. **Visual Feedback on 10 LEDs (`0x001`):**
   - The 10 board LEDs display a live thermometer bar representing the money level.
   - Every 3 steps illuminates an additional LED from bottom to top.
3. **Controls (`0x000`):**
   - **SW0 (Launch):** Starts round and countdown.
   - **SW1 (Cash Out):** Locks in current money, stops timer (`0x071 <= 0`), banks winnings, and safely concludes the round.
   - **SW2 (Pause / Resume):** Calls the hardware timer API (`0x071 <= 0` to pause, `0x071 <= 1` to resume). Freezes both the VHDL hardware countdown and the 30-value climb. Inputs are locked out while paused.
   - **SW3 (New Round / Replay):** Prepares state for the next launch.
4. **Crash, Timeout & Bankruptcy:**
   - If the player fails to cash out before the timer reaches 0 (`DONE = 1` at bit 1 of `0x071`) or before the random crash threshold is reached, the round **busts** and the stake is forfeited.
   - If the player's bankroll drops to `0`, the player is **Bankrupt (Game Over)**. All LEDs turn off and the board locks down.

---

## 2. 5-Person Team Organization & Individual Files

Each team member owns a dedicated file in `software/` containing plain-English instructions at the top and a starter assembly scaffold:

| Person | File | Primary Responsibility |
| :--- | :--- | :--- |
| **Person 1** | [`software/Person1_TimerAPI.asm`](software/Person1_TimerAPI.asm) | **Timer API Specialist:** Interfacing with `0x070` and `0x071` in the `PausableCountdownTimerAPI` peripheral. Loads duration, starts, pauses, resumes, and checks the hardware `DONE` timeout bit. |
| **Person 2** | [`software/Person2_MultiplierTable.asm`](software/Person2_MultiplierTable.asm) | **30-Value Array & Crash Engine:** Defines the 30 pre-computed payout values in RAM (bypassing SCOMP's lack of hardware multiplier) and implements a 16-bit PRNG LFSR to roll random crash thresholds. |
| **Person 3** | [`software/Person3_SwitchControls.asm`](software/Person3_SwitchControls.asm) | **Switch Controls & Debounce:** Reads `0x000`, implements rising-edge detection (release-to-trigger) so held switches don't repeat commands, handles Cash Out (SW1), and enforces pause interlock. |
| **Person 4** | [`software/Person4_DisplaysLEDs.asm`](software/Person4_DisplaysLEDs.asm) | **10-LED Money Meter & Displays:** Maps the 30 steps to the 10 DE10-Lite LEDs (`0x001`) as a thermometer bar, writes win/crash animations, and drives remaining deciseconds to HEX displays (`0x004`). |
| **Person 5** | [`software/Person5_RocketGame_Master.asm`](software/Person5_RocketGame_Master.asm) | **Master Integrator & FSM Lead:** Manages the main game loop, shared RAM variables, and merges everyone's routines into the final runnable program. |

---

## 3. Project Documentation

* **[Team Roles & Architecture](docs/ROCKET_GAME_RESPONSIBILITIES.md):** Full technical specification, shared RAM variables, and module interfaces.
* **[ECE 2031 Project Summary Guide](docs/PROJECT_SUMMARY_GUIDE.md):** Compliance guide for the 650-word report, detailing individual vs. team shared sections.

---

## 4. Hardware Connection & Quartus Workflow

The hardware countdown peripheral is maintained in the sister repository:
- Peripheral sources: `PausableCountdownTimerAPI/hardware/rtl/`
- Top-level Quartus project: `PausableCountdownTimerAPI/hardware/quartus/course-starter/`

To test on the DE10-Lite board:
1. Merge tested subroutines into `software/RocketGame.asm`.
2. Assemble using `scasm RocketGame.asm` to generate `RocketGame.mif`.
3. Set `init_file => "RocketGame.mif"` in Quartus `SCOMP.vhd` (or replace `SCOMP.mif`).
4. Compile and program the FPGA via Quartus Programmer.
