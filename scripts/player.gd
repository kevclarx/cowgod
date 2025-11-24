@tool
extends Node3D

# Simple procedural stick-figure renderer using MeshInstance3D parts.
# Configure species and terrain_map from outside (game manager / spawner).

@export var species: int = -1
@export var walk_speed: float = 2.0
var coor: Vector3 = Vector3.ZERO
var ticks: int = 0

# Single mesh instance we redraw each frame using SurfaceTool (immediate-style primitives)
var model_instance: MeshInstance3D

func _ready() -> void:
	model_instance = MeshInstance3D.new()
	add_child(model_instance)
	model_instance.name = "StickFigure"
	set_process(true)
	_update_materials()

func _process(delta: float) -> void:
	ticks += 1
	_draw_stick_figure(delta)

func _species_color(s: int) -> Color:
	if s == -1:
		return Color(0.627,0.627,0.627) # 160/255
	var colors = [
		Color(0.93,0.86,0.78),
		Color(0.47,0.83,0.33),
		Color(0.16,0.64,0.24),
		Color(0.49,0.54,0.61)
	]
	return colors[s % colors.size()]

func _update_materials() -> void:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _species_color(species)
	mat.emission = _species_color(species)
	mat.emission_enabled = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	model_instance.material_override = mat

# --- Small primitive helpers using SurfaceTool ---
func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var n = (b - a).cross(c - a)
	if n.length() == 0:
		n = Vector3.UP
	else:
		n = n.normalized()
	st.set_normal(n)
	st.set_color(color); st.add_vertex(a)
	st.set_normal(n)
	st.set_color(color); st.add_vertex(b)
	st.set_normal(n)
	st.set_color(color); st.add_vertex(c)

func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_add_triangle(st, a, b, c, color)
	_add_triangle(st, a, c, d, color)

func _add_box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var hx = size.x * 0.5
	var hy = size.y * 0.5
	var hz = size.z * 0.5
	var p0 = center + Vector3(-hx, -hy, -hz)
	var p1 = center + Vector3(hx, -hy, -hz)
	var p2 = center + Vector3(hx, hy, -hz)
	var p3 = center + Vector3(-hx, hy, -hz)
	var p4 = center + Vector3(-hx, -hy, hz)
	var p5 = center + Vector3(hx, -hy, hz)
	var p6 = center + Vector3(hx, hy, hz)
	var p7 = center + Vector3(-hx, hy, hz)
	# -Z face
	_add_quad(st, p0, p1, p2, p3, color)
	# +Z face
	_add_quad(st, p5, p4, p7, p6, color)
	# -X face
	_add_quad(st, p4, p0, p3, p7, color)
	# +X face
	_add_quad(st, p1, p5, p6, p2, color)
	# -Y face
	_add_quad(st, p4, p5, p1, p0, color)
	# +Y face
	_add_quad(st, p3, p2, p6, p7, color)

# draw a thin rectangular limb as a rotated quad (simpler than true cylinder)
func _add_limb_plane(st: SurfaceTool, base_pos: Vector3, length: float, width: float, angle_rad: float, color: Color) -> void:
	# limb goes down in -Y, swings in X by sin(angle)
	var dir = Vector3(sin(angle_rad) * 0.6, -1.0, 0.0).normalized() * length
	var p0 = base_pos
	var p1 = base_pos + dir
	# perpendicular in Z for a thin plane
	var perp = Vector3(0,0,1) * (width * 0.5)
	var a = p0 - perp
	var b = p0 + perp
	var c = p1 + perp
	var d = p1 - perp
	_add_quad(st, a, b, c, d, color)

