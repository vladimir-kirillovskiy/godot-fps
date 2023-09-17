extends Node3D

signal weapon_change
signal update_ammo
signal update_weapon_stack	

@onready var animation_player = $FPSRig/AnimationPlayer
@onready var bullet_point = $FPSRig/BulletPoint

var debug_bullet = preload("res://Scenes/bullet_debug.tscn")

var current_weapon = null
var weapon_stack = [] # array of weapons currently held by the player
var weapon_indicator = 0
var next_weapon: String
var weapon_list = {}

@export var _weapon_resources: Array[Weapon_Resource]

@export var start_weapons: Array[String]

enum {NULL, HITSCAN, PROJECTILE}

var collision_exclusion = []


func _ready():
	initialize(start_weapons) # enter the state machine
	
func _input(event):
	if event.is_action_pressed("weapon_up"):
		weapon_indicator = min(weapon_indicator+1, weapon_stack.size() - 1)
		exit(weapon_stack[weapon_indicator])
		
	if event.is_action_pressed("weapon_down"):
		weapon_indicator = max(weapon_indicator-1, 0)
		exit(weapon_stack[weapon_indicator])
		
	if event.is_action_pressed("shoot"):
		shot()
	if event.is_action_pressed("reload"):
		reload()

func initialize(_start_weapons: Array):
	# create a dictionary to refer to our weapons 
	for weapon in _weapon_resources:
		weapon_list[weapon.weapon_name] = weapon  
		
	for i in _start_weapons:
		weapon_stack.push_back(i) # add put start weapon
		
	current_weapon = weapon_list[weapon_stack[0]] # set our current weapon as 1st weapon from stack
	
	emit_signal("update_weapon_stack", weapon_stack)
	
	enter()
	
func enter():
	# call when entering into a weapon
	animation_player.queue(current_weapon.activate_anim)
	emit_signal("weapon_change", current_weapon.weapon_name)
	emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])
	
func exit(_next_weapon: String):
	#in order to change weapons - first call exit
	if _next_weapon != current_weapon.weapon_name:
		if animation_player.get_current_animation() != current_weapon.deactivate_anim:
			animation_player.play(current_weapon.deactivate_anim)
			next_weapon = _next_weapon

func change_weapon(_weapon_name: String):
	current_weapon = weapon_list[_weapon_name]
	next_weapon = ""
	enter()	


func _on_animation_player_animation_finished(anim_name):
	if anim_name == current_weapon.deactivate_anim:
		change_weapon(next_weapon)
		
	# auto fire
	if anim_name == current_weapon.shoot_anim && current_weapon.auto_fire:
		if Input.is_action_pressed("shoot"):
			shot()
		


func shot():
	if current_weapon.current_ammo !=0:
		if !animation_player.is_playing(): # enforce firerate set by animation/can't interupt an animation
			animation_player.play(current_weapon.shoot_anim)
			current_weapon.current_ammo -= 1
			emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])
			
			var camera_collision = get_camera_collision()
			
			match current_weapon.type:
				NULL: 
					print("Weapon type not choosen")
				HITSCAN:
					hit_scan_collision(camera_collision)
				PROJECTILE:
					launch_projectile(camera_collision)
			
	else:
		animation_player.play(current_weapon.ooa_anim) # clip is empty
	
func reload():
	if current_weapon.current_ammo == current_weapon.magazine:
		return
	elif !animation_player.is_playing():
		if current_weapon.reserve_ammo != 0:
			animation_player.play(current_weapon.reload_anim)
			var reload_amount = min(
				current_weapon.magazine - current_weapon.current_ammo, 
				current_weapon.magazine, 
				current_weapon.reserve_ammo
			)
			
			current_weapon.current_ammo += reload_amount
			current_weapon.reserve_ammo -= reload_amount 
			
			emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])
		else:
			animation_player.play(current_weapon.ooa_anim)
			
			
func get_camera_collision() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	var viewport = get_viewport().get_size()
	
	var ray_origin = camera.project_ray_origin(viewport/2)
	var ray_end = ray_origin + camera.project_ray_normal(viewport/2) * current_weapon.weapon_range
	
	var new_intersection = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	new_intersection.set_exclude(collision_exclusion)
	
	var intersection = get_world_3d().direct_space_state.intersect_ray(new_intersection)
	if not intersection.is_empty():
		var col_point = intersection.position
		return col_point
	else:
		return ray_end
	
	
func hit_scan_collision(collision_point):
	var bullet_direction  = (collision_point - bullet_point.get_global_transform().origin).normalized()
	var new_intersection = PhysicsRayQueryParameters3D.create(bullet_point.get_global_transform().origin, collision_point + bullet_direction*2)
	
	var bullet_collision = get_world_3d().direct_space_state.intersect_ray(new_intersection)
	
	if bullet_collision:
		var hit_indicator = debug_bullet.instantiate()
		var world = get_tree().get_root().get_child(0)
		world.add_child(hit_indicator)
		hit_indicator.global_translate(bullet_collision.position) 
		hit_scan_damage(bullet_collision.collider)
		
		
	
func hit_scan_damage(collider):
	if collider.is_in_group("Target") and collider.has_method("hit_succesful"):
		collider.hit_succesful(current_weapon.damage)
	
	
func launch_projectile(point: Vector3):
	var direction = (point - bullet_point.get_global_transform().origin).normalized()
	var projectile = current_weapon.projectile_to_load.instantiate()
	
	var projectile_rid = projectile.get_rid()
	collision_exclusion.push_back(projectile_rid)
	projectile.tree_exited.connect(remove_exclusion.bind(projectile_rid))
	
	bullet_point.add_child(projectile)
	projectile.damage = current_weapon.damage
	projectile.set_linear_velocity(direction * current_weapon.projectile_velocity)


func remove_exclusion(projectile_rid):
	collision_exclusion.erase(projectile_rid)
