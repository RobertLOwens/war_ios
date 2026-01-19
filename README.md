# War IoS 🏰

**A Fair-Play Medieval Real-Time Strategy Game for iOS**

Grow2 is a hex-based RTS game built with Swift and SpriteKit, designed for strategic depth without pay-to-win mechanics. Build your empire, manage resources, train armies, and outmaneuver your opponents through skill and tactics—not wallet size.

---

## The Vision

Strategy games are about *decisions*. Tactical positioning, resource management, information warfare, and timing should determine victory—not who spent the most money.

Mobile strategy games have incredible potential: massive maps, diplomacy, resource contention, and bite-sized sessions perfect for busy schedules. But they're plagued by pay-to-win mechanics, loot boxes, and progression systems that favor spending over strategy.

**Grow2 is different.** One purchase. No microtransactions. No loot boxes. Just pure strategy where every player competes on equal footing.

---

## Game Features

### 🗺️ Hex-Based Maps
- Hexagonal grid system for nuanced movement and positioning
- Procedurally generated terrain with forests, mountains, and resource deposits
- Strategic chokepoints and defensible positions

### 🏛️ Building System
16 building types across economic and military categories:

**Economic Buildings**
- **City Center** — Main hub for economy and population (upgradeable to level 10)
- **Farm** — Produces food resources with gathering bonuses
- **Neighborhood** — Houses population
- **Warehouse** — Stores extra resources
- **Market** — Trade resources
- **Lumber Camp** — Increases wood collection (+1.5x bonus)
- **Mining Camp** — Increases ore collection (+1.5x bonus)
- **Blacksmith** — Upgrades units and tools
- **University** — Research technologies

**Military Buildings**
- **Barracks** — Trains infantry units
- **Archery Range** — Trains ranged units  
- **Stable** — Trains cavalry units
- **Siege Workshop** — Builds siege weapons
- **Castle** — Defensive stronghold and military command center
- **Tower** — Defensive structure
- **Wooden Fort** — Basic defensive fortification

Buildings unlock progressively based on City Center level, creating meaningful tech tree decisions.

### ⚔️ Military Units & Commanders
- **Entity-based system** — Armies and Villager Groups instead of individual unit micromanagement
- **Commander system** — Leaders with ranks, specialties, and army size bonuses
- **Unit composition** — Infantry, archers, cavalry, and siege weapons with rock-paper-scissors counters
- **Garrison mechanics** — Station units in buildings for defense

### 📦 Resource Management
Four core resources drive your economy:
- 🪵 **Wood** — Construction and unit training
- 🌾 **Food** — Population upkeep and growth
- 🪨 **Stone** — Advanced buildings and fortifications
- ⛏️ **Ore** — Military equipment and upgrades

Resources can be gathered from map deposits (with depletion mechanics) or produced via buildings. Population consumes food over time, creating economic pressure.

### 👁️ Fog of War
- **Three visibility states:** Unexplored → Explored → Visible
- **Memory system:** Previously seen areas show last-known building positions
- **Diplomatic vision sharing:** Allies and guild members share line of sight
- **Entity-based vision:** Buildings provide 1-tile radius; mobile units provide 2-tile radius

### 🔬 Research System
Technology upgrades provide permanent bonuses:
- Tool improvements (e.g., Axe Sharpening for faster wood gathering)
- Unit upgrades
- Building enhancements
- Background timer integration for offline progress

### ⏰ Flexible Time Formats
Designed for real-life schedules:
- **Quick matches** — 10-15 minute tactical battles
- **Async games** — 1-day turn-based for thinking strategists
- **Offline progress** — Constructions, training, and gathering continue while away (capped at 8 hours)

---

## Architecture

### Command Pattern
Game actions flow through a centralized `CommandExecutor` for consistent validation, logging, and execution:
- `MoveCommand` — Entity movement
- `BuildCommand` — Structure construction  
- `GatherCommand` — Resource collection
- `TrainCommand` variants — Unit and villager training
- `RecruitCommand` — Commander recruitment

### Entity System
Rather than managing individual units, Grow2 uses aggregate entities:
- **Army** — Groups of military units led by a Commander
- **VillagerGroup** — Civilian workers for gathering and construction

This reduces screen clutter while maintaining strategic depth.

### Core Components
```
Grow2/
├── Shared/
│   ├── GameScene.swift      — Main SpriteKit scene and game loop
│   ├── HexMap.swift         — Hex grid and coordinate system
│   ├── Player.swift         — Player state, resources, diplomacy
│   ├── Building.swift       — BuildingType enum and BuildingNode
│   ├── Map Entity.swift     — Army and VillagerGroup classes
│   ├── FogOfWar.swift       — Vision and memory systems
│   ├── Commander.swift      — Leader ranks and abilities
│   ├── Commands/            — Command pattern implementations
│   └── GameSaveManager.swift— Persistence and offline calculation
├── iOS/
│   ├── ViewControllers/     — UIKit screens and menus
│   └── Coordinators/        — Menu and action coordination
```

---

## Current Status

**✅ Implemented**
- Hex map generation and rendering
- Complete building system with construction progress
- Resource gathering with villager capacity and depletion
- Military training queues with slider-based quantity selection
- Commander recruitment with rank progression
- Fog of war with diplomatic vision sharing
- Research system with background timers
- Save/load with offline progress calculation
- Entity-based army and villager management
- Command pattern architecture

**🚧 In Development**
- Balance tuning and playtesting
- Additional research items
- UI/UX refinements

---

## Roadmap

### Phase 1: Multiplayer Foundation
- 1v1 online matches
- Matchmaking system
- Real-time and async game modes

### Phase 2: Seasonal Campaigns
- Structured competitive seasons
- Persistent rankings
- Special campaign maps and objectives

### Phase 3: Expansion
- Additional unit types and buildings
- Expanded commander abilities
- Map editor tools

---

## Technical Details

- **Platform:** iOS (iPhone and iPad)
- **Language:** Swift
- **Framework:** SpriteKit for rendering, UIKit for menus
- **Architecture:** Entity-based game objects, Command pattern for actions
- **Persistence:** JSON-based save system with offline progress
- **Target:** iOS 15+

---

## Development Philosophy

1. **Fair play above all** — Every player has access to the same tools
2. **Decisions matter** — Strategic choices should outweigh grinding
3. **Respect player time** — Flexible formats for busy schedules
4. **Iterate systematically** — Test, measure, improve

---

## Contributing

This is a personal project in active development. If you're interested in following the journey or providing feedback, stay tuned for updates.

---

## License

All rights reserved. This codebase is not open source.

---

*Building something better, one hex at a time.* ◡̈
