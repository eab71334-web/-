# بيت الصفصاف — Willow House

First-person paranormal-investigation horror (Godot 4.3+, GDScript). Original story and characters; the atmosphere is inspired by classic "haunted farmhouse" horror films.

## The game
You are the field investigator of a small paranormal team (Dr. Rana and Kamal guide you by radio from the van). An isolated 1976 farmhouse, a family of five, and a ghost with a clear backstory. Goal: discover the house's secret and free the family.
- **Place**: cellar, ground floor, upper floor, attic, garden, barn, well, willow tree. Floors are connected by stairs; doors really swing (the ghost opens and slams them).
- **Family** (talk with E): Saeed (father), Layla (mother), Maryam (16, sleepwalker who draws), Ziad (10, talks to "the lady"), Grandma Halima. Each one gives story and hints; what they say changes with your progress.
- **Tools (limited shared battery)**: flashlight (F), **camera** (R, then E to shoot — evidence exists only in the viewfinder), **audio recorder** (V — record 8 s in "close" places to catch her voice, EVP). Batteries are hidden around the house.
- **The haunting**: distant footsteps, humming, doors moving, flicker, falling objects, a shadow at the end of a hall. She is almost never seen: only through the lens, as a flicker, and fully only in the final scene. The haunting escalates; from chapter 4 she can hunt you (stay still, quiet, hide).
- **Story chain**: meet the family → fuse box in the cellar → photograph 3 traces → record 2 voices → collect Maryam's 4 pages → safe (date from the pages) → attic key → music box → shovel + dig under the willow → the lullaby ritual.
- **Twist**: Grandma Halima is the older sister who survived in 1921. See `docs/STORY.md`.

## Controls
WASD/mouse, Shift run, C crouch, Z crawl, E interact / camera shutter, F flashlight, R camera, V recorder, I inventory, Esc mouse. Touch controls included for phones (CAM / REC buttons).

## Build
Open `project.godot` in Godot 4.3+. CI: `.github/workflows` builds APK / unsigned IPA (needs `export_presets.cfg`).
