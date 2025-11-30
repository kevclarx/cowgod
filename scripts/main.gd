@tool
class_name main extends Node

# Use the UIOverlay global class defined via `class_name UIOverlay` in ui_overlay.gd
# (do not preload to avoid shadowing the global identifier)

var creatures: Array = []
var ticks: int = 0
var archive: Array = []
var max_id: int = 0
var ui_overlay: Control
@onready var map = $Map
@onready var player = $Player

@export var flower: PackedScene

const ARCHIVE_EVERY = 30
const ARCHIVE_SIZE = 200

func _ready():
	#randomize()
	#setup_ui()
	#start_game()
	set_process(true)
	start_game()

func start_game():
	setup_world()
	#spawn_initial_creatures()
	
func setup_world():
	# generate the map
	if map.is_initialized():
		# spawn the player
		# player.set_player_position()
		var map_bounds = $Map/StaticBody3D/GroundMesh.get_aabb()
		print("Map bounds: position %v end %v size %v" % [map_bounds.position, map_bounds.end, map_bounds.size])
		for i in range(40):
			var dx = randf() * Constants.SIZE * Constants.T
			var dz = randf() * Constants.SIZE * Constants.T
			var random_position = Vector3(dx, 0, dz)
			var flower_position = Vector3(dx, map.get_ground_level(random_position), dz)
			var ice_flower = flower.instantiate()
			ice_flower.position = flower_position
			ice_flower.scale *= 40
			print("spawning flower at %v" % ice_flower.position)
			add_child(ice_flower)
			
			#ice_flower.owner = ice_flower.get_parent()
	


#func spawn_initial_creatures():
	#for i in range(Constants.PLAYER_COUNT):
		#var dx = randf() * Constants.SIZE * Constants.T
		#var dz = randf() * Constants.SIZE * Constants.T
		#var pos = Vector3(dx, 0, dz)
		#
		#var species = -1
		#if i >= 1:
			#var index = int(float(i) / Constants.PLAYER_COUNT * Constants.START_SPECIES.size())
			#species = Constants.START_SPECIES[index]
		#
		#spawn_creature(species, pos, false, true, randf_range(0.3333, 0.6666), randf_range(0.3333, 0.6666), 0)

#func spawn_creature(species: int, pos: Vector3, burst: bool, primordial: bool, hunger: float, thirst: float, gen: int):
	#var creature = Creature.new()
	#creature.terrain_map = terrain_map
	#creature.game_manager = self
	#creature.creature_id = max_id
	#max_id += 1
	#
	#add_child(creature)
	#creature.initialize(species, pos, burst, primordial, hunger, thirst, gen)
	#creatures.append(creature)
	#return creature

func _process(delta):
	ticks += 1
	# Do archive
	#if ticks % ARCHIVE_EVERY == 0:
		#do_archive()
	#
	## Remove dead creatures
	#garbage_removal()

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

#func find_nearest_animal() -> Node3D:
	#var nearest = null
	#var nearest_dist = 999999.0
	#for creature in creatures:
		#if Constants.get_species_type(creature.species) >= 1:
			#var dist = player_camera.position.distance_to(creature.position)
			#if dist < nearest_dist:
				#nearest_dist = dist
				#nearest = creature
	#return nearest
