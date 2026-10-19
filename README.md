# التسلسل: الظل القاتل — Sequence: Killer Shadow

First-person stealth-horror in **Godot 4.3+** (GDScript). Solo or 2–4 player co-op (ENet).
Full design doc: [`docs/game_design_ar.txt`](docs/game_design_ar.txt)

## Run
1. Install Godot 4.3 or newer (standard build, not .NET).
2. Open Godot → **Import** → select `project.godot` → press **F5**.

## Controls
| Key | Action |
|---|---|
| WASD / Mouse | Move / look |
| Shift | Run (loud) |
| C / Z | Toggle crouch / crawl |
| E (hold) | Operate generator, lever, wheel |
| E | Hide (crouch near crates) / leave hiding |
| F | Flashlight |
| Esc | Release mouse |

## Escape sequence
Generator lever (noise!) → emergency lever in control room → hydraulic wheel at main door → run out through the door.

## How the monster works (`scripts/monster.gd`)
- **Senses:** sight (cone + raycast) and hearing (player `noise_level`: posture + optional microphone).
- **7-second rule:** spots you → freezes and stares 7 s → any movement/noise = instant chase.
- **Adaptive:** remembers where it saw you and which crates you hid behind, patrols them more, gets more aggressive each time you survive a stare.
- **Confrontation:** climbs onto your hiding spot, turns slowly, calls your name (HUD shows name + health bar), then decides.
- **Dynamic kills:** `crush_crate`, `reach_through`, `stomp_lift`, `intercept_slam` — chosen from your posture, positioned/randomised from a seed.
- Name is whispered with the OS text-to-speech (`DisplayServer.tts_speak`).

## Privacy
The player types their own name in the menu. Microphone loudness is measured locally only (optional checkbox) — audio is never recorded or sent.

## Multiplayer
Host → share your IP (UDP **7777**, forward the port for internet play) → friends press Join → host presses Start. The host's machine runs the monster.

## Project layout
```
project.godot
scenes/   main_menu.tscn, game.tscn   (thin; level is built in code)
scripts/  game.gd (autoload)  mic_listener.gd (autoload)  network_manager.gd (autoload)
          world.gd  level_builder.gd  player.gd  monster.gd  hud.gd
          interactable.gd  hide_zone.gd  exit_zone.gd  util.gd
docs/     game_design_ar.txt
```

## Push to GitHub
```bash
git init
git add .
git commit -m "Initial Godot project"
git branch -M main
git remote add origin https://github.com/<you>/sequence-killer-shadow.git
git push -u origin main
```

## Known limits / next steps
- Placeholder graphics (boxes/capsules) — replace with real models, textures, animations and horror audio.
- Level is a procedural test basement; build a real one with a baked NavigationMesh.
- Co-op: first player to cross the exit wins for the team; no spectator camera yet.
- "Closing the door at the last moment" is simplified to reaching the exit zone.

## CI builds (GitHub Actions)
- `.github/workflows/android.yml` → debug-signed **APK** (artifact `SequenceKillerShadow-apk`)
- `.github/workflows/ios.yml` → **unsigned IPA** (artifact `SequenceKillerShadow-ipa`); sideload with AltStore/Sideloadly or sign it yourself
- Run from the repo's **Actions** tab (Run workflow) or on every push to `main`.
- Phones: touch controls are built in (left = joystick, right = look, buttons E / RUN / C / Z / F).
