extends Node

const Constants = preload("res://scripts/constants.gd")

var creature: Node3D
var game_manager: Node
var terrain_map: Node3D

var animal_key_presses: Array = [false, false, false, false, false, false, false, false]
var wander_action: int = -1

func _init(parent_creature, manager, t_map):
	creature = parent_creature
	game_manager = manager
	terrain_map = t_map

func do_priorities():
	var species = creature.species
	
	# Update priority levels
	for i in range(Constants.PRIORITY_NAMES.size()):
		var drain_rate = Constants.PRIORITY_RATES[species][i] * 0.00003
		if drain_rate == 0:
			continue
		
		# Freaky rate increases when well-fed
		if i == 2:  # Freaky
			drain_rate *= 0.2 + 0.8 * creature.priorities[0]
		
		# Hunger increases slower when not moving
		if i == 0 and not is_exerting_motion():
			drain_rate *= 0.3333
		
		creature.priorities[i] = clamp(creature.priorities[i] - drain_rate, Constants.PRIORITY_CAPS[i], 1.0)
		
		# Die from hunger or thirst
		if creature.priorities[i] <= 0 and i < 2:
			creature.to_die = true
			return
	
	# Update eepy (sleepiness) based on daylight
	var daylight = 0.5 - 0.5 * cos(game_manager.ticks / Constants.TICKS_PER_DAY * TAU)
	var cap = Constants.PRIORITY_CAPS[3]
	creature.priorities[3] = cap + (1 - cap) * daylight
	
	# Check for predators periodically
	if game_manager.ticks % 20 == creature.tick_bucket:
		creature.predator = find_target(2)  # Find predators
		if creature.predator == null:
			creature.priorities[4] = 1.0
		else:
			var dx = unloop(creature.coor.x - creature.predator.coor.x) / Constants.T
			var dz = unloop(creature.coor.z - creature.predator.coor.z) / Constants.T
			var dist = sqrt(dx * dx + dz * dz)
			creature.priorities[4] = clamp((dist - 1.0) / 3.5, 0.0, 1.0)
	
	# Find the top priority
	var next_priority = get_top_priority()
	var refresh = game_manager.ticks % 20 == creature.tick_bucket or next_priority != creature.top_priority
	
	if refresh:
		search(next_priority)
	
	pathfind(next_priority)
	creature.top_priority = next_priority

func get_top_priority() -> int:
	var lowest_val = 999.0
	var lowest_idx = -1
	for i in range(creature.priorities.size()):
		if creature.priorities[i] < lowest_val:
			lowest_val = creature.priorities[i]
			lowest_idx = i
	return lowest_idx

func search(top_priority: int):
	if top_priority == 0:  # Hungry
		creature.target = find_target(1)
	elif top_priority == 1:  # Thirsty
		creature.target = find_water()
	elif top_priority == 2:  # Freaky (reproduction)
		creature.target = find_target(0)
	elif top_priority == 4:  # Fleeing
		creature.target = creature.predator
	else:
		creature.target = null

func find_target(target_type: int):
	var record_holder = null
	var distance_record = Constants.VISION_DISTANCE
	
	for other in game_manager.creatures:
		if creature.species <= -1 or other.species <= -1 or other == creature:
			continue
		
		# Check target type compatibility
		if target_type == 0 and creature.species != other.species:
			continue
		if target_type == 1 and not Constants.IS_FOOD[creature.species][other.species]:
			continue
		if target_type == 2 and not Constants.IS_FOOD[other.species][creature.species]:
			continue
		
		# Don't eat inedible creatures
		if target_type == 1 and not is_edible(other):
			continue
		
		var distance = d_loop(creature.coor, other.coor)
		if distance < distance_record:
			distance_record = distance
			record_holder = other
	
	return record_holder

func is_edible(target) -> bool:
	if Constants.get_species_type(target.species) == 0:
		return target.size >= 0.25 and target.size <= 0.75
	else:
		return target.priorities[0] >= 0.25 and target.priorities[0] <= 0.75

func find_water():
	var ix = int(creature.coor.x / Constants.T) % Constants.SIZE
	var iz = int(creature.coor.z / Constants.T) % Constants.SIZE
	if ix < 0:
		ix += Constants.SIZE
	if iz < 0:
		iz += Constants.SIZE
	
	var closest = terrain_map.closest_water[ix][iz]
	var water_pos = Vector3(closest[0] * Constants.T, 0, closest[1] * Constants.T)
	
	# Create a temporary target node
	var water_target = Node3D.new()
	water_target.position = water_pos
	water_target.set_meta("is_water", true)
	return water_target

