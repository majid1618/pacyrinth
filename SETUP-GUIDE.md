# Pacyrinth — Setup & Play Guide

A 3D tilt-maze Pac-Man style game for Android, built with **Godot 4.7.2**.
This project implements the architecture from `labyrinth-pacman-game-guide.md`, translated from 2D Unity/C# to 3D Godot/GDScript.

---

## 1. What was installed (by the setup automation)

Everything lives in `E:\3d-pacyrinth\tools\`:

| Tool | Path | Purpose |
|---|---|---|
| Godot 4.7.2 editor | `tools\godot\Godot_v4.7.2-stable_win64.exe` | The game engine / IDE |
| Temurin JDK 17 | `tools\jdk17\` | Required by Godot to sign/build APKs |
| Android SDK | `tools\android-sdk\` | `platform-tools` (adb), platforms 34+35, build-tools, USB driver |
| Export templates | `%APPDATA%\Godot\export_templates\4.7.2.stable\` | Prebuilt engine binaries used when exporting |
| Debug keystore | `tools\debug.keystore` | Signs your test APKs (password: `android`) |

Editor settings were pre-configured at `%APPDATA%\Godot\editor_settings-4.7.tres`
so Godot already knows where the JDK/SDK/keystore are.

Check `tools\finish-setup.log` — it must end with `=== ALL SETUP STEPS FINISHED ===`.

---

## 2. Run the game on your PC right now (no phone needed)

1. Double-click `tools\godot\Godot_v4.7.2-stable_win64.exe`.
2. Click **Import**, select `E:\3d-pacyrinth\game\project.godot`, click **Import & Edit**.
3. Press **F5** (Run Project).

**Desktop controls** (keyboard simulates phone tilt):
- `WASD` or `Arrow keys` — tilt the board
- `R` — restart level

The board tilts, gravity rolls the ball, ghosts chase you via BFS pathfinding.

---

## 3. Test on your Android phone

### One-time phone setup
1. **Settings → About phone → tap "Build number" 7 times** → unlocks Developer Options.
2. **Settings → Developer options → enable "USB debugging"**.
3. Plug the phone into this PC via USB.
4. If Windows doesn't recognize it:
   - Accept the "Allow USB debugging?" popup on the phone (check *Always allow*).
   - Some brands need their own driver; a generic fallback is installed at
     `tools\android-sdk\extras\google\usb_driver` (point Device Manager at it if needed).
5. Verify the connection:

```powershell
E:\3d-pacyrinth\tools\android-sdk\platform-tools\adb.exe devices
```

You should see your device ID followed by `device`.

### Option A — one-click deploy from the editor
With the project open in Godot: **Editor → Editor Settings → Export → Android** should already show your paths (pre-configured).
Then press **F5** — if an Android device is connected, Godot asks whether to run on **Android device** instead of the desktop. Choose it. That's it.

### Option B — build an APK file
In Godot: **Project → Export… → Android → Export Project** (uncheck *Export With Debug* only for store builds; keep debug for testing).
Or from the command line:

```powershell
& "E:\3d-pacyrinth\tools\godot\Godot_v4.7.2-stable_win64.exe" --headless --path "E:\3d-pacyrinth\game" --export-debug "Android" "E:\3d-pacyrinth\builds\pacyrinth.apk"
```

Install to the connected phone:

```powershell
E:\3d-pacyrinth\tools\android-sdk\platform-tools\adb.exe install -r E:\3d-pacyrinth\builds\pacyrinth.apk
```

Launch **Pacyrinth** on the phone and tilt away.

> First export takes a minute while Godot imports assets. Tilt sensitivity lives in
> `game\scripts\board_tilt.gd` (`max_tilt_deg`, `smoothing`) — tune to taste.

---

## 4. How the code maps to the original guide

| Guide concept | This project |
|---|---|
| §3 Maze grid = single source of truth | `scripts/maze_data.gd` — ASCII map (`#` wall, `.` dot, `S` start, `G` goal hole, `a-d` ghost spawns) + cell↔world conversion |
| §4 Tilt input (`Input.acceleration`) | `scripts/board_tilt.gd` — reads `Input.get_gravity()` (with accelerometer fallback), rotates the whole board ±11° so real gravity rolls the ball |
| §4 Ball physics (Rigidbody + circle collider) | `scripts/ball.gd` — `RigidBody3D`, sphere shape, friction material, zero-bounce walls |
| §5 Dots spawned from grid data | `main.gd → _build_dots()` instantiates Area3D dots at every `.` cell |
| §6 Goal hole trigger | `main.gd → _build_goal()` — pulsing green ring; ball shrinks and sinks in |
| §7 Ghost BFS pathfinding | `maze_data.gd → bfs_next_step()`; `scripts/ghost.gd` walks cell-to-cell, re-pathing at every junction, prefers not reversing (classic feel) |
| §7.5 Scatter/chase personalities | Each ghost alternates **7s chase → 4s scatter** toward its own corner, with staggered phase offsets |
| §8 GameManager singleton | `scripts/game_manager.gd` autoload — score, 3 lives, invulnerability window, win/lose state |
| §9 UI | `scripts/hud.gd` — score, lives, dots-left, win/lose panels with retry button |
| §10 Polish | Chomping mouth + eyes tracking velocity, emissive neon materials, haptic vibration on pickup/catch, smooth camera follow |

