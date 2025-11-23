extends Node3D

const Constants = preload("res://scripts/constants.gd")

var elev: Array = []  # 2D array of elevations
var tiles: Array = []  # 2D array of Tile objects
var closest_water: Array = []  # 3D array for closest water coordinates
var N: int = Constants.SIZE
var ELEV_FACTOR: float = 10.0
var WATER_DEEP: float = 20.0
var WATER_LEVEL: float = 2.44 * Constants.T
var WAVE_SIZE: float = 10.0
var WAVE_PERIOD: float = 100.0
var ticks: int = 0

var noise: FastNoiseLite
var ground_mesh_instance: MeshInstance3D
var water_mesh_instance: MeshInstance3D

func _ready():
	initialize_map()
	generate_mesh()

func initialize_map():
	# Initialize noise
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.1
	noise.seed = randi()
	
	# Initialize arrays
	elev.resize(N)
	tiles.resize(N)
	closest_water.resize(N)
	
	for x in range(N):
		elev[x] = []
		elev[x].resize(N)
		tiles[x] = []
		tiles[x].resize(N)
		closest_water[x] = []
		closest_water[x].resize(N)
		for y in range(N):
			tiles[x][y] = []  # Array of occupants
			closest_water[x][y] = [x, y]
	
	# Generate elevation
	var max_elev = -9999.0
	var min_elev = 9999.0
	
	for x in range(N):
		for y in range(N):
			var noi_val = get_noise_at(x, y)
			elev[x][y] = noi_val
			max_elev = max(max_elev, noi_val)
			min_elev = min(min_elev, noi_val)
	
	# Normalize elevation
	for x in range(N):
		for y in range(N):
			elev[x][y] = (elev[x][y] - min_elev) / (max_elev - min_elev) * ELEV_FACTOR
	
	# Find closest water for each tile
	for x in range(N):
		for y in range(N):
			closest_water[x][y] = find_closest_water(x, y)

func get_noise_at(x: int, y: int) -> float:
	# Seamless noise by averaging corners with wrapping
	var NR = 0.1
	var smooth = N * 0.1
	
	var noi = [
		[noise.get_noise_2d(x * NR, y * NR), noise.get_noise_2d(x * NR, (y - N) * NR)],
		[noise.get_noise_2d((x - N) * NR, y * NR), noise.get_noise_2d((x - N) * NR, (y - N) * NR)]
	]
	
	var x_lerp = clamp((x - (N - smooth)) / smooth, 0.0, 1.0)
	var y_lerp = clamp((y - (N - smooth)) / smooth, 0.0, 1.0)
	
	var mid_val_1 = lerp(noi[0][0], noi[0][1], y_lerp)
	var mid_val_2 = lerp(noi[1][0], noi[1][1], y_lerp)
	var final_val = lerp(mid_val_1, mid_val_2, x_lerp)
	
	return final_val

func find_closest_water(x: int, y: int) -> Array:
	if elev[x][y] * Constants.T <= WATER_LEVEL - WATER_DEEP:
		return [x, y]
	
	for dist in range(1, N / 2 + 1):
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
	
	return [x, y]

func get_ground_level(pos: Vector3) -> float:
	var x_val = clamp(pos.x / Constants.T, 0.0, N - 0.001)
	var y_val = clamp(pos.z / Constants.T, 0.0, N - 0.001)
	
	var x_int = int(x_val)
	var x_rem = x_val - x_int
	var y_int = int(y_val)
	var y_rem = y_val - y_int
	
	var x2_int = (x_int + 1) % N
	var y2_int = (y_int + 1) % N
	
	var elev1 = lerp(elev[x_int][y_int], elev[x_int][y2_int], y_rem)
	var elev2 = lerp(elev[x2_int][y_int], elev[x2_int][y2_int], y_rem)
	
	return Constants.T * lerp(elev1, elev2, x_rem)

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
	# Create ground mesh instance
	ground_mesh_instance = MeshInstance3D.new()
	add_child(ground_mesh_instance)
	
	# Create water mesh instance
	water_mesh_instance = MeshInstance3D.new()
	add_child(water_mesh_instance)
	
	update_mesh()

