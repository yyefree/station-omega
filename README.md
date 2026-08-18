# Station Omega

A fully procedural sci-fi FPS dungeon crawler built with **Godot 4.7**. Zero external assets — every texture, sound effect, and visual is generated entirely in code.

[![Godot 4.7](https://img.shields.io/badge/Godot-4.7-blue)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/Tests-99%2F99%20passing-brightgreen)](#testing)

## Story

Deep Space Research Station **Omega** has suffered a catastrophic dimensional rift breach. Alien organisms have flooded the lower decks. You are the last surviving security operative — navigate the station, collect energy cores, and reach the bridge to activate the self-destruct sequence before the contamination reaches Earth.

## Features

- **2 Complete Levels** — Engineering Deck (industrial, emergency lighting) and Jungle (alien-overgrown ruins)
- **3 Weapons** — Revolver, Assault Rifle, Shotgun with muzzle flash FX
- **Procedural Everything** — 16 texture types, 31 sound effects, all generated at runtime (no image/audio files)
- **Sci-fi Atmosphere** — Emergency red overhead lights, cool blue work lights, volumetric fog, space station ceiling
- **Enemy AI** — Flying drones and ground security bots with pathfinding and combat
- **Puzzle Mechanics** — Power switches, pressure plates, locked bulkhead doors
- **Full HUD** — Health, ammo, score, timer, objective tracker, weapon display
- **Auto-Demo Mode** — AI plays automatically after 5 seconds on menu
- **99 Automated Tests** — Regression tests covering movement, combat, puzzles, level switching

## Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Mouse | Look |
| Left Click | Shoot |
| R | Reload |
| 1 / 2 / 3 | Switch Weapon |
| E | Interact |
| Space | Jump |
| Shift | Sprint |
| Ctrl / C | Crouch |
| Esc | Pause |

## Quick Start

### Option 1: Download

1. Download and install [Godot 4.7](https://godotengine.org/download)
2. Clone this repository:
   ```
   git clone https://github.com/yyefree/station-omega.git
   ```
3. Open Godot → Import → select the `project.godot` file
4. Press **F5** to play

### Option 2: Run from command line

```bash
# Play Level 1
path/to/Godot --path . -- --level 1

# Play Level 2
path/to/Godot --path . -- --level 2

# Auto-demo mode
path/to/Godot --path . -- --level 1 --demo

# Autostart (skip menu)
path/to/Godot --path . -- --level 1 --autostart

# Fullscreen
path/to/Godot --path . -- --fullscreen
```

## Project Structure

```
station-omega/
├── project.godot          # Godot project configuration
├── scenes/
│   └── main.tscn          # Main scene (minimal — everything built in code)
├── scripts/
│   ├── main.gd            # Game loop, state machine, scene construction
│   ├── player.gd          # FPS controller, weapons, camera
│   ├── enemy.gd           # Enemy AI, combat, death
│   ├── hud.gd             # Full UI: menus, HUD, settings
│   ├── fx.gd              # Particle effects, muzzle flash, floating text
│   ├── texgen.gd          # 16 procedural texture generators (512px)
│   ├── audio_manager.gd   # 31 procedural PCM sound effects
│   ├── weapon.gd          # Weapon data container
│   ├── artifact.gd        # Collectible energy cores
│   ├── pickup.gd          # Health and ammo pickups
│   ├── ruin_door.gd       # Animated doors (bulkheads)
│   ├── ruin_switch.gd     # Levers and pressure plates
│   └── target.gd          # Target practice (unused)
├── tests/
│   ├── run_all.gd         # 67 regression tests (Level 1)
│   └── run_level2.gd      # 32 regression tests (Level 2)
├── .gitignore
├── LICENSE
└── README.md
```

## Testing

Run the automated test suite from the command line:

```bash
# Level 1 tests (67 checks)
path/to/Godot --headless --path . --script "res://tests/run_all.gd"

# Level 2 tests (32 checks)
path/to/Godot --headless --path . --script "res://tests/run_level2.gd"
```

Tests cover: movement, jumping, crouching, weapon switching, firing, enemy combat, artifact collection, puzzle mechanics, level switching, and UI state.

## Technical Highlights

- **Procedural Textures**: ground, stone, brick, wood, metal, steel, polymer, plastic, carbon, grass, leaf, vine, gunmetal, knurl — all generated with layered noise and blending
- **Procedural Audio**: gunshots, explosions, footsteps, ambient wind, UI clicks — all synthesized PCM waveforms
- **Space Station Lighting**: Emergency red Omni+SpotLight pairs, cool blue work lights, volumetric fog injection
- **GLSL Shaders**: Water surface with multi-wave caustics, animated ceiling panels, sky atmosphere
- **Performance**: All textures cached after first generation, forward+ renderer with FXAA + MSAA

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
