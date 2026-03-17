# 💧 Water Ring Toss — iOS

> A physics-based water ring toss game for iOS, built with **SwiftUI + SpriteKit**.  
> Inspired by the classic handheld water ring toy.

---

## 📱 Demo

<!-- Add your screen recording GIF here -->
https://github.com/ErsanQ/WaterRingToss/raw/main/Assets/demo.mp4


---

## 🎮 Gameplay

- Press and **hold** the left or right button to build air pressure
- **Release** to fire a burst that launches rings upward
- Guide rings onto the **needle pegs** — they must enter from the top
- **Tilt your device** to shift gravity and reposition rings
- **Flip the device upside-down** to knock all rings off the pegs

---

## ✨ Features

| Feature | Details |
|---|---|
| 🌊 Fluid simulation | Oil-like viscosity via `linearDamping`, slow `physicsWorld.speed` |
| 💉 Pressure engine | Hold-to-charge mechanic with tremor noise at max pressure |
| 📐 Angled pump stream | 20° inward angle per nozzle, cone-based ring detection |
| 🧲 Smart stacking | New rings land on top, older rings slide down the pole |
| 📳 CoreMotion gravity | Tilt = gravity shift, flip = all rings fall off |
| 🎯 Contact-only pegs | Rings enter from the top only — sides block via solid body |
| ✨ Visual effects | Air stream particles, ripples, peg flash, star burst on score |
| 🔁 Instant reset | Full scene rebuild with one tap |

---

## 🏗️ Architecture

```
WaterRingToss/
├── AppEntry.swift              # @main App entry
├── Views/
│   ├── GameRootView.swift      # SwiftUI container + scene builder
│   ├── HUDView.swift           # Score, rings counter, pressure gauge
│   ├── PumpButtonsView.swift   # Left/Right pump buttons + reset
│   └── GameOverView.swift      # End-of-game overlay
├── GameScene.swift             # SpriteKit scene (physics, contacts, visuals)
├── Nodes/
│   ├── RingNode.swift          # Ring visuals + physics + animations
│   └── PegNode.swift           # Needle peg visuals + sensor
├── Models/
│   ├── GameModel.swift         # Score, state, game-over logic
│   └── PhysicsCategories.swift # Collision bitmasks
└── Engine/
    └── PressureEngine.swift    # Press-duration → impulse mapping
```

---

## 🔧 Requirements

- **Xcode** 15+
- **iOS** 16+
- **Swift** 5.9+
- Frameworks: `SwiftUI`, `SpriteKit`, `CoreMotion`, `Combine`

---

## 🚀 Getting Started

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/WaterRingToss.git

# 2. Open in Xcode
open WaterRingToss.xcodeproj

# 3. Select a simulator or real device and Run (⌘R)
```

> **Note:** CoreMotion (tilt/flip) only works on a **real device**.  
> On the Simulator use **Hardware → Rotate** or **Portrait Upside Down**.

---

## 🎯 Physics Tuning

| Parameter | Value | Effect |
|---|---|---|
| `linearDamping` | `2.2` | Oil-like resistance |
| `physicsWorld.speed` | `0.70` | Slowed simulation |
| `restitution` | `0.15` | Barely bounces |
| `density` | `2.4` | Heavy ring feel |
| `gravity` | `-5.5` | Default downward |
| Pump angle | `20°` | Inward from each nozzle |
| Eject threshold | `≥ 80%` pressure | Knocks rings off pegs |

---

## 📋 Controls

| Control | Action |
|---|---|
| Hold ◀ | Build pressure, release to pump left nozzle rightward |
| Hold ▶ | Build pressure, release to pump right nozzle leftward |
| Tilt device | Shift gravity in that direction |
| Flip upside-down | Eject all rings from pegs |
| 🔄 Reset button | Restart the game |

---

## 🛠️ Built With

- [SwiftUI](https://developer.apple.com/xcode/swiftui/) — UI layer
- [SpriteKit](https://developer.apple.com/spritekit/) — Physics & rendering
- [CoreMotion](https://developer.apple.com/documentation/coremotion) — Device tilt & flip
- [Combine](https://developer.apple.com/documentation/combine) — Reactive state

---

## 📄 License

MIT License — feel free to use, modify, and share.

---

*Made with 💧 and SwiftUI + SpriteKit*
