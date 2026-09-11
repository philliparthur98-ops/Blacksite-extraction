# Prototype 0.1 acceptance criteria

## Player feel
- Mouse input is immediate and unsmoothed.
- Hip fire and ADS have visibly different spread and FOV.
- Sprint lowers the weapon and prevents firing.
- Reload has distinct mag-out, mag-in, and charge beats.
- Ammo commits only when the reload completes.
- Dry fire does not consume reserve ammunition.
- Crouch and sprint have clearly different movement speeds.

## Combat
- Enemy shots are physical visibility traces, not direct random damage.
- Hard cover between muzzle and player prevents damage.
- Player shots use physical traces and support head/body damage.
- Nearby unsuppressed gunfire alerts enemies.
- Enemy profiles differ in movement: aggressive flank, hold/range, heavy pressure.
- Losing LOS transitions enemies to investigate before returning to patrol.

## Objective / extraction
- Archive drive requires a short hold interaction.
- Extraction is locked before the drive is secured.
- Extraction requires a four-second continuous hold while inside the checkpoint.
- Releasing F or leaving the checkpoint cancels progress.
- Raid completion disables movement/input and gives clear HUD feedback.

## Visual/readability
- Spawn has immediate hard cover.
- No district is a single uninterrupted firing lane.
- Objective is visually marked by a cool point light.
- Extraction is a physical checkpoint, not a floating text marker.
- Extraction light changes from locked red to available green.
- Fog and work lights support silhouettes without making combat unreadable.

## Next art milestone
Replace Engine primitive environment and weapon geometry with coherent authored assets without changing:
- Harbor playable footprint
- cover rhythm
- objective position
- extraction timing
- enemy count
- core weapon timings

Visual replacement is accepted only if it improves readability and frame time remains within target.
