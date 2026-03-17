# AI RAGs (Rules & Guidance)

Terminology:
- Peg: a needle-shaped pole with a sharp top. Contact is detected at the tip.
- Ring: an oval ring that can be free or settled on a peg.
- Cap/Tip: the top of the peg; stacking starts below this point.

Rules:
- Do not change the meaning of controls: right pushes right, left pushes left.
- Keep ring stacking going downward from the peg tip at spacing = 30pt.
- Peg physics: no blocking collision; peg only signals contact.
- Preserve `releaseFromPeg` cooldown at 1.5s unless explicitly changed.
- Avoid heavy textures; prefer SKShapeNode and paths for visuals.

Code style:
- Use SpriteKit actions for micro-animations (move/scale/fade groups).
- Keep physics and rendering on main; use async only for non-render tasks.
- Keep files cohesive: views in Views/, nodes in Nodes/, engine/models in their folders.
- Document any new tuning constants in Documentation/Physics.md.

Integration notes:
- Use PegNode tip position (≈ y:26 from node origin) as stack reference.
- In GameScene.didBegin(contact), compute final ring position from peg cap Y minus (index+1)*spacing.
- Respect `PressureEngine` output as-is; clamp only in scene if needed for tuning.
