@tool
class_name Map extends Node3D

var _skip_setter := true

# Exposed parameters so the terrain can be edited in the inspector and will update in the editor.
@export var N: int = Constants.SIZE: set = set_N
@export var ELEV_FACTOR: float = 10.0 : set = set_elev_factor
@export var WATER_DEEP: float = 20.0
@export var WATER_LEVEL: float = 2.44 * Constants.T
@export var WAVE_SIZE: float = 10.0
@export var WAVE_PERIOD: float = 100.0
@export var noise_frequency: float = 0.1 : set = set_noise_frequency
@export var noise_seed: int = randi() : set = set_noise_seed
	
var elev: Array[Array]  # 2D array of elevations
var tiles: Array[Array]  # 2D array of Tile objects
var closest_water: Array[Array]  # 3D array for closest water coordinates
var vis: Array[Array]
var ticks: int = 0
var noise: FastNoiseLite

@onready var ground_mesh = $StaticBody3D/GroundMesh
@onready var water_mesh = $StaticBody3D/WaterMesh

# Internal flag to avoid reinitializing repeatedly while editor is refreshing
var _initialized: bool = false

func _ready():
	_initialize_and_build()
	_skip_setter = false

func _process(_delta: float) -> void:
	if _initialized:
		ticks += 1
		water_mesh.update_water_mesh(N)

# Setter helpers — reinitialize when inspector values change
func set_N(v):
	N = v
	_initialized = false
	print("setting N")
	if not _skip_setter:
		_initialize_and_build()

func set_elev_factor(v):
	ELEV_FACTOR = v
	_initialized = false
	print("setting elev_factor")
	if not _skip_setter:
		_initialize_and_build()

func set_noise_frequency(v):
	noise_frequency = v
	_initialized = false
	print("setting noise freq")
	if not _skip_setter:
		_initialize_and_build()

func set_noise_seed(v):
	noise_seed = v
	_initialized = false
	print("setting noise seed")
	if not _skip_setter:
		_initialize_and_build()

func _initialize_and_build() -> void:
	# (re)initialize arrays/noise and build the mesh
	initialize_map()
	ground_mesh.update_ground_mesh(N, elev)
	_initialized = true

func initialize_map():
	# Initialize noise
	print("initializing map")
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_frequency
	noise.seed = randi()
	
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
		elev[x] = Array([], TYPE_FLOAT, "", null)
		elev[x].resize(N)
		tiles[x] = Array([], TYPE_OBJECT, "", null)
		tiles[x].resize(N)
		closest_water[x] = Array([], TYPE_FLOAT, "", null)
		closest_water[x].resize(N)
		vis[x] = Array([], TYPE_BOOL, "", null)
		vis[x].resize(N)
		for y in range(N):
			elev[x][y] = get_noise_at(x, y, N, N*0.1)
			tiles[x][y] = Tile.new()
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

func get_water_level(x: float, z: float) -> float:
	var cycle_offset = (x * 3 + z * 2) / N
	return WATER_LEVEL + sin(cycle_offset + ticks * TAU / WAVE_PERIOD) * WAVE_SIZE
