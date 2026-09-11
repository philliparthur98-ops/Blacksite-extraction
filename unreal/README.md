# BLACKSITE Extraction — Unreal Prototype 0.1

This is the new primary implementation of BLACKSITE Extraction. The Godot build remains in `desktop/` as a design/reference prototype; new combat and visual work should target this Unreal project.

## Target

- Unreal Engine 5.8
- Windows first
- C++ gameplay foundation with no paid or external runtime assets required
- One focused Harbor vertical slice before adding more maps, traders, weapons, or meta systems

## What is playable in Prototype 0.1

Launch the project and play the default map. The game builds its Harbor combat slice at runtime so the first source commit does not depend on binary `.umap` or `.uasset` files.

Current loop:

1. Insert into Harbor.
2. Fight nine hostiles across cover-rich industrial lanes.
3. Enter the archive warehouse and hold **F** on the archive drive.
4. Reach the east service-road checkpoint.
5. Stay inside the extraction volume and hold **F** for four seconds.
6. Extraction cancels immediately if interaction is released or the player leaves the zone.
7. Press **F5** to restart the raid.

Controls:

- **WASD** move
- **Mouse** look
- **Shift** sprint
- **Ctrl** crouch
- **LMB** fire
- **RMB** ADS
- **R** reload
- **F** interact / extract
- **Space** jump
- **F5** restart

## Playability work already in source

- responsive first-person movement
- ADS FOV transition
- automatic rifle fire with recoil, spread, muzzle lighting and dry-fire feedback
- 30-round magazine / 120-round reserve
- staged reload presentation with visible mag-out, mag-in and charge phases
- footsteps and gunfire generated procedurally at runtime
- physical player and enemy line traces; world geometry blocks hostile fire
- three enemy behavior profiles
- patrol -> investigate -> combat -> search/return flow
- gunshots alert nearby hostiles
- navigation-based movement with runtime nav bounds and direct-movement fallback
- health, death, raid failure, kill count and enemy count
- authored interaction timing for the objective and extraction
- extraction completion/failure feedback
- compact tactical HUD

## Visual direction in source

The first commit deliberately uses Engine basic meshes instead of low-quality temporary marketplace art. The runtime Harbor is lit and composed as a moody industrial dusk slice with:

- Lumen GI/reflections enabled
- Virtual Shadow Maps
- TSR
- dynamic sun / sky atmosphere
- height fog
- restrained bloom/vignette
- industrial work lights
- dense cover silhouettes and sightline breaks
- five distinct combat districts
- first-person weapon geometry and muzzle lighting
- objective and extraction lighting states

This is a **visual foundation**, not final art. The next visual pass should replace the runtime blockout geometry with a coherent, licensed industrial environment kit and a proper rigged first-person weapon/arms set while preserving the gameplay metrics and sightlines in this prototype.

## Opening the project

1. Install Unreal Engine **5.8** through the Epic Games Launcher.
2. Install Visual Studio 2022 with **Desktop development with C++** and **Game development with C++** workloads.
3. Open `BlacksiteExtraction.uproject`.
4. If Unreal asks to build missing modules, choose **Yes**.
5. Press **Play**.

If project files need to be generated manually, right-click the `.uproject` in Windows Explorer and choose **Generate Visual Studio project files**, then build the `BlacksiteExtractionEditor` Development Editor target.

## Scope rule

Do not add a second map, another weapon family, trader expansion, contract tiers, or a larger meta system until this slice has:

- reliable 60+ fps on target hardware,
- polished rifle animation/audio,
- visually authored Harbor environment art,
- readable enemy silhouettes,
- robust tactical AI around cover,
- strong hit/damage feedback,
- a satisfying 10–15 minute raid loop.

That is the quality gate for moving beyond Prototype 0.1.