### Physics layers
1. walls/floor · 2. ball · 3. ghosts (bit value 4) · 4. pickups (bit value 8)

---

## 5. Validate the maze anytime

```powershell
& "E:\3d-pacyrinth\tools\godot\Godot_v4.7.2-stable_win64.exe" --headless --path "E:\3d-pacyrinth\game" --script res://tests/validate_maze.gd
```

Prints `MAZE OK` with dot count, or lists unreachable cells.

## 6. Design your own levels

Edit `GRID` in `scripts/maze_data.gd`. Keep rows equal width, border solid,
and run the validator above. Add rows/cols freely — everything (walls, dots,
camera framing) scales automatically.

## Controls & input plan
- **Game boots into a HOME hub**: PLAY NEW GAME, SETTINGS, STORE, MY PROGRESS, TOP SCORES, ABOUT, ACCOUNT. Reachable anytime via **☰ MENU** (top-left) or the **HOME** button on win/lose screens.
- **SETTINGS button** (top-right) opens the settings card:
  - **CONTROLS**: `AUTO` (tilt if sensor present, touch always works) / `TILT` only / `TOUCH` only
  - **SENSITIVITY** slider (1.0x–3.0x), applies to tilt and drag
  - **MIRROR LEFT-RIGHT** toggle
  - **SOUND EFFECTS** toggle
  - **ROTATE BOARD 180°** toggle (also flips sensor axes)
  - **RECALIBRATE NEUTRAL POSE**
- **Opening SETTINGS or STORE pauses the game** (ghosts freeze, powers hold).
- Tilt auto-calibrates to your holding pose at launch; **CAL** re-zeroes anytime.
- The ball has **brake assist**: sharp stopping when you release steering, so high speed stays controllable.
- Touch drag radius ~160px for quick thumb steering; desktop: `WASD`/arrows, mouse-drag, `R` (restart level).

### Rescue & safety nets
- **Hold your finger on the ball (~1s)** → *"RESCUE"* progress fills, ball returns to start for free. Moving your finger cancels it.
- If the ball ever escapes the board and falls into the void, the watchdog auto-respawns it (costs one life).
- Invisible tall rim + speed cap make escapes nearly impossible in the first place.

## Stages
Six stages loop endlessly, progress saved. Each swaps textured wall/floor material *and* physics — walls are **bouncy**, tuned per material:

