extends RigidBody3D

@export var weapon_name: String
@export var current_ammo: int
@export var reserve_ammo: int

@export_enum("weapon", "ammo") var pick_up_type: String = "weapon"

var pick_up_ready = false

func _ready():
	await get_tree().create_timer(2.0).timeout
	pick_up_ready = true
