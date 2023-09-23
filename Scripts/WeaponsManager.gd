extends Node3D

signal weapon_change
signal update_ammo
signal update_weapon_stack	

@onready var animation_player = $FPSRig/AnimationPlayer
@onready var bullet_point = $FPSRig/BulletPoint

var debug_bullet = preload("res://Scenes/bullet_debug.tscn")

var current_weapon = null
var weapon_stack = [] # array of weapons currently held by the player
#var weapon_indicator = 0
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
		var get_ref = weapon_stack.find(current_weapon.weapon_name)
		get_ref = min(get_ref + 1, weapon_stack.size() - 1)
		exit(weapon_stack[get_ref])
		
	if event.is_action_pressed("weapon_down"):
		var get_ref = weapon_stack.find(current_weapon.weapon_name)
		get_ref = max(get_ref - 1, 0)
		exit(weapon_stack[get_ref])
		
	if event.is_action_pressed("shoot"):
		shot()
	if event.is_action_pressed("reload"):
		reload()
	if event.is_action_pressed("drop_weapon"):
		drop_weapon(current_weapon.weapon_name)

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
		hit_scan_damage(bullet_collision.collider, bullet_direction, bullet_collision.position)
		
		
	
func hit_scan_damage(collider, direction, position):
	if collider.is_in_group("Target") and collider.has_method("hit_succesful"):
		collider.hit_succesful(current_weapon.damage, direction, position)
		
	
	
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
	

func _on_pick_up_detection_body_entered(body):
	if !body.pick_up_ready: return
	print(body.name)
	
	var weapon_in_stack = weapon_stack.find(body.weapon_name, 0)
	
	if weapon_in_stack == -1 && body.pick_up_type == "weapon": #pick up
		var get_ref = weapon_stack.find(current_weapon.weapon_name)
		
		weapon_stack.insert(get_ref, body.weapon_name)
		
		
		# zero out ammo in the resource
		weapon_list[body.weapon_name].current_ammo = body.current_ammo
		weapon_list[body.weapon_name].reserve_ammo = body.reserve_ammo
		
		emit_signal("update_weapon_stack", weapon_stack)
		exit(body.weapon_name)
		body.queue_free()
	else: #add ammo
		
		var remaining = add_ammo(body.weapon_name, body.current_ammo + body.reserve_ammo)
		if remaining == 0:
			body.queue_free()
		
		body.current_ammo = min(remaining, weapon_list[body.weapon_name].magazine)
		body.reserve_ammo = max(remaining - body.current_ammo, 0)
		
func drop_weapon(_name: String):
	if !weapon_list[_name].can_be_dropped || weapon_stack.size() == 1: return
	
	var weapon_ref = weapon_stack.find(_name, 0)
	
	if weapon_ref != -1:
		weapon_stack.pop_at(weapon_ref)
		emit_signal("update_weapon_stack", weapon_stack)
		
		var weapon_dropped = weapon_list[_name].weapon_drop.instantiate()
		weapon_dropped.current_ammo = weapon_list[_name].current_ammo
		weapon_dropped.reserve_ammo = weapon_list[_name].reserve_ammo
		
		weapon_dropped.set_global_transform(bullet_point.get_global_transform())
		var world = get_tree().get_root().get_child(0)
		world.add_child(weapon_dropped)
		
		var get_ref = weapon_stack.find(current_weapon.weapon_name)
		get_ref = max(get_ref - 1, 0)
		exit(weapon_stack[get_ref])


func add_ammo(_weapon_name: String, ammo: int) -> int:
	var _weapon = weapon_list[_weapon_name]
	
	var required = _weapon.max_ammo - _weapon.reserve_ammo
	var remaining = max(ammo - required, 0)
	
	_weapon.reserve_ammo += min(ammo, required)
	emit_signal("update_ammo", [current_weapon.current_ammo, current_weapon.reserve_ammo])
	return remaining
	
