# Verification Findings

Date: 2026-09-20

## Checks performed

- Godot `4.7.2.stable.official.ed1daf0bf` loaded `game/project.godot` successfully with `--headless --editor --quit`.
- A USB-connected Android device was detected and authorized: Samsung SM-F711U1, serial `R5CRA023H7T`.
- The existing `builds/pacyrinth.apk` installed successfully with `adb install -r`.
- The installed package `com.pacyrinth.game` launched through its registered Godot launcher. The process remained alive after launch, and the captured log contained no fatal exception.
- Installed APK SHA-256: `c52bf80d18db58e241fe37aff813a6ee9201cb69d7250af8024cb7488f89447a`.

## Findings

### Fresh Android export is currently blocked

The attempted export command was:

```sh
./Godot_v4.7.2-stable_linux.x86_64 --headless --path game --export-debug Android ../builds/pacyrinth.apk
```

Godot reported three local configuration problems:

1. Android export templates are missing from `~/.local/share/godot/export_templates/4.7.2.stable/`.
2. No debug keystore is configured in Godot Editor Settings or the export preset. The preset contains a Windows-style path (`E:/3d-pacyrinth/tools/debug.keystore`), which is not valid on this Linux workstation.
3. A valid Java SDK path is not configured in Godot Editor Settings.

Because the export failed, the APK installed during this verification is the existing artifact rather than a newly generated APK.

### Installed APK is stale relative to the project configuration

The installed APK reports `versionCode=1` and `versionName=1.0`. The current Android export preset specifies `version/code=2` and `version/name="0.12.3"`. Regenerate the APK after fixing the export toolchain before treating it as a current release candidate.

### Initial activity probe was incorrect, not an app failure

Launching the guessed component `com.pacyrinth.game/.GodotApp` returned an activity-not-found error. Resolving the package launcher and using `adb shell monkey -p com.pacyrinth.game 1` successfully started the app. The registered launcher is `com.godot.game.GodotAppLauncher`.

## Recommended remediation

Install the matching Godot 4.7.2 Android export templates, set the Linux JDK 17 and Android SDK paths in Godot Editor Settings, and replace the Windows keystore path with a valid local debug keystore. Then rerun the export and repeat the `adb install` and launch checks.