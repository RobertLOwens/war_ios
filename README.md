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
- **Commander system** — Leaders with 5 stats, 10 specialties, 6 ranks, and leveling progression
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

---

## Game Mechanics

### ⚔️ Military Units

9 military unit types across 4 categories:

#### Infantry (Barracks)
| Unit | HP | Move Speed | Attack Speed | Training Time | Cost |
|------|-----|------------|--------------|---------------|------|
| Swordsman | 50 | 1.40s/tile | 1.0s | 15s | 50 Food, 25 Ore |
| Pikeman | 35 | 1.60s/tile | 1.2s | 14s | 45 Food, 20 Wood, 15 Ore |

#### Ranged (Archery Range)
| Unit | HP | Move Speed | Attack Speed | Training Time | Cost |
|------|-----|------------|--------------|---------------|------|
| Archer | 30 | 1.40s/tile | 1.0s | 12s | 40 Food, 30 Wood |
| Crossbow | 40 | 1.52s/tile | 1.5s | 18s | 50 Food, 40 Wood, 20 Ore |

#### Cavalry (Stable)
| Unit | HP | Move Speed | Attack Speed | Training Time | Cost |
|------|-----|------------|--------------|---------------|------|
| Scout | 30 | 0.88s/tile | 0.7s | 18s | 60 Food, 20 Ore |
| Knight | 60 | 1.00s/tile | 1.1s | 25s | 80 Food, 60 Ore |
| Heavy Cavalry | 80 | 1.12s/tile | 1.2s | 35s | 100 Food, 80 Ore |

#### Siege (Siege Workshop)
| Unit | HP | Move Speed | Attack Speed | Training Time | Cost |
|------|-----|------------|--------------|---------------|------|
| Mangonel | 70 | 2.00s/tile | 2.5s | 45s | 60 Food, 100 Wood, 40 Ore |
| Trebuchet | 120 | 2.40s/tile | 4.0s | 60s | 80 Food, 150 Wood, 60 Ore |

#### Combat Stats

| Unit | Melee Dmg | Pierce Dmg | Bludgeon Dmg | Melee Armor | Pierce Armor | Bludgeon Armor | Special Bonuses |
|------|-----------|------------|--------------|-------------|--------------|----------------|-----------------|
| Swordsman | 2 | 0 | 0 | 2 | 1 | 0 | — |
| Pikeman | 1 | 0 | 0 | 1 | 1 | 3 | +8 vs Cavalry |
| Archer | 0 | 2 | 0 | 0 | 1 | 0 | — |
| Crossbow | 0 | 2 | 0 | 1 | 2 | 0 | — |
| Scout | 2 | 0 | 0 | 1 | 0 | 0 | +1 vs Ranged |
| Knight | 4 | 0 | 0 | 2 | 2 | 1 | +1 vs Ranged |
| Heavy Cavalry | 5 | 0 | 0 | 3 | 3 | 1 | +1 vs Ranged |
| Mangonel | 0 | 0 | 8 | 2 | 10 | 3 | +20 vs Buildings |
| Trebuchet | 0 | 0 | 12 | 2 | 15 | 4 | +30 vs Buildings |

### 📦 Resources

Four core resources drive your economy:
- 🪵 **Wood** — Construction and unit training
- 🌾 **Food** — Population upkeep and growth
- 🪨 **Stone** — Advanced buildings and fortifications
- ⛏️ **Ore** — Military equipment and upgrades

#### Resource Points on the Map

| Resource Point | Yields | Initial Amount | Base Gather Rate | Notes |
|----------------|--------|----------------|------------------|-------|
| Farmland | Food | Unlimited | 0.1/sec | Requires Farm building |
| Trees | Wood | 5,000 | 0.5/sec | Requires Lumber Camp |
| Forage | Food | 3,000 | 0.5/sec | — |
| Ore Mine | Ore | 8,000 | 0.5/sec | Requires Mining Camp |
| Stone Quarry | Stone | 6,000 | 0.5/sec | Requires Mining Camp |
| Deer | Food | — | — | Must hunt first |
| Wild Boar | Food | — | — | Must hunt first |
| Deer Carcass | Food | 2,000 | 0.5/sec | Created after hunting deer |
| Boar Carcass | Food | 1,500 | 0.5/sec | Created after hunting boar |

