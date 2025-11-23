@tool
extends Node3D
class_name TerrainMap

const Constants = preload("res://scripts/constants.gd")

# Exposed parameters so the terrain can be edited in the inspector and will update in the editor.
@export var N: int = Constants.SIZE : set = set_N
@export var ELEV_FACTOR: float = 10.0 : set = set_elev_factor
@export var WATER_DEEP: float = 20.0
@export var WATER_LEVEL: float = 2.44 * Constants.T
@export var WAVE_SIZE: float = 10.0
@export var WAVE_PERIOD: float = 100.0
@export var noise_frequency: float = 0.1 : set = set_noise_frequency
@export var noise_seed: int = 0 : set = set_noise_seed
	
var elev: Array[Array]  # 2D array of elevations
var tiles: Array[Array]  # 2D array of Tile objects
var closest_water: Array[Array]  # 3D array for closest water coordinates
var vis: Array[Array]

var ticks: int = 0

var noise: FastNoiseLite
var ground_mesh_instance: MeshInstance3D
var water_mesh_instance: MeshInstance3D

# Internal flag to avoid reinitializing repeatedly while editor is refreshing
var _initialized: bool = false

func _enter_tree() -> void:
	# Ensure MeshInstance children exist both in editor and at runtime
	ground_mesh_instance = get_node_or_null("GroundMesh")
	if ground_mesh_instance == null:
		ground_mesh_instance = MeshInstance3D.new()
		ground_mesh_instance.name = "GroundMesh"
		add_child(ground_mesh_instance)
	
	water_mesh_instance = get_node_or_null("WaterMesh")
	if water_mesh_instance == null:
		water_mesh_instance = MeshInstance3D.new()
		water_mesh_instance.name = "WaterMesh"
		add_child(water_mesh_instance)

func _ready():
	# When running the game, pick a random seed if seed == 0.
	if not Engine.is_editor_hint() and noise_seed == 0:
		noise_seed = randi()
	_initialize_and_build()

func _process(_delta: float) -> void:
	# In editor, show the mesh updates live when values change.
	if Engine.is_editor_hint():
		# Only initialize once per editor session unless params change
		if not _initialized:
			_initialize_and_build()
		# animate water in editor preview (optional)
		ticks += 1
		# keep water surface updated
		#if water_mesh_instance:
			#update_mesh()

# Setter helpers — reinitialize when inspector values change
func set_N(v):
	N = v
	_initialized = false
	_initialize_and_build()

func set_elev_factor(v):
	ELEV_FACTOR = v
	_initialized = false
	_initialize_and_build()

func set_noise_frequency(v):
	noise_frequency = v
	_initialized = false
	_initialize_and_build()

func set_noise_seed(v):
	noise_seed = v
	_initialized = false
	_initialize_and_build()

func _initialize_and_build() -> void:
	# (re)initialize arrays/noise and build the mesh
	initialize_map()
	generate_mesh()
	_initialized = true