# simple sphere via lat/lon triangles (coarse)
func _add_sphere(st: SurfaceTool, center: Vector3, radius: float, color: Color, stacks: int = 6, slices: int = 10) -> void:
	for i in range(stacks):
		var phi0 = PI * float(i) / stacks - PI * 0.5
		var phi1 = PI * float(i + 1) / stacks - PI * 0.5
		for j in range(slices):
			var theta0 = TAU * float(j) / slices
			var theta1 = TAU * float(j + 1) / slices
			var p00 = center + Vector3(cos(phi0) * cos(theta0), sin(phi0), cos(phi0) * sin(theta0)) * radius
			var p01 = center + Vector3(cos(phi0) * cos(theta1), sin(phi0), cos(phi0) * sin(theta1)) * radius
			var p10 = center + Vector3(cos(phi1) * cos(theta0), sin(phi1), cos(phi1) * sin(theta0)) * radius
			var p11 = center + Vector3(cos(phi1) * cos(theta1), sin(phi1), cos(phi1) * sin(theta1)) * radius
			_add_triangle(st, p00, p10, p11, color)
			_add_triangle(st, p00, p11, p01, color)

# --- Face & mouth helpers translated from Processing ---
func _draw_smile(st: SurfaceTool, center: Vector3, radius: float, W: float, pieces: int, color: Color) -> void:
	# build an approximated ring as a triangle strip fan (2 loops)
	var outer := [] 
	var inner := []
	for i in range(pieces + 1):
		var ang = float(i) / pieces * PI * 0.8 + PI * 1.1
		var ix = cos(ang) * (radius - W * 0.5)
		var iy = sin(ang) * (radius - W * 0.5)
		var ox = cos(ang) * (radius + W * 0.5)
		var oy = sin(ang) * (radius + W * 0.5)
		inner.append(Vector3(ix, iy, 0))
		outer.append(Vector3(ox, oy, 0))
	# center is in head local space; create triangles
	for i in range(pieces):
		var a = center + inner[i]
		var b = center + outer[i]
		var c = center + outer[i + 1]
		var d = center + inner[i + 1]
		_add_quad(st, a, b, c, d, color)

# --- Main: translate Processing drawStickFigure -> build mesh ---
func _draw_stick_figure(_delta: float) -> void:
	# Ensure model_instance exists (guard against editor/script reloads where onready became Nil)
	if not model_instance:
		model_instance = MeshInstance3D.new()
		model_instance.name = "StickFigure"
		add_child(model_instance)
		_update_materials()

	# Processing timing uses millis(); we use ticks (frame count)
	var walk_swing = sin(float(ticks) * 0.04 * walk_speed)
	var walk_swing2 = sin(float(ticks) * 0.052 * walk_speed)
	var idle_swing = sin(float(ticks) * 0.003 * walk_speed)
	#var inAir = (coor.y > _get_ground_level_at_position(coor))
	#if inAir:
		#walk_swing = 0.0
		#walk_swing2 = 0.0
		#idle_swing = 0.0

	# Processing SCALEs are large (10-ish). Use them but scale down later.
	var SCALE_Y = 10.0
	var SCALE_Z = 10.0
	if walk_speed >= 0.001:
		SCALE_Z = 10.0 + walk_swing2
	else:
		SCALE_Z = 10.0 + 0.26 * idle_swing

	var limbW = 3.0
	var limbColor = Color(50.0/255.0,50.0/255.0,50.0/255.0)
	# Build mesh
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# body color logic (closest_AI / trait highlights are best-effort guarded)
	var bodyColor = _species_color(species)
	# HEAD and BODY sizes - translate Processing numeric sizes into Godot units
	var HEAD_R = 0.2 # corresponds roughly to Processing 20
	var BODY_HEIGHT = 0.4 if (((species % 3) + 1) % 3 == 0) else 0.2

	# HEAD - translate upward by BODY_HEIGHT*SCALE_Z + HEAD_R (scale down)
	var head_offset = BODY_HEIGHT * SCALE_Z * 0.01
	var head_pos = Vector3(0, head_offset + HEAD_R, 0)
	_add_sphere(st, head_pos, HEAD_R, bodyColor, 6, 10)

	# commit mesh and assign (model_instance guaranteed non-null)
	var mesh = st.commit()
	model_instance.mesh = mesh
	global_position = coor
