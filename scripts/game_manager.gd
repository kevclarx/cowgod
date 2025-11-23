extends Node

const Constants = preload("res://scripts/constants.gd")
const Creature = preload("res://scripts/creature.gd")
const TerrainMap = preload("res://scripts/terrain_map.gd")
const UIOverlay = preload("res://scripts/ui_overlay.gd")

var creatures: Array = []
var terrain_map: Node3D
var ticks: int = 0
var player_camera: Camera3D
var archive: Array = []
var max_id: int = 0
var ui_overlay: CanvasLayer
var camera_target: Node3D = null
var camera_follow_mode: bool = false

const ARCHIVE_EVERY = 30
const ARCHIVE_SIZE = 200

func _ready():
	randomize()
	setup_world()
	spawn_initial_creatures()
	setup_ui()

func setup_world():
	# Create terrain
	terrain_map = TerrainMap.new()
	add_child(terrain_map)
	
	# Create camera
	player_camera = Camera3D.new()
	add_child(player_camera)
	player_camera.position = Vector3(Constants.SIZE * Constants.T / 2, 500, Constants.SIZE * Constants.T / 2)
	player_camera.look_at(Vector3(Constants.SIZE * Constants.T / 2, 0, Constants.SIZE * Constants.T / 2))
	
	# Add lighting
	var dir_light = DirectionalLight3D.new()
	dir_light.light_energy = 0.8
	dir_light.rotation_degrees = Vector3(-45, 45, 0)
	add_child(dir_light)
	
	var ambient = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Constants.SKY_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.3, 0.3)
	ambient.environment = env
	add_child(ambient)

func spawn_initial_creatures():
	for i in range(Constants.PLAYER_COUNT):
		var dx = randf() * Constants.SIZE * Constants.T
		var dz = randf() * Constants.SIZE * Constants.T
		var pos = Vector3(dx, 0, dz)
		
		var species = -1
		if i >= 1:
			var index = int(float(i) / Constants.PLAYER_COUNT * Constants.START_SPECIES.size())
			species = Constants.START_SPECIES[index]
		
		spawn_creature(species, pos, false, true, randf_range(0.3333, 0.6666), randf_range(0.3333, 0.6666), 0)

func spawn_creature(species: int, pos: Vector3, burst: bool, primordial: bool, hunger: float, thirst: float, gen: int):
	var creature = Creature.new()
	creature.terrain_map = terrain_map
	creature.game_manager = self
	creature.creature_id = max_id
	max_id += 1
	
	add_child(creature)
	creature.initialize(species, pos, burst, primordial, hunger, thirst, gen)
	creatures.append(creature)
	return creature

func _process(_delta):
	ticks += 1
	
	# Do archive
	if ticks % ARCHIVE_EVERY == 0:
		do_archive()
	
	# Remove dead creatures
	garbage_removal()
	
	# Update camera
	update_camera()

func do_archive():
	var populations = get_populations()
	var daylight = 0.5 - 0.5 * cos(ticks / Constants.TICKS_PER_DAY * TAU)
	archive.append({"populations": populations, "daylight": daylight})
	while archive.size() > ARCHIVE_SIZE:
		archive.pop_front()

func get_populations() -> Array:
	var result = []
	result.resize(Constants.SPECIES_COUNT)
	for i in range(Constants.SPECIES_COUNT):
		result[i] = 0
	
	for creature in creatures:
		if creature.species >= 0:
			result[creature.species] += 1
	
	return result

func garbage_removal():
	for i in range(creatures.size() - 1, -1, -1):
		if creatures[i].to_die:
			creatures[i].queue_free()
			creatures.remove_at(i)

func setup_ui():
	ui_overlay = UIOverlay.new()
	ui_overlay.game_manager = self
	add_child(ui_overlay)

func update_camera():
	if camera_follow_mode and camera_target and not camera_target.is_queued_for_deletion():
		# Follow target creature
		var offset = Vector3(0, 150, 150)
		var target_pos = camera_target.position + offset
		player_camera.position = player_camera.position.lerp(target_pos, 0.1)
		player_camera.look_at(camera_target.position)
	else:
		# Free camera - find nearest animal
		var nearest = find_nearest_animal()
		if nearest:
			camera_target = nearest
			var offset = Vector3(0, 200, 200)
			var target_pos = camera_target.position + offset
			player_camera.position = player_camera.position.lerp(target_pos, 0.02)
			player_camera.look_at(camera_target.position)

func find_nearest_animal() -> Node3D:
	var nearest = null
	var nearest_dist = 999999.0
	for creature in creatures:
		if Constants.get_species_type(creature.species) >= 1:
			var dist = player_camera.position.distance_to(creature.position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = creature
	return nearest

func _input(event):
	if event is InputEventKey and event.pressed:
		# Camera controls
		if event.keycode == KEY_W:
			player_camera.position.z -= 50
		elif event.keycode == KEY_S:
			player_camera.position.z += 50
		elif event.keycode == KEY_A:
			player_camera.position.x -= 50
		elif event.keycode == KEY_D:
			player_camera.position.x += 50
		elif event.keycode == KEY_SPACE:
			player_camera.position.y += 50
		elif event.keycode == KEY_SHIFT:
			player_camera.position.y -= 50
		elif event.keycode == KEY_C:
			# Toggle follow mode
			camera_follow_mode = not camera_follow_mode
			if camera_follow_mode:
				camera_target = find_nearest_animal()
		elif event.keycode == KEY_T:
			# Switch to target of current creature
			if camera_target and "target" in camera_target and camera_target.target:
				camera_target = camera_target.target
