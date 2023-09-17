extends RigidBody3D


var health = 5

func hit_succesful(damage):
	health -= damage
	print("Target health: " + str(health))
	if health <= 0:
		queue_free()
