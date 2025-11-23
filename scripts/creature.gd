extends Node3D

const Constants = preload("res://scripts/constants.gd")
const CreatureAI = preload("res://scripts/creature_ai.gd")

var species: int = 0
var coor: Vector3 = Vector3.ZERO
var velo: Vector3 = Vector3.ZERO
var rotation_angle: float = 0.0
var priorities: Array = [0.5, 0.5, 1.0, 1.0, 1.0, 1.0]  # hunger, thirst, freaky, eepy, flee, caretaking
var size: float = 0.0
var to_die: bool = false
var plant_landed: bool = false
var walk_speed: float = -1.0
var tick_bucket: int = 0

var target: Node3D = null
var predator: Node3D = null
var top_priority: int = -1
var wander_action: int = -1
var time_of_last_meal: int = -99999
var recent_child: Node3D = null

var mesh_instance: MeshInstance3D
var terrain_map: Node3D
var game_manager: Node
var creature_id: int = 0
var creature_name: String = ""
var generation: int = 0
var ai: CreatureAI = null
var children: Array = []

const FRICTION = 0.85
const ACCEL = 2.0
const WANDER_ACCEL = 1.0

func _ready():
	create_mesh()
	if Constants.get_species_type(species) >= 1:
		tick_bucket = randi() % 20
		creature_name = generate_name()
		ai = CreatureAI.new(self, game_manager, terrain_map)

func initialize(spec: int, pos: Vector3, burst: bool, primordial: bool, hunger: float, thirst: float, gen: int):
	species = spec
	coor = pos
	position = coor
	generation = gen
	
	if burst:
		var angle = randf() * TAU
		var dist = randf_range(2.0, 11.0)
		velo = Vector3(cos(angle) * dist, 18.0, sin(angle) * dist)
		if terrain_map:
			coor.y = terrain_map.get_ground_level(coor) + 0.1
	else:
		plant_landed = true
	
	priorities[0] = hunger
	priorities[1] = thirst
	
	if Constants.get_species_type(species) == 0:
		if primordial:
			size = randf()
		else:
			size = 0.0

func create_mesh():
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	update_mesh()

func update_mesh():
	if Constants.get_species_type(species) == 0:
		create_flower_mesh()
	else:
		create_creature_mesh()

func create_flower_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	const MIN_FLOWER_SCALE = 0.15
	var flower_scale = MIN_FLOWER_SCALE + size
	var height = 75.0 * flower_scale
	var width = 7.0 * flower_scale
	var petal_width = 30.0 * flower_scale
	
	var color = Constants.SPECIES_COLORS[species]
	
	# Stem
	st.set_color(Color(0.0, 0.31, 0.0))
	add_box(st, Vector3(0, height / 2, 0), Vector3(width, height, width))
	
	# Upper stem
	st.set_color(Color(0.0, 0.63, 0.0))
	add_box(st, Vector3(0, height - height / 2 * size, 0), Vector3(width + 1, height * size, width + 1))
	
	# Flower head center
	st.set_color(Color(1.0, 1.0, 0.0) if species == 0 else Color(1.0, 1.0, 1.0))
	add_sphere(st, Vector3(0, height, 0), petal_width * 0.65, 8)
	
	# Petals
	st.set_color(color)
	for p in range(5):
		var ang = p * TAU / 5.0
		var petal_pos = Vector3(cos(ang) * petal_width, height, sin(ang) * petal_width)
		add_sphere(st, petal_pos, petal_width * 0.8, 6)
	
	st.generate_normals()
	mesh_instance.mesh = st.commit()
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh_instance.material_override = mat

