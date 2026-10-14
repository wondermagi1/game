# Skill VFX resources

Downloaded source packs listed below are marked CC0 on their original pages, retrieved 2026-10-13. License: https://creativecommons.org/publicdomain/zero/1.0/

**2026-10-14 gunner revision:** `gunner-fantasy/runic-shot.png` and `gunner-fantasy/powder-orb.png` were generated with the built-in image_gen tool on transparent backgrounds and copied unchanged into this project. They are AI-generated project assets, not downloaded CC0 artwork. Exact prompts and output identifiers are in `gunner-fantasy/prompts.json`. The earlier Kenney bullet/grenade renders and dirkwybe explosion atlas below are retained for historical provenance but are no longer used by the runtime drawing code. Explosions again use the previously credited `art/v6/fx/explosion00..08.png` and existing V9 volume textures.

- **Kenney**, Blaster Kit 2.1: https://kenney.nl/assets/blaster-kit . Selected bullet and grenade GLBs; the original license is retained in `sources/Kenney-License.txt`. Rendered in Godot with replacement metallic materials; the bullet also has project-authored copper nose and brass rim geometry. `bullet.png` / `grenade.png` are 2D renders of this adapted geometry, not runtime 3D actors.
- **Tatermand**, 2D Shooter Effects (Alpha version): https://opengameart.org/node/32258 . Selected original PSD layers exported to PNG with psd-tools; layer indexes/bounds are in `manifest.json`. No project ownership of the original artwork is claimed.
- **dirkwybe**, explosion spritesheet low res: https://opengameart.org/content/explosion-spritesheet-low-res . `explosion.png` is copied unchanged from explosion0003-sheet_300x300.png. Rendered using atlas UVs.
- **Cethiel**, Weapon Slash: https://opengameart.org/content/weapon-slash-effect . Blue and classic sequence PNGs copied unchanged.
- **Cethiel**, Nature Magic Effect: https://opengameart.org/content/nature-magic-effect . Groups 0, 1 and 3 copied unchanged.
- **Cethiel**, Arcane Magic Effect: https://opengameart.org/content/arcane-magic-effect . Group 01 copied unchanged.

Existing Kenney particle textures in `art/v6/fx` retain their earlier credits. The project's previous painted sword/arrow textures remain in use. `sources/*.html` are original-page provenance snapshots, not program instructions. Optional donation/contact requests on source pages have not been treated as mandatory license terms or authorization to contact the creators.

Alternative packs compared but not used are documented in `docs/SKILL_VFX_V12.md`.
