
# WaterRingToss – Overview

This project is a SwiftUI + SpriteKit game:
- SwiftUI hosts the HUD and controls.
- SpriteKit `GameScene` renders the water chamber, rings, and pegs.

Key modules:
- Views: HUDView, GameRootView, PumpButtonsView, GameOverView
- Scene: GameScene (physics, contacts, visuals)
- Nodes: RingNode (rings), PegNode (pegs)
- Models: GameModel (score/state), PhysicsCategories
- Engine: PressureEngine (maps press duration → impulse)

Design goals:
- Right-to-left consistency: right button pushes rings to the right, left button pushes to the left.
- Pegs are needles with a sharp top. Rings stack downward from the tip at a fixed spacing.
- Strong pump or device flip can eject rings off pegs (contact disabled for a short time after release).

Project flow:
1) AppEntry → GameRootView (SwiftUI container)
2) GameRootView builds GameScene and shows HUD + controls
3) GameScene builds water, walls, pegs, rings and runs physics
4) Player presses/holds a pump button → PressureEngine builds pressure
5) On release → GameScene.pump applies impulse to rings in the air stream
6) Ring contacts a Peg → settleOnPeg animation → scoring via GameModel
7) Game over overlay shown when all rings are stacked
