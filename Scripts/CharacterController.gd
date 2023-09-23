extends CharacterBody3D

@onready var main_camera = $MainCamera

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

# camera bob
const BOB_FREQ = 2.0
const BOB_AMP = 0.08
var t_bob = 0.0


var camera_rotation = Vector2(0, 0)
var mouse_sensitivity = 0.001 # working in radients

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	if event.is_action_pressed("quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
	if event is InputEventMouseMotion:
		var mouse_event = event.relative * mouse_sensitivity
		camera_look(mouse_event)

func camera_look(movement: Vector2):
	camera_rotation += movement
	camera_rotation.y = clamp(camera_rotation.y, -1.5, 1.2)
	
	transform.basis = Basis()
	main_camera.transform.basis = Basis()
	
	rotate_object_local(Vector3.UP, -camera_rotation.x) # first rotate y
	main_camera.rotate_object_local(Vector3.RIGHT, -camera_rotation.y) # rotate x

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	# head bob
	t_bob += delta * velocity.length() * float(is_on_floor())
	main_camera.transform.origin = head_bob(t_bob)

	move_and_slide()


func head_bob(time) -> Vector3:
	var pos = Vector3.ZERO
	pos.y = sin(time * BOB_FREQ) * BOB_AMP + 1.5
	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
	return pos
