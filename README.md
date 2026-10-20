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

## Look & feel
Procedural monster (`monster_rig.gd`), player arms/flashlight (`viewmodel.gd`), humanoid for co-op teammates (`human_rig.gd`), generated horror audio (`proc_audio.gd`: drone, heartbeat, breathing, footsteps, sting), flickering lights, vignette/grain/red fear pulse shader.

## Real-AI monster (optional)
Menu → paste a **Claude API key**. Every ~10 s the monster's "director" (`scripts/ai_brain.gd`, model `claude-haiku-5-5`) gets a snapshot of what it *sensed* + its own memories/self-notes and returns JSON: tactic (investigate / search a hiding spot / ambush / taunt) and a whispered Arabic line. Chase, stare and kill logic stay rule-based so it is always fair. No key / no internet → the built-in AI runs as before.
- Only the player name and a play summary are sent; **microphone audio is never sent**.
- The key is stored in plain text in `user://settings.cfg` on the device. **Do not ship your own key inside a published APK/IPA** — run a small proxy server that holds the key and set `ai_url` to it.

## Offline learning AI (default, no internet)
`scripts/shadow_mind.gd` — the monster learns **on the device** and keeps learning forever (`user://shadow_mind.json`):
heat-map of where you walk, your favourite hiding spots, how often you run, whether you freeze under the stare, how loud you are.
It picks hunting tactics with a bandit (UCB1) and rewards the ones that find/catch you, so it adapts night after night. Each escape makes the next night harder (endless). Its spoken lines are generated from what it truly learned about you.
This is a learning AI, not a language model: running a real LLM fully offline on a phone needs a native plugin and a ~1 GB model file.

## LAN play
Host: menu → **استضافة** → shows your LAN IP and broadcasts the game (UDP 7778). Friends on the same Wi-Fi open the menu and tap your game in the list (or type the IP). Game traffic uses UDP 7777 — allow both ports in your firewall.
iOS may block UDP broadcast without a special Apple entitlement; if the list stays empty, type the host's IP manually.
Full screen: aspect = *expand* (no black bars), landscape forced on phones, **F11** toggles fullscreen on desktop, touch buttons respect the notch.

## Free "smart" AI on your own PC (Ollama, no cloud, no cost)
1. Install Ollama on a PC (free) and pull a model, e.g. `ollama pull qwen2.5:3b` (CPU) or `qwen2.5:7b` (GPU) — bigger = smarter.
2. Let the LAN reach it: set env `OLLAMA_HOST=0.0.0.0`, restart Ollama, allow TCP 11434 in the firewall.
3. In the game menu write `http://<PC-IP>:11434` and the model name. The monster's director then runs on your PC over Wi-Fi; if it is unreachable the built-in offline AI continues.
Android may block plain-http traffic depending on the export template; if so put the server behind https.

## Talking to the monster (offline)
- **Type**: tap/press **تكلّم (T)**, write e.g. `سيبني`, `من انت؟`, `لماذا`, `please` — `shadow_talk.gd` understands Arabic/English keywords offline (plead, who, why, greet, insult, threat, bargain, help).
- **Speak**: with the mic on, the game detects *that* you spoke, for how long and how loud (whisper vs shout). It does **not** transcribe words (no speech-to-text engine is bundled; a future STT plugin can call `Game.fire("report_speech", [pid, dur, peak, text])`).
- He only answers sometimes (cooldown + probability by what you said and his mood), may spare you, toy with you (7-second stare), or punish you (chase). Shouting or running mid-conversation = chase. If you speak from far away he just comes to investigate.
## Horror tricks & invented movement (`shadow_mind.gd`)
Blackout + sudden appearance, footsteps behind you, sudden silence then a thud, light-flicker bursts, far whispers, peeking at the end of a corridor. A pacing director builds tension, never repeats the same trick, and learns which tricks make you panic. Each patrol leg he invents a movement style (stalk / crawl on all fours / limp / walk) with random tempo.