func initialize_map():
	# clear existing ground and water meshes
	ground_mesh_instance = null
	water_mesh_instance = null
	# Initialize noise
	print("initializing map")
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	# If seed is 0 use a stable random; otherwise use provided seed so editor preview is reproducible
	if noise_seed == 0:
		noise.seed = randi()
	else:
		noise.seed = noise_seed
	
	# Generate elevation
	var maxElev:float = -9999.0
	var minElev:float = 9999.0
	
	# Initialize arrays (resize according to exported N)
	elev = []
	tiles = []
	closest_water = []
	vis = []
	elev.resize(N)
	tiles.resize(N)
	closest_water.resize(N)
	vis.resize(N)
	
	for x in range(N):
		elev[x] = Array([N], TYPE_FLOAT, "", null)
		elev[x].resize(N)
		tiles[x] = Array([N], TYPE_FLOAT, "", null)
		tiles[x].resize(N)
		closest_water[x] = Array([N], TYPE_FLOAT, "", null)
		closest_water[x].resize(N)
		vis[x] = Array([N], TYPE_BOOL, "", null)
		vis[x].resize(N)
		for y in range(N):
			elev[x][y] = get_noise_at(x, y, N, N*0.1)
			#elev[x][y] = 0.5
			tiles[x][y] = 1  # Array of occupants
			maxElev = max(maxElev, elev[x][y])
			minElev = min(minElev,elev[x][y])
			
	# Normalize elevation (safe)
	if maxElev <= minElev:
		# all values equal — use constant mid value
		for x in range(N):
			for y in range(N):
				elev[x][y] = ELEV_FACTOR * 0.5
	else:
		for x in range(N):
			for y in range(N):
				elev[x][y] = (elev[x][y]-minElev)/(maxElev-minElev)*ELEV_FACTOR
	
	# Debug info
	print_debug("noise min:", minElev, "max:", maxElev, "ELEV_FACTOR:", ELEV_FACTOR)
	
	# Find closest water for each tile
	#for x in range(N):
		#for y in range(N):
			#closest_water[x][y] = get_closest_water(x, y)

func get_noise_at(x: float, y: float, mapSize: int, smooth: float) -> float:
	var NR = 0.1
	
	var noi = [
		[noise.get_noise_2d(x * NR, y * NR), noise.get_noise_2d(x * NR, (y - mapSize) * NR)],
		[noise.get_noise_2d((x - mapSize) * NR, y * NR), noise.get_noise_2d((x - mapSize) * NR, (y - mapSize) * NR)]
	]
	
	var x_lerp = clamp((x - (mapSize - smooth)) / smooth, 0.0, 1.0)
	var y_lerp = clamp((y - (mapSize - smooth)) / smooth, 0.0, 1.0)
	
	var mid_val_1 = lerp(noi[0][0], noi[0][1], y_lerp)
	var mid_val_2 = lerp(noi[1][0], noi[1][1], y_lerp)
	var final_val = lerp(mid_val_1, mid_val_2, x_lerp)
	
	return final_val

func get_closest_water(x: int, y: int) -> Array[int]:
	var here: Array[int] = [x, y]
	if elev[x][y] * Constants.T <= WATER_LEVEL - WATER_DEEP:
		return here
	
	for dist in range(1, int(N / 2.0)):
		for shift in range(-dist, dist):
			var deltas = [[dist, shift], [-dist, -shift], [shift, -dist], [-shift, dist]]
			for delta in deltas:
				var x_t = (x + delta[0]) % N
				if x_t < 0:
					x_t += N
				var y_t = (y + delta[1]) % N
				if y_t < 0:
					y_t += N
				if elev[x_t][y_t] * Constants.T <= WATER_LEVEL - WATER_DEEP:
					return [x_t, y_t]
	return here

func get_ground_level(pos: Vector3) -> float:
	# Convert world position -> tile indices for the mesh which is centered at origin
	var half = (N - 1) * Constants.T / 2.0
	var fx = (half - pos.x) / Constants.T
	var fz = (half - pos.z) / Constants.T
	# Use floor to get correct tile index for negatives
	var gx = int(floor(fx)) % N
	if gx < 0:
		gx += N
	var gy = int(floor(fz)) % N
	if gy < 0:
		gy += N
	# Return positive world Y (so higher elev -> larger Y)
	return elev[gx][gy] * Constants.T

func get_water_level(x: float, z: float) -> float:
	var cycle_offset = (x * 3 + z * 2) / N
	return WATER_LEVEL + sin(cycle_offset + ticks * TAU / WAVE_PERIOD) * WAVE_SIZE

