# CowGod - Food Chain Extinction Simulator

A Godot 4 port of the Utopia food chain simulator by carykh.

## About

This is a 3D food chain simulator featuring 6 species in an ecosystem:
- **Pink Flowers** and **Ice Flowers** (plants)
- **Yellow Cows** and **Teal Cows** (herbivores)
- **Red Predators** (carnivores)
- **Gray Species** (not yet implemented)

The simulation features:
- Procedurally generated terrain with seamless wrapping
- Runtime mesh generation for all creatures and terrain (no 3D models needed)
- Complex AI behaviors: hunger, thirst, reproduction, fleeing from predators
- Population dynamics and extinction mechanics
- Day/night cycle affecting creature behavior
- Real-time population graphs

## Controls

- **WASD** - Move camera
- **Space/Shift** - Move camera up/down
- **C** - Toggle follow mode (follow nearest creature)
- **T** - Switch to target of current creature (when in follow mode)

## Running the Project

1. Open the project in Godot 4.3 or later
2. Press F5 or click "Run Project"

## WebGL Export

The project is configured for WebGL export:
1. Go to Project > Export
2. Select "Web" preset
3. Click "Export Project"
4. The build will be in `build/web/`

## Technical Details

- **Engine**: Godot 4.3+
- **Renderer**: GL Compatibility (for WebGL support)
- **Meshes**: All generated at runtime using SurfaceTool
- **Terrain**: Procedural with FastNoiseLite, seamlessly wrapping

## Credits

Original Utopia simulator by carykh: https://github.com/carykh/Utopia/
Ported to Godot 4 by GitHub Copilot
