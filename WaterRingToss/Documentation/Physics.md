# Physics

Categories:
- ring: dynamic circular body (R ≈ 17)
- peg: small static circle at the needle tip (radius ≈ 5) for contact detection
- wall: scene edges

Ring physics (RingNode.setupPhysics):
- restitution 0.15, friction 0.60
- linearDamping 2.2, angularDamping 2.0, density 2.4
- Contact with pegs enabled after initial settle delay (0.9s at spawn)

Peg physics (PegNode.setupPhysics):
- static SKPhysicsBody at needle tip (center around y:22..26 relative to node origin)
- collisionBitMask = 0 (no physical blocking), only contact to trigger settle

Release logic:
- `RingNode.releaseFromPeg()`:
  - isOnPeg = false, pegIndex = -1
  - contact disabled for 1.5s to avoid immediate re-landing
  - small impulse applied, resumes tumbling

Stacking:
- Rings stack under the needle tip using a constant spacing (default 30pt).
- Final position per ring = cap position y - spacing * (stackIndex + 1)

Gravity & motion:
- Gravity follows device accelerometer on real devices (CoreMotion)
- Simulator fallback uses orientation notifications
