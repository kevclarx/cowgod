class_name Player extends CharacterBody3D

@export var map: Node3D
@export var speed: int = 14
@export var fall_acceleration: int = 75
@export var jump_impulse = 400
@export var camera_path: NodePath

var target_velocity = Vector3.ZERO
@onready var anim_player = $Pivot/Stickman/AnimationPlayer
@onready var cam := get_node_or_null(camera_path) as Camera3D

func _ready() -> void:
	#set_player_position()
	pass
	
func _physics_process(delta: float):
	if Engine.is_editor_hint(): return
	if position.y < -10:
		set_player_position()

	# Build local input vector (x = right/left, z = back/forward)
	var input_x := 0.0
	var input_z := 0.0

	if Input.is_action_pressed("move_right"):
		input_x += 1
		anim_player.play("Walk", -1, 4.0, false)
	if Input.is_action_pressed("move_left"):
		input_x -= 1
		anim_player.play("Walk", -1, 4.0, false)
	if Input.is_action_pressed("move_back"):
		input_z -= 1
		anim_player.play("Walk", -1, 4.0, false)
	if Input.is_action_pressed("move_forward"):
		input_z += 1
		anim_player.play("Walk", -1, 4.0, false)

	# Form movement direction in world space relative to camera if available
	var direction = Vector3.ZERO
	if abs(input_x) > 0.0 or abs(input_z) > 0.0:
		# ensure camera reference
		if cam == null and camera_path != null and camera_path != NodePath(""):

			cam = get_node_or_null(camera_path) as Camera3D

		# compute flat camera forward/right
		var cam_f = Vector3.FORWARD
		var cam_r = Vector3.RIGHT
		if cam:
			cam_f = -cam.global_transform.basis.z
			cam_f.y = 0.0
			if cam_f.length() > 0.0001:
				cam_f = cam_f.normalized()
			else:
				cam_f = Vector3.FORWARD
			cam_r = cam.global_transform.basis.x
			cam_r.y = 0.0
			if cam_r.length() > 0.0001:
				cam_r = cam_r.normalized()
			else:
				cam_r = Vector3.RIGHT
		else:
			# fallback to player orientation
			cam_f = -global_transform.basis.z
			cam_f.y = 0.0
			cam_f = cam_f.normalized()
			cam_r = global_transform.basis.x
			cam_r.y = 0.0
			cam_r = cam_r.normalized()

		# combine: forward (W) adds cam_f, back (S) subtracts cam_f
		direction = cam_r * input_x + cam_f * input_z
		direction.y = 0.0
		if direction.length() > 0.001:
			direction = direction.normalized()
			# rotate pivot to face movement direction
			$Pivot.basis = Basis.looking_at(direction, Vector3.UP)

	# Ground Velocity (horizontal)
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed

	# Jumping.
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		target_velocity.y = jump_impulse
		$AudioStreamPlayer3D.play()

	# Vertical Velocity (gravity)
	if not is_on_floor():
		target_velocity.y = target_velocity.y - (fall_acceleration * delta)

	# Moving the Character
	velocity = target_velocity
	move_and_slide()
	
func set_player_position():
	var center_x = Constants.SIZE * Constants.T / 2.0
	var center_z = Constants.SIZE * Constants.T / 2.0
	if map != null and map.has_method("get_ground_level"):
		var ground_y = map.get_ground_level(Vector3(center_x, 0, center_z))
		var center_map = Vector3(center_x, ground_y + 80, center_z)
		position = center_map

func set_terrain_map(tm: Node) -> void:
	map = tm
