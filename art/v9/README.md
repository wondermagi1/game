# V9 action keyframe source art

The three `*-attack-keyframes-source.png` files are AI-assisted raster assets generated on 2026-10-04 from this project's existing V6 integrated character sheets. They were generated specifically for this project and do not copy or bundle third-party game assets.

Each transparent 1536×1024 atlas contains 24 cells: six attack phases across four cardinal directions. The phase order is anticipation, compression, release, follow-through, recoil and recovery. The direction order is right, down, left and up.

Godot uses the complete character-and-weapon image in each cell. The hands, body and weapon therefore remain authored together instead of rotating a separate weapon around the actor's feet. Diagonal aim selects the closest authored cardinal row while gameplay projectiles keep their exact aim vector.

These files are AI-assisted source images with local integration and validation. They are not represented as hand-drawn frame-by-frame animation.

The three files under `fx/` are also AI-assisted transparent source textures created specifically for this project. They contain no character or weapon art: sword uses a cyan spiritual vortex, gunner uses a fire-and-smoke core, and ranger uses an emerald astral-wind core. Godot layers them over the existing bounded C-skill presentation; they have no collision or damage callbacks.
