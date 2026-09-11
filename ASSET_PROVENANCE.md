# Asset provenance

This project uses original code and interface design plus openly licensed runtime assets.

## FPS Asset Kit

Source: https://github.com/petroulacl/fps-asset-kit

The upstream project aggregates CC0/public-domain FPS assets, including:

- Flat Guns West / Flat Guns East 3D weapon models
- ambientCG PBR material sets
- public-domain/CC0 sound effects including gunshots

The Harbor Yard vertical slice currently uses its web-ready GLB rifle, recorded gunshot audio, and asphalt / concrete / metal material imagery. The metal surface also uses an OpenGL normal map for added surface relief.

## CC0 human base

Source: https://github.com/UMRAM-Bilkent/supine-human-model

The optional enemy-body runtime model is `assets/human_posed.glb`. The repository documents it as derived from a Quaternius CC0 character and distributes the prepared model under CC0 1.0. BLACKSITE layers original tactical-gear geometry over the body. If the model cannot load, the game keeps a procedural capsule-based tactical enemy instead of blocking the raid.

## Runtime resilience

Runtime URLs currently point at raw GitHub-hosted copies from the source repositories. None of these downloads are required for boot: materials and 3D models are asynchronous enhancements with procedural fallbacks. Before a production release, assets should be mirrored into this repository so the game does not depend on third-party availability.

## Intellectual-property boundary

BLACKSITE: Extraction is an original extraction-shooter project. It does not ship Escape From Tarkov code, maps, textures, character art, UI assets, audio, or other proprietary content.