| # | Material | Bounce | Feel |
|---|---|---|---|
| 1 | WOOD | 0.32 | grippy |
| 2 | STONE | 0.40 | mild |
| 3 | MARBLE | 0.46 | smooth |
| 4 | IRON | 0.55 | fast, springy |
| 5 | ICE | 0.60 | near-frictionless slides |
| 6 | NEON | 0.72 | pinball |

Walls/floors use procedural noise textures (wood grain, marble veins, brushed iron, cellular neon panels) plus roughness variation; two shadow-casting lamps and fog dress the scene. Ghosts gain +0.05 m/s per stage.

## The ball
- Rolls like a real marble (physics rotation on) with visible tumble spots; the pac-face floats above and turns toward travel direction.
- Top speed 14 m/s normally, 26 m/s under ROCKET; brake assist keeps it controllable.

## Stars & Superpowers
- **4 golden stars** spawn at random spots each level → grant a random core power for **15 seconds**: INVISIBILITY / ROCKET / GIANT.
- Every point you earn also lands in your permanent **BANK** (dots +10, +20 during fever; ghost crush +200; stage clear +100 + time bonus).
- **SHOP** button sells powers from the bank:

| Power | Cost | Effect |
|---|---|---|
| INVISIBILITY | 50 | Phase through walls only — floor & safety rim stay solid |
| MAGNET | 75 | Dots within ~4m fly to you |
| SHIELD | 80 | Ghosts can't touch you |
| SLOW GHOSTS | 90 | Ghosts crawl at 35% speed |
| ROCKET | 100 | ~5x speed burst + wider tilt authority |
| DOT FEVER | 110 | Double dot points |
| GHOST FREEZE | 120 | Ghosts stop dead |
| GHOST REPEL | 140 | Ghosts flee from you |
| GIANT | 150 | Grow huge, crush ghosts (+200 each, they respawn home) |
| EXTRA LIFE | 200 | +1 life instantly |

### Difficulty balance
| Knob | File | Default |
|---|---|---|
| Ball damping per stage | `stages.gd` `damp` | 0.10–0.38 |
| Ball top speed | `ball.gd` `BASE_MAX_SPEED` | 14 m/s |
| Brake strength when idle | `ball.gd` `BRAKE_MULT` | 3.2x |
| Ghost speeds | `ghost.gd` `SPEEDS` | 1.55–2.0 m/s (+0.05/stage) |
| Board max angle | `board_tilt.gd` `max_tilt_deg` | 22° (+12° rocket) |
| Sensitivity multiplier | settings slider (`Game.sensitivity`) | 2.0x |

### Physics layers
1 = walls · 2 = floor+rim · 4 = ball · 8 = ghosts · 16 = pickups. INVISIBILITY drops only layer 1 from the ball's mask.

## Lighting
Two hanging lamp fixtures (visible shades + glowing bulbs) light the board; the main lamp casts real-time shadows from the tilting walls. Glow/bloom makes dots and neon pop.

---

## 7. Troubleshooting

- **`adb` not found / no devices**: try a different USB cable (charge-only cables are the #1 cause), re-accept the debugging popup, restart `adb kill-server && adb start-server`.
- **App dies instantly with "Failed to create vulkan window" in logcat**: wedged graphics state or corrupted incremental install — run `adb uninstall com.ramlisoft.game.pacyrinth`, reinstall fresh, relaunch. If it persists, reboot the phone.
- **Verify sensors are being read**: `adb logcat -d -s godot:* | findstr "tilt sensor"` should print `tilt sensor active, raw=...`.
- **Export fails mentioning Java/SDK**: check Editor Settings → Export → Android paths match section 1 (keys are `export/android/*` in Godot 4.7).
- **Ball too twitchy/sluggish on phone**: tune `max_tilt_deg` (lower = gentler) and `smoothing` in `board_tilt.gd`; raise `linear_damp` in `ball.gd` to make it stop sooner.
- **Ghost colors**: randomized vivid HSV per run in `ghost.gd → setup()` (golden-ratio hue spacing keeps all four distinct).