#### Hunting Mechanics

Animals must be hunted before they can be gathered:

| Animal | Health | Attack | Defense |
|--------|--------|--------|---------|
| Deer | 30 | 2 | 3 |
| Wild Boar | 50 | 8 | 5 |

When killed, animals become carcasses that can be gathered for food.

### 👷 Villager Gathering Rates

**Formula:** `Base Rate + (Villager Count × 0.2) × Modifiers`

- **Per-villager rate:** 0.2 resources/second
- **Max villagers per resource:** 20
- **Building bonuses:** Lumber Camp (+1.5x wood), Mining Camp (+1.5x ore/stone)

**Example calculation:**
- 10 villagers gathering from Trees (base 0.5/sec)
- Near Lumber Camp (1.5x multiplier)
- `(0.5 + (10 × 0.2)) × 1.5 = 3.75/sec`

### 🏘️ Adjacency Bonuses

Strategic building placement provides bonuses:

| Source Building | Target Building | Bonus |
|-----------------|-----------------|-------|
| Mill | Farm | +25% gather rate |
| Warehouse | Lumber Camp | +15% gather rate |
| Warehouse | Mining Camp | +15% gather rate |
| Warehouse | Farm | +15% gather rate |
| Warehouse | Barracks | -10% training cost |
| Warehouse | Archery Range | -10% training cost |
| Warehouse | Stable | -10% training cost |
| Warehouse | Siege Workshop | -10% training cost |

Bonuses stack if multiple source buildings are adjacent.

### 🔬 Research System

75 total technologies across Economic (30) and Military (45) research lines.

#### Tier Requirements
- **Tier I:** City Center Level 1 (30 sec research time)
- **Tier II:** City Center Level 2 (60 sec research time)
- **Tier III:** City Center Level 3 (120 sec research time)

#### Economic Research (10 Lines × 3 Tiers = 30 Technologies)

| Research Line | Tier I | Tier II | Tier III | Bonus Type |
|---------------|--------|---------|----------|------------|
| Farm Efficiency | +10% | +15% | +20% | Farm gather rate |
| Mining Efficiency | +10% | +15% | +20% | Mining Camp gather rate |
| Lumber Efficiency | +10% | +15% | +20% | Lumber Camp gather rate |
| Better Market Rates | +5% | +10% | +15% | Market exchange rates |
| Swift Villagers | +10% | +15% | +20% | Villager movement speed |
| Trade Routes | +10% | +15% | +20% | Trade speed |
| Improved Roads | +10% | +15% | +20% | Road speed bonus |
| Urban Planning | +5 | +10 | +15 | Population capacity (flat) |
| Efficient Rations | -5% | -10% | -15% | Food consumption |
| Construction | +10% | +15% | +20% | Building speed |

#### Military Research (15 Lines × 3 Tiers = 45 Technologies)

| Research Line | Tier I | Tier II | Tier III | Bonus Type |
|---------------|--------|---------|----------|------------|
| Forced March | +5% | +7% | +10% | Army movement speed |
| Tactical Retreat | +5% | +7% | +10% | Retreat speed |
| Infantry Weapons | +5% | +7% | +10% | Infantry melee attack |
| Cavalry Weapons | +5% | +7% | +10% | Cavalry melee attack |
| Infantry Shields | +5% | +7% | +10% | Infantry melee armor |
| Cavalry Barding | +5% | +7% | +10% | Cavalry melee armor |
| Archer Padding | +5% | +7% | +10% | Archer melee armor |
| Bodkin Points | +5% | +7% | +10% | Pierce damage |
| Infantry Mail | +5% | +7% | +10% | Infantry pierce armor |
| Cavalry Mail | +5% | +7% | +10% | Cavalry pierce armor |
| Archer Mail | +5% | +7% | +10% | Archer pierce armor |
| Siege Ammunition | +5% | +7% | +10% | Siege bludgeon damage |
| Reinforced Walls | +5% | +7% | +10% | Building bludgeon armor |
| Military Drills | +10% | +15% | +20% | Military training speed |
| Field Rations | -5% | -10% | -15% | Military food consumption |
| Fortifications | +10% | +15% | +20% | Building HP |

