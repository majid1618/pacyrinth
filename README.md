# Pacyrinth

Pacyrinth is a Godot 4 mobile tilt-maze game with Pac-Man-inspired scoring, ghosts, pellets, multiple stages, and touch-friendly HUD controls. The game is designed for portrait Android screens and also supports keyboard controls when run from the editor.

## Project layout

- `game/` contains the Godot project, main scene, gameplay scripts, and smoke tests.
- `game/scripts/` contains the ball, board tilt, camera, maze, ghost, HUD, game manager, stages, and sound systems.
- `game/tests/` contains focused validation and restart/startup test scenes.
- `builds/` is ignored by Git and is used for local Android exports.
- `tools/` contains local SDK, JDK, and setup assets and is ignored by Git.

## Requirements

- Godot `4.7.2` with Android export templates.
- Android SDK with platform and build tools installed.
- JDK 17.
- `adb` for installing to a USB-connected Android device.

The project uses the Android preset in `game/export_presets.cfg`. It targets portrait orientation, supports `arm64-v8a` and `armeabi-v7a`, and uses the package name `com.pacyrinth.game`.

## Run locally

Open `game/project.godot` in Godot, or run:

```sh
./Godot_v4.7.2-stable_linux.x86_64 --editor --path game
```

Run the main scene from the editor. Keyboard input is mapped as follows:

- `W` / Up: tilt up
- `A` / Left: tilt left
- `S` / Down: tilt down
- `D` / Right: tilt right
- `R`: restart

On Android, the game uses the device sensors configured in `game/project.godot`.

## Validate and export

Check that the project loads without editor errors:

```sh
./Godot_v4.7.2-stable_linux.x86_64 --headless --path game --editor --quit
```

After installing the Godot Android export templates and configuring the SDK/JDK in Godot Editor Settings, export the Android debug APK:

```sh
./Godot_v4.7.2-stable_linux.x86_64 --headless --path game --export-debug Android ../builds/pacyrinth.apk
```

The export path is relative to `game/`, so the APK is written to `builds/pacyrinth.apk` at the repository root.

## Install on Android

Enable USB debugging, connect the device, and verify it is authorized:

```sh
adb devices -l
adb install -r builds/pacyrinth.apk
adb shell monkey -p com.pacyrinth.game 1
```

## Current verification

The project passed the headless Godot editor-load check on September 20, 2026. The APK available in `builds/` was installed successfully on a connected Samsung SM-F711U1 and launched without a fatal exception. That artifact predates the current export preset, so it should be regenerated after the Android export toolchain is configured; see `findings.md` for details.