# Technical Documentation - CowGod Simulator

## Architecture Overview

This project is a complete port of the Utopia food chain simulator from Processing to Godot 4, featuring runtime mesh generation and WebGL compatibility.

## Core Systems

### 1. Terrain System (`terrain_map.gd`)

**Runtime Mesh Generation:**
- Uses `SurfaceTool` to generate meshes at runtime
- Ground mesh with vertex colors based on elevation
- Water mesh with animated waves
- Seamless world wrapping using noise interpolation

**Key Features:**
- Procedural terrain using `FastNoiseLite`
- Elevation-based coloring (sand, grass, stone, snow)
- Water level with sine wave animation
- Closest water lookup for each tile

**Performance:**
- Static ground mesh (generated once)
- Water mesh updates every 10 frames for wave animation
- Vertex coloring avoids texture memory

### 2. Creature System (`creature.gd`)

**Runtime Mesh Generation:**
- Flowers: Procedural petals and stems
- Animals: Stick figure bodies with sphere heads
- All meshes generated using `SurfaceTool`
- Dynamic mesh updates for plant growth

**Mesh Types:**
- `create_flower_mesh()`: Generates flowers with 5 petals
- `create_creature_mesh()`: Generates stick figures with limbs
- `add_box()`, `add_sphere()`: Helper functions for geometry

**Physics:**
- Custom physics with friction and gravity
- World wrapping (toroidal world)
- Ground collision detection
- Jump mechanics for animals

### 3. AI System (`creature_ai.gd`)

**Priority-Based Behavior:**
Six priorities determine creature actions:
1. **Hunger** - Seek food
2. **Thirst** - Seek water
3. **Freaky** - Reproduction drive
4. **Eepy** - Sleep (day/night cycle)
5. **Flee Monsters** - Escape predators
6. **Caretaking** - Care for offspring

**Pathfinding:**
- Target seeking with angle-based steering
- Obstacle avoidance (implicit through terrain)
- Wandering behavior when no target
- Fleeing behavior with reverse pathfinding

**Vision System:**
- `VISION_DISTANCE = T * 7.0` (7 tiles)
- Periodic target search (every 20 ticks with bucket system)
- Distance-based threat assessment

### 4. Food Chain (`constants.gd`)

**Species Configuration:**
```
0: Pink Flower (plant)
1: Ice Flower (plant)
2: Yellow Cow (herbivore - eats pink flowers)
3: Teal Cow (herbivore - eats ice flowers)
4: Red Predator (carnivore - eats both cows)
5: Gray Species (not implemented)
```

**Food Matrix:**
- Defined in `IS_FOOD` 2D boolean array
- Herbivores eat specific plants
- Carnivores eat herbivores
- Edibility based on size/hunger level (0.25-0.75 range)

**Energy System:**
- Each species has calorie gain rate
- Hunger/thirst drain rates per species
- Movement affects hunger drain
- Birth costs parents energy

### 5. Game Manager (`game_manager.gd`)

**Main Loop:**
- Spawns initial creatures
- Updates all creature physics and AI
- Archives population data
- Manages camera
- Removes dead creatures

**Population Tracking:**
- Archives every 30 ticks
- Keeps last 200 records
- Tracks each species separately

### 6. UI System (`ui_overlay.gd`)

**Display Components:**
- Day/night cycle indicator
- Population counts by species
- Population graph over time
- Daylight indicator

**Graph Rendering:**
- Custom `_draw()` function
- Line-based visualization
- Auto-scaling Y-axis
- Color-coded species

## WebGL Compatibility

**Renderer Configuration:**
```gdscript
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

**WebGL-Safe Features:**
- No compute shaders
- No advanced rendering features
- Vertex color instead of textures
- Basic lighting only

**Performance Optimizations:**
- Static ground mesh
- Periodic water mesh updates (not every frame)
- Creature mesh updates only when needed (plant growth)
- Spatial bucketing for AI updates (20 buckets)

## Key Algorithms

### World Wrapping (Toroidal Topology)

```gdscript
func unloop(val: float) -> float:
    var world_size = Constants.SIZE * Constants.T
    while val <= -world_size / 2:
        val += world_size
    while val > world_size / 2:
        val -= world_size
    return val
```

### Seamless Noise

Uses corner interpolation to create seamless wrapping:
```gdscript
# Sample noise at 4 corners with wrapping
# Interpolate based on distance from edges
```

### Priority Selection

```gdscript
# Find minimum priority value (most urgent)
# Search for target based on priority type
# Pathfind towards target
```

## Performance Characteristics

**Creature Count:** 110 (configurable)
**Map Size:** 36x36 tiles
**Tile Size:** 140 units
**World Size:** ~5040 x 5040 units

**Mesh Complexity:**
- Ground: (36 * 36 * 2 triangles) = 2,592 triangles
- Water: ~2,592 triangles (only visible areas)
- Flower: ~100 triangles each
- Animal: ~200 triangles each
- Total: ~30,000-40,000 triangles

**Update Frequency:**
- AI priorities: Every frame
- Target search: Every 20 frames (staggered)
- Water mesh: Every 10 frames
- Archive: Every 30 frames

## Extensions and Modifications

### Adding New Species

1. Add to `SPECIES_COLORS` array
2. Update `PRIORITY_RATES` array
3. Extend `IS_FOOD` matrix
4. Update `CALORIES_RATE`
5. Modify `create_creature_mesh()` for new appearance

### Modifying Terrain

1. Adjust `ELEV_FACTOR` for mountain height
2. Change `WATER_LEVEL` for ocean size
3. Modify `noise.frequency` for terrain detail
4. Update color array in `get_color_at()`

### Tuning AI

1. Adjust `PRIORITY_RATES` for behavior frequency
2. Change `VISION_DISTANCE` for awareness
3. Modify `COLLISION_DISTANCE` for interaction range
4. Tune `ACCEL` and `FRICTION` for movement feel

## Known Limitations

1. No shadows (WebGL compatibility)
2. Simple lighting model
3. No particle effects
4. Limited creature mesh detail (performance)
5. Fixed creature count (no dynamic spawning limits)

## Future Improvements

- Terrain texture blending
- More detailed creature meshes
- Particle effects for births/deaths
- Sound effects
- Save/load system
- Statistics screen
- Evolution/mutation system
- Biome system