func create_creature_mesh():
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var color = Constants.SPECIES_COLORS[species]
	var head_r = 20.0
	var scale_y = 10.0
	var scale_z = 10.0
	var limb_w = 3.0
	
	# Limbs
	st.set_color(Color(0.2, 0.2, 0.2))
	var limb_positions = []
	if Constants.get_species_type(species) == 1:  # Herbivore
		limb_positions = [
			[0, 0, 2, -1, -1],
			[0, 0, 2, 1, 1],
			[-4, 0, 2, -1, 1],
			[-4, 0, 2, 1, -1]
		]
	else:  # Carnivore
		limb_positions = [
			[0, 0, 4, 0, 0],
			[0, 0, 4, -1, -1],
			[0, 0, 4, 1, 1],
			[0, 0, 2, -1, 1],
			[0, 0, 2, 1, -1]
		]
	
	for limb in limb_positions:
		var pos = Vector3(limb[0] * scale_z, limb[2] * scale_z, limb[1] * scale_y)
		add_box(st, pos + Vector3(0, -scale_z, 0), Vector3(limb_w, 2 * scale_z, limb_w))
	
	# Head
	st.set_color(color)
	var body_height = 2 if Constants.get_species_type(species) in [1, 2] else 4
	add_sphere(st, Vector3(0, body_height * scale_z + head_r, 0), head_r, 8)
	
	# Body (for herbivores)
	if Constants.get_species_type(species) == 1:
		var meat = (2 * priorities[0] + 0.05) * scale_y
		add_box(st, Vector3(-2 * scale_y, 2 * scale_y, 0), Vector3(4 * scale_y + limb_w, meat, meat))
	
	st.generate_normals()
	mesh_instance.mesh = st.commit()
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh_instance.material_override = mat

func add_box(st: SurfaceTool, center: Vector3, sz: Vector3):
	var half = sz / 2
	var verts = [
		center + Vector3(-half.x, -half.y, -half.z),
		center + Vector3(half.x, -half.y, -half.z),
		center + Vector3(half.x, half.y, -half.z),
		center + Vector3(-half.x, half.y, -half.z),
		center + Vector3(-half.x, -half.y, half.z),
		center + Vector3(half.x, -half.y, half.z),
		center + Vector3(half.x, half.y, half.z),
		center + Vector3(-half.x, half.y, half.z)
	]
	
	var faces = [
		[0,1,2, 0,2,3], [1,5,6, 1,6,2], [5,4,7, 5,7,6],
		[4,0,3, 4,3,7], [3,2,6, 3,6,7], [4,5,1, 4,1,0]
	]
	
	for face in faces:
		for idx in face:
			st.add_vertex(verts[idx])

func add_sphere(st: SurfaceTool, center: Vector3, radius: float, segments: int):
	var rings = max(1, int(segments / 2.0))
	for i in range(rings):
		var lat0 = PI * (-0.5 + float(i) / rings)
		var lat1 = PI * (-0.5 + float(i + 1) / rings)
		var y0 = sin(lat0) * radius
		var y1 = sin(lat1) * radius
		var r0 = cos(lat0) * radius
		var r1 = cos(lat1) * radius
		
		for j in range(segments):
			var lng0 = TAU * float(j) / segments
			var lng1 = TAU * float(j + 1) / segments
			
			var x00 = cos(lng0) * r0
			var z00 = sin(lng0) * r0
			var x01 = cos(lng0) * r1
			var z01 = sin(lng0) * r1
			var x10 = cos(lng1) * r0
			var z10 = sin(lng1) * r0
			var x11 = cos(lng1) * r1
			var z11 = sin(lng1) * r1
			
			st.add_vertex(center + Vector3(x00, y0, z00))
			st.add_vertex(center + Vector3(x10, y0, z10))
			st.add_vertex(center + Vector3(x11, y1, z11))
			
			st.add_vertex(center + Vector3(x00, y0, z00))
			st.add_vertex(center + Vector3(x11, y1, z11))
			st.add_vertex(center + Vector3(x01, y1, z01))

func generate_name() -> String:
	var length = randi() % 4 + 5
	var consonants = "BCDFGHJKLMNPQRSTVWXZ"
	var vowels = "AEIOUY"
	var result = ""
	var inversion = randf() < 0.5
	
	for i in range(length):
		var options = vowels if (i % 2 == 1) != inversion else consonants
		var letter = options[randi() % options.length()]
		if i > 0:
			letter = letter.to_lower()
		result += letter
	
	return result

