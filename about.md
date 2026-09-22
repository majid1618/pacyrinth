# Pacyrinth

**A 3D tilt-maze Pac-Man for mobile.**

Roll a golden pac-ball through a physics-driven 3D labyrinth by tilting your phone — or dragging your thumb. Eat dots, dodge ghosts, grab golden superpower stars, clear six themed stages, and spend your lifetime bank on wild powers from the shop.

- **Live version:** v0.13.0 · build 2026.09.22.1

---

## Table of contents
1. [What the game is](#1-what-the-game-is)
2. [Core gameplay loop](#2-core-gameplay-loop)
3. [Controls & input](#3-controls--input)
4. [The board & physics](#4-the-board--physics)
5. [Superpowers & the bank](#5-superpowers--the-bank)
6. [Stages](#6-stages)
7. [Audio & haptics](#7-audio--haptics)
8. [Project architecture](#8-project-architecture)
9. [Physics layer plan](#9-physics-layer-plan)
10. [Data-driven maze design](#10-data-driven-maze-design)
11. [Technology stack](#11-technology-stack)
12. [Engineering highlights](#12-engineering-highlights)
13. [Build & deploy pipeline](#13-build--deploy-pipeline)
14. [File reference](#14-file-reference)
15. [Roadmap](#15-roadmap)

---

## 1. What the game is

Pacyrinth reimagines the classic *Pac-Man* top-down chase inside a **working 3D physics board**. There are no discrete "arrows"—the board is a real tilting surface:

- Tilt the physical phone (or drag) to slant the whole board and steer the ball by gravity.
- The board is a real rigid body; walls, floor and rim have mass properties (friction, bounce) tuned per stage material.
- The ball is a genuine rolling solid sphere — it rolls, climbs off wall strikes, and can be sent *through* walls by the Invisibility power, all except the floor.

It runs entirely on the phone, portrait orientation, rendering on the mobile Vulkan/Mobile pipeline.

---

## 2. Core gameplay loop

1. **Collect**: roll over all glowing dots (★ stars are optional power-ups).
2. **Dodge**: 4 BFS-chasing ghosts patrol the maze.
3. **Clear**: reach the glowing ringed goal hole to win the stage and move on.
4. **Earn**: every action banks permanent score into your **BANK**.
5. **Spend**: buy superpowers from the shop for the bank points.
6. **Progress**: 6 stages loop endlessly, with progress, unlocked stage and bank all persisted.

Score sources:

| Action | Points |
|---|---|
| Collect a dot | 10 |
| Collect a dot during **DOT FEVER** | 20 |
| Crush a ghost while **GIANT** | +200 |
| Clear a stage | +100 |
| Time bonus on clear | +5 / remaining second |

Lives: start with 3. Losing all 3 = Game Over (score persists; retry restarts the stage at your current bank/progress).

---

## 3. Controls & input

**Three steering modes (switchable in SETTINGS):**

| Mode | Behaviour |
|---|---|
| **AUTO (default)** | Uses the tilt/gravity sensor when present; falls back to touch drag if the sensor is dead |
| **TILT** | Sensor only, touch steering disabled |
| **TOUCH** | Drag anywhere to steer (virtual tilt stick, ~160 px radius) |

- **Auto-calibration** – on launch the game samples ~14 physics frames of gravity to learn your current holding pose as "neutral", so there's no phantom slope. **CAL** / **RECALIBRATE** re-zeroes anytime.
- **ROTATE BOARD 180°** – rotates the whole playground 180° on screen (visual flip only). Default ON (persisted).
- **REVERSE TILT DIRECTION** – flips the sensor/drag axes for devices whose sensors point the "wrong" way. Default OFF (persisted). The two toggles are independent, so any phone can find a comfortable combination.
- **SENSITIVITY** slider – 1.0×–3.0× multiplier on both tilt and drag.
- **MIRROR LEFT-RIGHT** – swaps steering orientation (persisted).
- **BRAKE ASSIST** – the ball cruises fast while you steer, but brakes hard (3.2× damping) the instant you release, so high speed stays controllable for dot-sniping.
- **RESCUE** – hold your finger on the ball ~0.9s to teleport it back to start for free (moving your finger cancels it).
- **PAUSE** – opening SETTINGS or the STORE while playing pauses the game: ghosts freeze, the ball freezes, powers hold. Nothing hunts you while you shop.
- **RESTART RUN** – a button in SETTINGS that restarts the current stage clean (score reset, full lives) *without costing a life*. Use it whenever the ball slips into the void and you'd rather not burn a life; the desktop `R` key does the same.
- Desktop fallback: `WASD`/arrow keys tilt, mouse-drag simulates touch, `R` restarts.

### Home hub & meta screens

The game boots into a **HOME** hub before any level: **PLAY NEW GAME**, **SETTINGS**, **STORE**, **MY PROGRESS**, **TOP SCORES**, **ABOUT THE GAME**, and **ACCOUNT**. Reachable again any time via the **☰ MENU** button (top-left) or **HOME** on the win/lose screens.

- **MY PROGRESS** – current stage, stages unlocked, bank, best score (persisted).
- **TOP SCORES** – local leaderboard of your best runs (name + score + stage, top 8). Worldwide/cloud sync is planned.
- **ACCOUNT** – pick a leaderboard name; **SAVE & LOGIN** persists it (full account login planned). **RESTORE PURCHASES** is a no-op placeholder until IAP lands.
- **STORE** pre-game works exactly like in-game, so you can spend bank before a run.

---

## 4. The board & physics

- **Board** is a Node3D whose pitch (`rotation.x`) and roll (`rotation.z`) are driven by normalized sensor/touch input, smoothed over frames — never teleported, always a real sloped rigid surface.
- **Ball** is a `RigidBody3D` with physics rotation (it *rolls*, not glides), visible tumble spots, a float-steered animated pac-face, chomping mouth, and velocity-based braking.
- **Walls & rim** are static colliders with a per-material `PhysicsMaterial` (friction + bounce).
- **Invisibility** drops only the wall layer from the ball's collision mask — the floor and invisible safety rim stay solid, so phasing never lets you fall into the void.
- **void watchdog** – if the ball is ever somehow lost below y=-4m or beyond the boundary, it auto-respawns at a life cost; prefer **RESTART RUN** in SETTINGS for a no-penalty do-over.
- **real-time shadows** from the main lamp swing as the board tilts.

Per-material constants:

| Stage | Friction | Bounce | Damping |
|---|---|---|---|
| WOOD | 0.25 | 0.32 | 0.38 |
| STONE | 0.18 | 0.40 | 0.31 |
| MARBLE | 0.10 | 0.46 | 0.26 |
| IRON | 0.07 | 0.55 | 0.21 |
| ICE | 0.03 | 0.60 | 0.14 |
| NEON | 0.03 | 0.72 | 0.10 |

---

## 5. Superpowers & the bank

**The bank** – *every* point you earn lands permanently in a cumulative **BANK** saved across sessions. The shop spends it.

**Golden stars** — 4 spawn at random open cells each level. Collecting one instantly grants a random *core* power (Invisibility / Rocket / Giant) for 15 seconds.

**The shop** (SHOP button) sells powers for bank points (**all last 15 s** unless noted):

| Power | Cost | Effect |
|---|---|---|
| INVISIBILITY | 50 | Phase through walls (floor & rim stay solid); ghosts lose your trail |
| MAGNET | 75 | Dots within ~4 m fly toward you |
| SHIELD | 80 | Ghosts cannot touch you |
| SLOW GHOSTS | 90 | Ghosts crawl at 35% speed |
| ROCKET | 100 | ~5× speed burst (26 m/s vs 14 m/s) + wider tilt authority |
| DOT FEVER | 110 | Double dot points |
| GHOST FREEZE | 120 | Ghosts stop dead |
| GHOST REPEL | 140 | Ghosts flee from you |
| GIANT | 150 | Grow to 1.75×, crush ghosts (+200 each; they respawn home) |
| EXTRA LIFE | 200 | +1 life instantly |

Power status is shown as a live countdown banner ("★ INVISIBILITY 12s").

---

## 6. Stages

Six themed stages loop endlessly; progress and unlocked stage persist.

| # | Material | Look & physics personality |
|---|---|---|
| 1 | WOOD | Wood-grain, grippy, medium bounce |
| 2 | STONE | Rough hewn, slicker |
| 3 | MARBLE | Pale veined, smooth + mild bounce |
| 4 | IRON | Brushed metallic, fast + springy |
| 5 | ICE | Pale translucent blue, near-frictionless slides |
| 6 | NEON | Dark cellular magenta, pinball bounce |

Advanced stage brings +0.05 m/s ghost speed to keep the chase tense.

---

## 7. Audio & haptics

**All audio is synthesized at runtime** — there are zero audio asset files. A `Sound` autoload (`scripts/sound_bank.gd`) builds 16-bit PCM `AudioStreamWAV`s in code (22050 Hz mono), cycling them through a pool of 8 `AudioStreamPlayer`s so sounds never cut each other off.

| Sound | Synthesis design | Trigger |
|---|---|---|
| dot | 880→1320 Hz chirp (65 ms) | each dot collected |
| bounce | 140→55 Hz sine thud + noise click (120 ms); louder/faster with ball speed | any body contact (walls or floor), 90 ms cooldown |
| finish | C5→E5→G5→C6 arpeggio (400 ms) | reaching the goal |
| power | 280→1400 Hz shimmering sweep (~330 ms) | star pickup / shop purchase |
| star | twin chime 1568+2093 Hz (280 ms) | star collected |
| hurt | descending tremolo square (300 ms) | losing a life |

**Background music** — one MP3 track per stage (`game/music/stage1.mp3` … `stage5.mp3`, cycling by stage index) plays on a dedicated `AudioStreamPlayer`, looping until the run ends; it stops on game over / win / exit to menu.

A **SOUND EFFECTS** toggle and a separate **BACKGROUND MUSIC** toggle persist in settings.

**Haptics** — `Input.vibrate_handheld` drives the Android VIBRATE permission: soft 25 ms on dots, 50 ms on ghost crush, 60 ms on power activation, 40–90 ms on star, 80 ms on rescue, 120 ms on hit.

---

## 8. Project architecture

Autoloads (run before any scene):

```
Game   scripts/game_manager.gd   — rules, state machine, economy (bank), powers, settings persistence, version
Sound  scripts/sound_bank.gd     — procedural audio synthesis + playback pool
```

Scene `scenes/main.tscn` → `Main` (Node3D), built 100% in code at `_ready`:

```
Main (main.gd)
├── Board (board_tilt.gd)     – the tilting surface + input
│   ├── Floor, Walls, Rim     – static colliders + textured meshes
│   ├── Dots (holder)         – 100+ dot areas + 4 star areas
│   ├── Goal                  – goal area + animated ring
│   ├── PacBall (ball.gd)     – the player rigid body
│   └── Ghosts ×4 (ghost.gd)  – CharacterBody3D pathers
├── CameraRig (camera_rig.gd) – follow cam
└── HUD (hud.gd, CanvasLayer) – HUD, settings card, shop, win/lose panels
```

Every mesh, material, collider and the environment are generated at runtime from code — the `.tscn` only holds the node tree with scripts. Levels are not hand-authored scenes; the maze is data.

---

## 9. Physics layer plan

Separating layers was essential for the Invisibility-feels-solid fix:

| Bit | Layer | Contents | During INVISIBILITY |
|---|---|---|---|
| 1 | Walls | only the maze walls | ignored (phase through) |
| 2 | Ground | floor + invisible safety rim | always solid |
| 4 | Player | the ball | — |
| 8 | Ghosts | ghost bodies + catch zones | feared/ignored |
| 16 | Pickups | dots, stars, goal | still collectible |

INVISIBILITY flips **only** bit 1 off the ball's collision mask — so it passes through walls but gravity, floor, and the safety rim keep it trapped on the board.

---

## 10. Data-driven maze design

The maze comes from a single source of truth: `scripts/maze_data.gd` holds a **15×15 ASCII GRID** (`#` wall, `.` dot, `S` start, `G` goal, `a–d` ghost spawns) plus BFS helpers. `MazeData.parse()` turns it into world data; the `validate_maze.gd` headless test proves every corridor it reachable.

```
const GRID := [
    "###S###########".repeat(...) # 15 rows
    ...
]
```

Ratio: **109 collectible dots** over a 15×15 layout. One dot per open cell (except start/goal), ghosts in the 4 corners of the map, start bottom-right, goal top-left.

---

## 11. Technology stack

| Layer | Technology |
|---|---|
| Engine | **Godot 4.7.2** (Stable) — GDScript, custom build |
| Renderer | **Mobile** pipeline (`renderer/rendering_method="mobile"`), Vulkan Forward Mobile, MSAA x2 |
| Language | **GDScript** (typed where hot: `:=`, signatures) |
| Physics | Godot's built-in 3D physics engine (`RigidBody3D` + `CharacterBody3D` + `Area3D`, `PhysicsMaterial`, `PhysicsBody3D.contact_monitor`) |
| Maze logic | Hand-written **BFS** pathfinding (`maze_data.gd`) for ghost chase/scatter/evade |
| Audio | **Runtime-synthesized** PCM (no asset files) via `AudioStreamWAV` |
| Textures | **Procedural** `NoiseTexture2D` (`FastNoiseLite`) — wood, stone, marble, iron, ice, neon — no image assets |
| UI | Godot `Control` nodes built in code (Label, Button, HSlider, OptionButton, ScrollContainer) |
| Persistence | Godot `ConfigFile` → `user://settings.cfg` (JSON-ish INI) |
| Mobile target | **Android** (arm64-v8a + armeabi-v7a), portrait, immersive full-screen |
| Tooling | Godot editor CLI, JDK 17, Android SDK (platform 34/35), adb |

**Why Godot 4 over Unity:** the original design guide was Unity-based, but the user chose Godot 4 — the classic-game architecture was translated to GDScript, with Godot's `RigidBody3D` physics replacing Unity's, `CharacterBody3D.move_and_slide()` for ghosts, `Area3D` for pickups, and `Input.get_gravity()`/`get_accelerometer()` for tilt.

---

## 12. Engineering highlights

- **Procedural everything** – textures, audio, meshes, materials, environment are all generated in code; the repo ships essentially no binary assets beyond the engine icon. This keeps the APK tiny (~55 MB) and the project infinitely tintable.
- **Physics-layer discipline** solved the "invisibility makes you fall through the floor" bug by separating walls from floor on different layers.
- **Sensor calibration** – device gravity axes differ per handset; two independent persisted toggles normalize geometry (ROTATE BOARD 180°) and input (REVERSE TILT DIRECTION) across devices.
- **One-Mask-Edit** powers: Invisibility toggles a single collision bit live; Giant/Shield/Slow/Freeze/Repel all read one `Game.is_power_active(id)` whether spares came from a star or the shop.
- **Brake assist** fixes the classic "fast = uncontrollable" tilt problem by decoupling cruising speed from stopping authority.
- **Deferred-safety** – scene changes and `queue_free` in physics callbacks are deferred; pickups check `is_queued_for_deletion` to avoid double-collect race conditions.
- **Auto-calibration** samples gravity for ~14 frames so any hold posture becomes neutral with no phantom slope.

---

## 13. Build & deploy pipeline

A fully scripted Windows toolchain (in `tools/`) downloads and configures everything:

```
tools/
├── godot/           Godot 4.7.2 editor/engine (headless CLI for all builds/tests)
├── jdk17/           Android Java toolchain
├── android-sdk/     platform-tools (adb), platforms 34+35, build-tools
└── debug.keystore   debug signing (androiddebugkey / android)
```

Standard commands (headless):

```
# boot smoke test
godot --headless --path game --quit-after 40
# maze validation
godot --headless --path game --script res://tests/validate_maze.gd   # "MAZE OK: 109 dots"
# export APK
godot --headless --path game --export-debug "Android" builds/pacyrinth.apk
# deploy + verify (adb device R5CRA023H7T)
adb uninstall com.pacyrinth.game; adb install builds/pacyrinth.apk
adb shell monkey -p com.pacyrinth.game -c android.intent.category.LAUNCHER 1
adb logcat -d -s godot:*    # expect clean boot + "tilt sensor active"
```

The same `Game`/`Sound` autoloads and scene run identically on desktop (an editor window) and the phone. Package: `com.pacyrinth.game`, version 1.0 (code 1), permission: `android.permission.VIBRATE`.

---

## 14. File reference

| File | Purpose |
|---|---|
| `project.godot` | portrait/mobile config, autoloads `Game`+`Sound`, input map, sensors |
| `scenes/main.tscn` | scene tree with script bindings |
| `scripts/game_manager.gd` | rules, state machine, bank/economy, powers, settings persistence |
| `scripts/stages.gd` | 6 stage definitions: texture recipe, colors, physics consts |
| `scripts/maze_data.gd` | 15×15 ASCII GRID + BFS helpers |
| `scripts/main.gd` | level builder: environment, texture/material factory, floor/walls/rim/dots/stars/goal/spawns |
| `scripts/board_tilt.gd` | sensor/touch input, auto-calibration, mode filter, inversion |
| `scripts/ball.gd` | player rigid body, rolling, powers, pickups, bounce sounds |
| `scripts/ghost.gd` | BFS chase/scatter/evade AI, freeze/slow/stun, crush respawn |
| `scripts/camera_rig.gd` | follow camera |
| `scripts/hud.gd` | HUD + settings card + shop + win/lose panels |
| `scripts/sound_bank.gd` | procedural audio synthesis + playback |
| `tests/validate_maze.gd` | headless maze/connectivity validator |
| `export_presets.cfg` | Android export target |
| `SETUP-GUIDE.md` | build/run/troubleshoot doc |

---

## 15. Roadmap

Ideas that didn't make today's build:
- More stage themes (Lava, Candy, Cyber, Water) and animated stage transitions.
- Rolling soundtrack that intensifies per stage.
- Boss ghosts or a peril-meter that speeds ghosts as dots deplete.
- Persistent glyph unlocks / customizations bought with bank.
- Local high-score table & shareable score.
- Controller + landscape support for tablet play.
- More procedural detail: skirting walls, corner trim, entry/exit ramps.