### 🏔️ Terrain Bonuses

Combat terrain effects based on defender's position:

| Terrain | Defender Defense Bonus | Attacker Attack Penalty | Movement Cost |
|---------|------------------------|-------------------------|---------------|
| Plains | 0% | 0% | 3 |
| Hill | +15% | 0% | 4 |
| Mountain | +25% | -10% | 5 |
| Desert | -5% | 0% | 3 |
| Water | N/A | N/A | Impassable |

**Strategic considerations:**
- Hills and mountains provide defensive advantages
- Desert terrain slightly penalizes defenders
- Mountains slow attackers and reduce their damage
- Roads negate terrain movement penalties (cost reduced to 1)

### 🎖️ Commander System

Commanders are leaders assigned to armies. They level up through combat experience, gain ranks, and provide meaningful gameplay bonuses through 5 core stats.

#### Ranks

Commanders progress through 6 ranks as they level up:

| Rank | Level Required | Icon |
|------|---------------|------|
| Recruit | 1 | ⭐ |
| Sergeant | 5 | ⭐⭐ |
| Captain | 10 | ⭐⭐⭐ |
| Major | 15 | 🎖️ |
| Colonel | 20 | 🎖️🎖️ |
| General | 25 | 👑 |

Leveling requires `level × 100` XP. Each level and rank increase boosts all 5 stats.

#### Stats

Each stat directly impacts gameplay:

| Stat | Effect | Formula |
|------|--------|---------|
| **Leadership** | Max army size | `20 + leadership × 2` |
| **Tactics** | Scales terrain combat bonuses | Multiplier on terrain defense/attack modifiers |
| **Logistics** | Army movement speed | `1.0 + logistics × 0.005` speed multiplier |
| **Rationing** | Reduces army food consumption | `1.0 - min(0.5, rationing × 0.005)` cost multiplier |
| **Endurance** | Stamina regeneration rate | `1.0 + endurance × 0.02` regen multiplier |

Stats are computed as: `base + (level - 1) × perLevel + rankIndex × perRank`, where base values and scaling rates come from the commander's specialty.

#### Specialties

10 specialties across 4 unit-type pairs plus 2 standalone:

| Specialty | Bonus | Boosted Stats |
|-----------|-------|---------------|
| Infantry (Aggressive) | +1 infantry attack | Endurance, Leadership |
| Infantry (Defensive) | +1 armor | Leadership |
| Cavalry (Aggressive) | +1 cavalry attack | Endurance, Logistics |
| Cavalry (Defensive) | +1 armor | Logistics |
| Ranged (Aggressive) | +1 ranged attack | Endurance, Tactics |
| Ranged (Defensive) | +1 armor | Tactics |
| Siege (Aggressive) | +1 siege attack | Endurance, Rationing |
| Siege (Defensive) | +1 armor | Rationing |
| Defensive | +1 armor | Tactics, Rationing, Leadership |
| Logistics | — | Leadership, Logistics |

Aggressive specialties provide +1 base attack to their matching unit type. Defensive variants (and the standalone Defensive specialty) provide +1 armor to all units.

#### Stamina

Commanders have a stamina pool (max 100) that is consumed by issuing commands (5 per action). Stamina regenerates over time at a base rate of 1/60 per second, scaled by the Endurance stat.

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
- Commander system with 5 stats, 10 specialties, leveling, and rank progression
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
