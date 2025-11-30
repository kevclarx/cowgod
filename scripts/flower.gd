@tool
class_name Flower extends Node3D

#var ice_flower = preload("res://assets/iceflower.glb")
@onready var flower_model = $StaticBody3D/IceFlower
var angular_speed = PI

func _ready() -> void:
	#flower_model = ice_flower.instantiate()
	#flower_model.name = "ice_flower"
	#$StaticBody3D.add_child(flower_model)
	#set_editable_instance(flower_model, true)
	#flower_model.set_owner(get_tree().edited_scene_root)
	pass

func _process(delta: float) -> void:
	flower_model.get_node("Flower").global_rotate(Vector3.UP, angular_speed * delta)
	
