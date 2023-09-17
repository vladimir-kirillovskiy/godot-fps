extends CanvasLayer


@onready var current_weapon_label = $VBoxContainer/HBoxContainer/CurrentWeapon
@onready var current_ammo_label = $VBoxContainer/HBoxContainer2/CurrentAmmo
@onready var weapon_stack_label = $VBoxContainer/HBoxContainer3/WeaponStack




func _on_weapons_manager_update_ammo(ammo):
	current_ammo_label.set_text(str(ammo[0]) + " / " + str(ammo[1]))


func _on_weapons_manager_update_weapon_stack(weapon_stack):
	weapon_stack_label.set_text("")
	for i in weapon_stack:
		weapon_stack_label.text += "\n" + i


func _on_weapons_manager_weapon_change(weapon_name):
	current_weapon_label.set_text(weapon_name)