func do_physics(delta: float):
	if Constants.get_species_type(species) == 0:
		plant_physics()
	
	# AI actions
	if Constants.get_species_type(species) >= 1 and ai:
		ai.do_actions()
	
	# Apply velocity
	coor += velo * delta * 30.0  # Scale for fixed timestep equivalent
	
	# Apply friction
	velo.x *= FRICTION
	velo.z *= FRICTION
	
	# Wrap around world
	var world_size = Constants.SIZE * Constants.T
	if coor.x < 0:
		coor.x += world_size
	elif coor.x >= world_size:
		coor.x -= world_size
	if coor.z < 0:
		coor.z += world_size
	elif coor.z >= world_size:
		coor.z -= world_size
	
	# Ground collision
	if terrain_map:
		var ground = terrain_map.get_ground_level(coor)
		if coor.y <= ground:
			coor.y = ground
			velo.y = 0
			if Constants.get_species_type(species) == 0 and not plant_landed:
				if randf() < 0.5:
					var angle = atan2(velo.z, velo.x)
					var dist = randf_range(2.0, 11.0)
					velo = Vector3(cos(angle) * dist, 18.0, sin(angle) * dist)
				else:
					velo = Vector3.ZERO
					plant_landed = true
		else:
			velo.y -= 1.0  # Gravity
	
	# Food chain interactions
	check_interactions()
	
	position = coor
	rotation.y = rotation_angle

func plant_physics():
	if not terrain_map:
		return
	
	var ground = terrain_map.get_ground_level(coor)
	if coor.y > ground:
		return
	
	var ideal_heights = [0.39, 0.73]
	var elev = min(ground / Constants.T / 10.0, 0.78)
	var offby = abs(elev - ideal_heights[species])
	var elev_factor = 0.05 + 0.95 * pow(max(1.0 - offby / 0.25, 0.0), 1.6)
	
	var daylight = 0.5 - 0.5 * cos(game_manager.ticks / Constants.TICKS_PER_DAY * TAU)
	var growth_speed = 0.01 + elev_factor * daylight
	size += growth_speed * randf_range(0.001, 0.002) * Constants.PRIORITY_RATES[species][0]
	
	if size >= 1.0:
		size -= 0.5
		if game_manager:
			game_manager.spawn_creature(species, coor, true, false, 0.5, 0.5, generation + 1)
	
	update_mesh()

func get_target_position(t) -> Vector3:
	if t.has_method("get_position"):
		return t.get_position()
	elif "coor" in t:
		return t.coor
	else:
		return t.position

func check_interactions():
	if not target or target.is_queued_for_deletion():
		return
	
	var distance = coor.distance_to(get_target_position(target))
	
	# Eating
	if top_priority == 0 and not to_die and species >= 0 and "species" in target:
		if target.species >= 0 and Constants.IS_FOOD[species][target.species]:
			if ai and ai.is_edible(target) and distance < Constants.COLLISION_DISTANCE:
				var gained_calories = 0.0
				if Constants.get_species_type(target.species) == 0:
					gained_calories = Constants.CALORIES_RATE[target.species] * target.size
				else:
					gained_calories = Constants.CALORIES_RATE[target.species] * target.priorities[0]
				
				priorities[0] = min(1.0, priorities[0] + gained_calories)
				time_of_last_meal = game_manager.ticks
				target.to_die = true
	
	# Drinking
	if top_priority == 1 and terrain_map:
		var water_level = terrain_map.get_water_level(coor.x, coor.z)
		if coor.y < water_level:
			priorities[1] = min(1.0, priorities[1] + Constants.WATER_CALORIES)
	
	# Mating
	if top_priority == 2 and "species" in target and species >= 0:
		if target.species >= 0 and species == target.species and distance < Constants.COLLISION_DISTANCE:
			# Give birth
			var hunger_for_offspring = (priorities[0] + target.priorities[0]) / 3.0
			priorities[0] -= priorities[0] / 3.0
			target.priorities[0] -= target.priorities[0] / 3.0
			priorities[5] = 0.0
			target.priorities[5] = 0.0
			
			var thirst_for_offspring = (priorities[1] + target.priorities[1]) / 2.0
			
			var child = game_manager.spawn_creature(species, coor, true, false, hunger_for_offspring, thirst_for_offspring, generation + 1)
			priorities[2] = min(1.0, priorities[2] + 0.25)
			
			children.append(child.creature_name)
			if "children" in target:
				target.children.append(child.creature_name)
			recent_child = child
			if "recent_child" in target:
				target.recent_child = child

func _process(delta):
	do_physics(delta)
	
	# Update AI
	if Constants.get_species_type(species) >= 1 and ai:
		ai.do_priorities()