func get_color_at(x: int, y: int) -> Color:
	var colors = [
		Color(0.59, 0.53, 0.47),
		Color(0.59, 0.53, 0.47),
		Color(0.93, 0.86, 0.78),
		Color(0.47, 0.83, 0.33),
		Color(0.16, 0.64, 0.24),
		Color(0.6, 0.6, 0.6),
		Color(0.49, 0.54, 0.61),
		Color(1.0, 1.0, 1.0),
		Color(1.0, 1.0, 1.0)
	]
	
	var e = clamp(elev[x][y] / ELEV_FACTOR, 0.0, 1.0)
	e = max(0.0, -0.1 + e * 1.10)
	var fac = e * (colors.size() - 1.001)
	var idx = int(fac)
	var t = fac - idx
	
	if idx >= colors.size() - 1:
		return colors[colors.size() - 1]
	
	return colors[idx].lerp(colors[idx + 1], t)

func generate_mesh():
	# Create or find ground mesh instance (safe for editor)
	if not ground_mesh_instance:
		print("initializing new ground mesh")
		ground_mesh_instance = get_node_or_null("GroundMesh")
		if ground_mesh_instance == null:
			print("adding child groundmesh")
			ground_mesh_instance = MeshInstance3D.new()
			ground_mesh_instance.name = "GroundMesh"
			add_child(ground_mesh_instance)
	
	# Create or find water mesh instance (ensure it's present before generating)
	if not water_mesh_instance:
		water_mesh_instance = get_node_or_null("WaterMesh")
		if water_mesh_instance == null:
			print("adding child watermesh")
			water_mesh_instance = MeshInstance3D.new()
			water_mesh_instance.name = "WaterMesh"
			add_child(water_mesh_instance)
	
	update_mesh()

func update_mesh():
	# Generate ground mesh, rotated 180° around Y and centered at origin
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half = (N - 1) * Constants.T / 2.0

	# iterate only to N-1 to avoid wrapping/connecting last to first
	for x in range(N - 1):
		for y in range(N - 1):
			var x2 = x + 1
			var y2 = y + 1

			# World-space base positions (centered)
			var base_x = half - x * Constants.T
			var base_x2 = half - x2 * Constants.T
			var base_z = half - y * Constants.T
			var base_z2 = half - y2 * Constants.T

			# Heights (Y) for the four corners
			var h00 = elev[x][y] * Constants.T
			var h01 = elev[x][y2] * Constants.T
			var h10 = elev[x2][y] * Constants.T
			var h11 = elev[x2][y2] * Constants.T

			# Quad corners in Godot: Vector3(x, y, z) with y = elevation
			var p0 = Vector3(base_x,  h00, base_z)   # (x, y)
			var p1 = Vector3(base_x,  h01, base_z2)  # (x, y+1)
			var p2 = Vector3(base_x2, h11, base_z2)  # (x+1, y+1)
			var p3 = Vector3(base_x2, h10, base_z)   # (x+1, y)

			# Colors for corners
			var c00 = get_color_at(x, y)
			var c01 = get_color_at(x, y2)
			var c10 = get_color_at(x2, y)
			var c11 = get_color_at(x2, y2)

			# Use CLOCKWISE winding (Godot editor expectation) -> triangles: (p0,p3,p2) and (p0,p2,p1)
			# Triangle 1: p0, p3, p2
			var n1 = (p3 - p0).cross(p2 - p0).normalized()
			if n1.dot(Vector3.UP) < 0:
				n1 = -n1
			st.set_normal(n1)
			st.set_color(c00); st.add_vertex(p0)
			st.set_normal(n1)
			st.set_color(c10); st.add_vertex(p3)
			st.set_normal(n1)
			st.set_color(c11); st.add_vertex(p2)
			
			# Triangle 2: p0, p2, p1
			var n2 = (p2 - p0).cross(p1 - p0).normalized()
			if n2.dot(Vector3.UP) < 0:
				n2 = -n2
			st.set_normal(n2)
			st.set_color(c00); st.add_vertex(p0)
			st.set_normal(n2)
			st.set_color(c11); st.add_vertex(p2)
			st.set_normal(n2)
			st.set_color(c01); st.add_vertex(p1)

	ground_mesh_instance.mesh = st.commit()

	# Ensure vertex colors are used by the material and make material non-metallic / high roughness
	var ground_mat = StandardMaterial3D.new()
	ground_mat.vertex_color_use_as_albedo = true
	ground_mat.albedo_color = Color(1,1,1)
	ground_mat.metallic = 0.0
	ground_mat.roughness = 1.0

	# Collect available property names safely
	var prop_names: Array = []
	for p in ground_mat.get_property_list():
		if p.has("name"):
			prop_names.append(p.name)

	# Prefer Godot 4 shading_mode, fall back to Godot 3 'unshaded' when present
	if "shading_mode" in prop_names:
		ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif "unshaded" in prop_names:
		ground_mat.unshaded = true

	# Emission fallback so colors remain visible if lighting behaves unexpectedly
	if "emission" in prop_names:
		ground_mat.emission = Color(1,1,1)
	if "emission_enabled" in prop_names:
		ground_mat.emission_enabled = true

	ground_mat.cull_mode = BaseMaterial3D.CULL_BACK
	ground_mesh_instance.material_override = ground_mat

	# Generate water mesh
	generate_water_surface()

