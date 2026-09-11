# BLACKSITE: Extraction

BLACKSITE is an original tactical extraction FPS. The **active production implementation is now Unreal Engine 5.8**, with the project deliberately focused on one premium Harbor vertical slice before expanding content.

## Active implementation

Open `unreal/BlacksiteExtraction.uproject` in Unreal Engine 5.8.

Prototype 0.1 currently targets:

- responsive first-person movement and mouse look
- a tactile VXR-11 rifle loop with ADS, recoil, reload staging, ammo state and dry fire
- physical player and hostile shot traces so world cover matters
- tactical enemy patrol / investigate / combat / search behavior
- three enemy behavior profiles
- hold-to-secure archive objective
- timed, cancellable physical extraction checkpoint
- tactical HUD and complete raid restart loop
- one compact Harbor combat slice with deliberate cover and sightline composition
- Lumen GI/reflections, Virtual Shadow Maps, TSR, dusk lighting, fog and industrial work lights
- performance/readability as hard gates before content growth

See `unreal/README.md` and `unreal/Docs/VERTICAL_SLICE.md` for controls, architecture and the current quality gate.

## Scope lock

Do not add a second map, additional weapon families, trader expansion, contract tiers, or a larger meta layer until the Unreal Harbor raid is materially premium in playability and presentation. The next priorities are a successful UE 5.8 editor build/playtest, authored industrial environment art, a rigged first-person arms/weapon set, stronger impact/damage feedback, coherent spatial audio, and 60+ fps profiling.

## Previous prototypes

- `desktop/` — Godot desktop implementation retained as a design/reference/fallback build.
- root web files / `src/` — earlier browser prototype retained for historical reference and lightweight demonstrations.

New gameplay and visual development should target `unreal/` unless the project direction explicitly changes again.

## Asset provenance

Only original or appropriately licensed assets should enter the production build. Existing external prototype assets are documented in `ASSET_PROVENANCE.md`. No Escape From Tarkov/SPT proprietary code, maps, models, UI artwork, audio, or other protected game assets are included.