func update_mesh():
	# Generate ground mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for x in range(N):
		for y in range(N):
			var x2 = (x + 1) % N
			var y2 = (y + 1) % N
			
			var p00 = Vector3(x * Constants.T, elev[x][y] * Constants.T, y * Constants.T)
			var p01 = Vector3(x * Constants.T, elev[x][y2] * Constants.T, y2 * Constants.T)
			var p10 = Vector3(x2 * Constants.T, elev[x2][y] * Constants.T, y * Constants.T)
			var p11 = Vector3(x2 * Constants.T, elev[x2][y2] * Constants.T, y2 * Constants.T)
			
			var c00 = get_color_at(x, y)
			var c01 = get_color_at(x, y2)
			var c10 = get_color_at(x2, y)
			var c11 = get_color_at(x2, y2)
			
			# First triangle
			st.set_color(c00)
			st.add_vertex(p00)
			st.set_color(c01)
			st.add_vertex(p01)
			st.set_color(c11)
			st.add_vertex(p11)
			
			# Second triangle
			st.set_color(c00)
			st.add_vertex(p00)
			st.set_color(c11)
			st.add_vertex(p11)
			st.set_color(c10)
			st.add_vertex(p10)
	
	st.generate_normals()
	ground_mesh_instance.mesh = st.commit()
	
	# Create material for ground
	var ground_mat = StandardMaterial3D.new()
	ground_mat.vertex_color_use_as_albedo = true
	ground_mesh_instance.material_override = ground_mat
	
	# Generate water mesh
	var wt = SurfaceTool.new()
	wt.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for x in range(N):
		for y in range(N):
			var x2 = (x + 1) % N
			var y2 = (y + 1) % N
			
			var w00 = get_water_level(x * Constants.T, y * Constants.T)
			var w01 = get_water_level(x * Constants.T, y2 * Constants.T)
			var w10 = get_water_level(x2 * Constants.T, y * Constants.T)
			var w11 = get_water_level(x2 * Constants.T, y2 * Constants.T)
			
			var g00 = elev[x][y] * Constants.T
			var g01 = elev[x][y2] * Constants.T
			var g10 = elev[x2][y] * Constants.T
			var g11 = elev[x2][y2] * Constants.T
			
			# Only draw water where ground is below water level
			if g00 <= w00 or g01 <= w01 or g10 <= w10 or g11 <= w11:
				var p00 = Vector3(x * Constants.T, w00, y * Constants.T)
				var p01 = Vector3(x * Constants.T, w01, y2 * Constants.T)
				var p10 = Vector3(x2 * Constants.T, w10, y * Constants.T)
				var p11 = Vector3(x2 * Constants.T, w11, y2 * Constants.T)
				
				# First triangle
				wt.set_color(Constants.WATER_COLOR)
				wt.add_vertex(p00)
				wt.add_vertex(p01)
				wt.add_vertex(p11)
				
				# Second triangle
				wt.add_vertex(p00)
				wt.add_vertex(p11)
				wt.add_vertex(p10)
	
	wt.generate_normals()
	water_mesh_instance.mesh = wt.commit()
	
	# Create material for water
	var water_mat = StandardMaterial3D.new()
	water_mat.vertex_color_use_as_albedo = true
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(Constants.WATER_COLOR, 0.7)
	water_mesh_instance.material_override = water_mat

func _process(_delta):
	ticks += 1
	# Update water mesh periodically for wave animation
	if ticks % 10 == 0:
		update_water_mesh()

func update_water_mesh():
	# Only update water mesh for wave animation
	var wt = SurfaceTool.new()
	wt.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	for x in range(N):
		for y in range(N):
			var x2 = (x + 1) % N
			var y2 = (y + 1) % N
			
			var w00 = get_water_level(x * Constants.T, y * Constants.T)
			var w01 = get_water_level(x * Constants.T, y2 * Constants.T)
			var w10 = get_water_level(x2 * Constants.T, y * Constants.T)
			var w11 = get_water_level(x2 * Constants.T, y2 * Constants.T)
			
			var g00 = elev[x][y] * Constants.T
			var g01 = elev[x][y2] * Constants.T
			var g10 = elev[x2][y] * Constants.T
			var g11 = elev[x2][y2] * Constants.T
			
			if g00 <= w00 or g01 <= w01 or g10 <= w10 or g11 <= w11:
				var p00 = Vector3(x * Constants.T, w00, y * Constants.T)
				var p01 = Vector3(x * Constants.T, w01, y2 * Constants.T)
				var p10 = Vector3(x2 * Constants.T, w10, y * Constants.T)
				var p11 = Vector3(x2 * Constants.T, w11, y2 * Constants.T)
				
				wt.set_color(Constants.WATER_COLOR)
				wt.add_vertex(p00)
				wt.add_vertex(p01)
				wt.add_vertex(p11)
				
				wt.add_vertex(p00)
				wt.add_vertex(p11)
				wt.add_vertex(p10)
	
	wt.generate_normals()
	water_mesh_instance.mesh = wt.commit()