func pathfind(top_priority: int):
	# Reset key presses
	for i in range(animal_key_presses.size()):
		animal_key_presses[i] = false
	
	if creature.target == null:
		if top_priority <= 2:  # Wander if hungry, thirsty, or freaky but no target
			animal_key_presses[7] = true  # Wander
		return
	
	if top_priority <= 2 or top_priority == 5:  # Move towards target
		var dx = unloop(creature.target.position.x - creature.coor.x)
		var dz = unloop(creature.target.position.z - creature.coor.z)
		var distance = sqrt(dx * dx + dz * dz)
		var target_angle = atan2(dz, dx)
		var angle_diff = unloop_angle(target_angle - creature.rotation_angle)
		
		if angle_diff <= -0.03:
			animal_key_presses[5] = true  # Turn left
		elif angle_diff >= 0.03:
			animal_key_presses[6] = true  # Turn right
		
		var angle_window = 0.3 if distance <= Constants.T * 3 else 0.05
		if abs(angle_diff) < angle_window:
			animal_key_presses[1] = true  # Move forward
			if randf() < 0.03 and distance >= Constants.T:
				animal_key_presses[4] = true  # Jump
			
			if randf() < 0.5:
				if angle_diff >= 0.05 and angle_diff < 0.45:
					animal_key_presses[0] = true  # Strafe right
				elif angle_diff <= -0.05 and angle_diff > -0.45:
					animal_key_presses[2] = true  # Strafe left
	
	elif top_priority == 4:  # Run away from predator
		var dx = unloop(creature.coor.x - creature.target.coor.x)
		var dz = unloop(creature.coor.z - creature.target.coor.z)
		var target_angle = atan2(dz, dx)
		var angle_diff = unloop_angle(target_angle - creature.rotation_angle)
		
		if angle_diff <= -0.1:
			animal_key_presses[5] = true
		elif angle_diff >= 0.1:
			animal_key_presses[6] = true
		
		if abs(angle_diff) < 0.25:
			animal_key_presses[1] = true
			if randf() < 0.03:
				animal_key_presses[4] = true
		
		animal_key_presses[4] = true  # Jump when fleeing

func is_exerting_motion() -> bool:
	for i in range(5):
		if animal_key_presses[i]:
			return true
	return false

func do_actions():
	var r = creature.rotation_angle
	creature.walk_speed = -1.0
	
	for i in range(8):
		if i == 7:
			if animal_key_presses[i] and wander_action >= 1:
				creature.walk_speed = 0.3
		elif animal_key_presses[i]:
			creature.walk_speed = 1.0
	
	var s = Constants.SPECIES_SPEED[creature.species] if creature.species >= 0 else 1.0
	var hunger_mult = 1.0
	
	if Constants.get_species_type(creature.species) in [1, 2]:
		hunger_mult = 1.0 - 0.25 * min(creature.priorities[0], 1.0)
	
	var accel = creature.ACCEL * s * hunger_mult
	
	if animal_key_presses[3]:  # Backward
		creature.velo.x -= cos(r) * accel
		creature.velo.z -= sin(r) * accel
	if animal_key_presses[1]:  # Forward
		creature.velo.x += cos(r) * accel
		creature.velo.z += sin(r) * accel
	if animal_key_presses[2]:  # Strafe left
		creature.velo.x -= sin(r) * accel
		creature.velo.z += cos(r) * accel
	if animal_key_presses[0]:  # Strafe right
		creature.velo.x += sin(r) * accel
		creature.velo.z -= cos(r) * accel
	
	# Wander behavior
	if animal_key_presses[7]:
		if game_manager.ticks % 20 == creature.tick_bucket:
			wander_action = randi() % 4  # 0: still, 1: forward, 2: left, 3: right
		
		if wander_action == 1:
			creature.velo.x += cos(r) * creature.WANDER_ACCEL * s * hunger_mult
			creature.velo.z += sin(r) * creature.WANDER_ACCEL * s * hunger_mult
		elif wander_action == 2:
			creature.rotation_angle -= accel * 0.05
		elif wander_action == 3:
			creature.rotation_angle += accel * 0.05
	
	# Jump
	if animal_key_presses[4]:
		if terrain_map:
			var ground = terrain_map.get_ground_level(creature.coor)
			if creature.coor.y <= ground and creature.velo.y <= 1:
				creature.velo.y = 18
	
	# Turn
	if animal_key_presses[5]:  # Turn left
		creature.rotation_angle -= accel * 0.05
	if animal_key_presses[6]:  # Turn right
		creature.rotation_angle += accel * 0.05

func unloop(val: float) -> float:
	var world_size = Constants.SIZE * Constants.T
	while val <= -world_size / 2:
		val += world_size
	while val > world_size / 2:
		val -= world_size
	return val

func unloop_angle(val: float) -> float:
	while val <= -PI:
		val += TAU
	while val > PI:
		val -= TAU
	return val

func d_loop(c1: Vector3, c2: Vector3) -> float:
	var dx = unloop(c1.x - c2.x)
	var dz = unloop(c1.z - c2.z)
	return sqrt(dx * dx + dz * dz)