func generate_water_surface():
	# Ensure water mesh instance exists
	if not water_mesh_instance:
		water_mesh_instance = get_node_or_null("WaterMesh")
		if water_mesh_instance == null:
			water_mesh_instance = MeshInstance3D.new()
			water_mesh_instance.name = "WaterMesh"
			add_child(water_mesh_instance)

	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half = (N - 1) * Constants.T / 2.0

	# small upward offset to reduce z-fighting with the ground (increase if needed)
	var WATER_EPS := 0.05 * Constants.T
	# define water color once (in scope for material assignment)
	var water_col := Color(0.0, 0.45, 0.8, 0.6)

	# iterate only to N-1 to avoid wrapping/connecting last to first (which can create stretched planes)
	for x in range(N - 1):
		for y in range(N - 1):
			var x2 = x + 1
			var y2 = y + 1

			# world-space bases
			var base_x = half - x * Constants.T
			var base_x2 = half - x2 * Constants.T
			var base_z = half - y * Constants.T
			var base_z2 = half - y2 * Constants.T

			# sample water level and lift slightly to avoid z-fighting
			var p00 = Vector3(base_x,  get_water_level(base_x, base_z) + WATER_EPS, base_z)
			var p01 = Vector3(base_x,  get_water_level(base_x, base_z2) + WATER_EPS, base_z2)
			var p10 = Vector3(base_x2, get_water_level(base_x2, base_z) + WATER_EPS, base_z)
			var p11 = Vector3(base_x2, get_water_level(base_x2, base_z2) + WATER_EPS, base_z2)

			var wn1 = (p11 - p00).cross(p10 - p00).normalized()
			if wn1.dot(Vector3.UP) < 0:
				wn1 = -wn1
			st.set_normal(wn1)
			st.set_color(water_col); st.add_vertex(p00)
			st.set_normal(wn1)
			st.set_color(water_col); st.add_vertex(p11)
			st.set_normal(wn1)
			st.set_color(water_col); st.add_vertex(p10)

			var wn2 = (p01 - p00).cross(p11 - p00).normalized()
			if wn2.dot(Vector3.UP) < 0:
				wn2 = -wn2
			st.set_normal(wn2)
			st.set_color(water_col); st.add_vertex(p00)
			st.set_normal(wn2)
			st.set_color(water_col); st.add_vertex(p01)
			st.set_normal(wn2)
			st.set_color(water_col); st.add_vertex(p11)

	water_mesh_instance.mesh = st.commit()

	# Create a simple unshaded, two-sided material to avoid artifacts
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = water_col
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = false
	water_mesh_instance.material_override = mat
