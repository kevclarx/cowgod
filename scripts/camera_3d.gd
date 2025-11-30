extends Camera3D

@export var target: Node3D
@export var height: float = 250.0			# vertical distance component used to derive initial distance
@export var horizontal_distance: float = 0.0	# horizontal offset component used to derive initial distance
@export var yaw_deg: float = 0.0				# horizontal angle for the offset (degrees)
@export var pitch_deg: float = -60.0			# pitch in degrees (negative looks down)
@export var smooth_speed: float = 8.0			# higher = snappier follow
@export var look_at_target: bool = true		# whether camera should look at the target

# mouselook settings
@export var enable_mouselook: bool = true
@export var mouse_sensitivity: float = 0.2

# zoom settings (mouse wheel)
@export var min_distance: float = 50.0
@export var max_distance: float = 2000.0
@export var zoom_step: float = 40.0
@export var zoom_sensitivity: float = 1.0

var _mouse_look_active: bool = false
var current_distance: float = 300.0

func _ready() -> void:
	# ensure initial yaw/pitch are sane
	yaw_deg = yaw_deg
	pitch_deg = clamp(pitch_deg, -89.0, 89.0)
	# initialize current_distance from exported components
	current_distance = sqrt(max(0.0001, horizontal_distance * horizontal_distance + height * height))
	current_distance = clamp(current_distance, min_distance, max_distance)
	set_process(true)

func _process(delta: float) -> void:
	if not target or target.is_queued_for_deletion():
		return

	var tgt: Vector3 = target.global_position

	# compute desired camera position using spherical coordinates derived from yaw/pitch
	var yaw_rad: float = deg_to_rad(yaw_deg)
	var pitch_rad: float = deg_to_rad(pitch_deg)

	# spherical offset: X/Z use cos(pitch) * sin/cos(yaw), Y uses sin(pitch)
	var cos_p: float = cos(pitch_rad)
	var offset_x: float = sin(yaw_rad) * cos_p * current_distance
	var offset_z: float = cos(yaw_rad) * cos_p * current_distance
	var offset_y: float = sin(pitch_rad) * current_distance

	var desired_pos: Vector3 = tgt + Vector3(offset_x, offset_y, offset_z)

	# smooth follow
	var t: float = clamp(smooth_speed * delta, 0.0, 1.0)
	global_position = global_position.lerp(desired_pos, t)

	# orient to target or maintain orientation based on pitch/yaw
	if look_at_target:
		look_at(tgt, Vector3.UP)
	else:
		rotation_degrees = Vector3(pitch_deg, yaw_deg, 0.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Right mouse button toggles mouselook
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_mouse_look_active = event.pressed
			if _mouse_look_active:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

		# Mouse wheel zoom
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			current_distance = clamp(current_distance - (zoom_step * zoom_sensitivity), min_distance, max_distance)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			current_distance = clamp(current_distance + (zoom_step * zoom_sensitivity), min_distance, max_distance)

	elif event is InputEventMouseMotion and _mouse_look_active:
		# normal: horizontal motion -> yaw
		yaw_deg -= event.relative.x * mouse_sensitivity
		# inverted vertical motion: move mouse up (negative relative.y) should look up -> increase pitch
		pitch_deg = clamp(pitch_deg + event.relative.y * mouse_sensitivity, -89.0, 89.0)

func get_flat_forward_right() -> Dictionary:
	# Returns flat (y=0) forward and right vectors based on current camera orientation
	var f = -global_transform.basis.z
	f.y = 0.0
	f = f.normalized() if f.length() > 0.0 else Vector3.FORWARD
	var r = global_transform.basis.x
	r.y = 0.0
	r = r.normalized() if r.length() > 0.0 else Vector3.RIGHT
	return {"forward": f, "right": r}
