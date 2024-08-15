extends CharacterBody3D

signal health_changed(health_value)

@onready var camera = $Camera3D
@onready var weapon_animation_player = $AnimationPlayerWeapon
@onready var muzzle_flash = $Camera3D/Weapon/pistol/MuzzleFlash
@onready var raycast = $Camera3D/RayCast3D


const SPEED = 8.0
const JUMP_VELOCITY = 7

const mouse_multiplier = 0.005

var health = 3

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# lock the mouse
func _ready():
	
	# check for multiplayer authority to only control our own player
	if not is_multiplayer_authority(): 
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# ensure the camera is current for each player
	camera.current = true
	
	# set the multiplayer authority immediately to let us distinguish an individual player across all clients and server
func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _unhandled_input(event):
	# check for multiplayer authority to only control our own player
	if not is_multiplayer_authority(): 
		return
		
	# handle mouse motion for player
	if event is InputEventMouseMotion:
		# rotate horizontally by mouse x-movement
		rotate_y(-event.relative.x * mouse_multiplier)
		# rotate camera vertically by mouse y-movement
		# also clamp vertical headlook
		camera.rotate_x(-event.relative.y * mouse_multiplier)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
		
		
	# handle fire action
	if Input.is_action_just_pressed("fire") and weapon_animation_player.current_animation != "shoot":
		# format to call a RPC function
		play_shoot_effects.rpc()
		
		# fire raycast and check for target player
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			# to only call receive_damage on the player we've shot, we use rpc_id to only send it to that player ID
			hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

# we want this function to be both called remotely and locally (so muzzle flash etc. is visible server-side)
# so we define it as a RPC call but with call_local as well
@rpc("call_local") 
func play_shoot_effects():
	# stop the current animation just in case
	weapon_animation_player.stop()
	# play the shooting animation
	weapon_animation_player.play("shoot")
	# muzzle flash client
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	
# a RPC function that we don't want to execute locally - we only want to send it to the peer we've shot
@rpc("any_peer")
func receive_damage():
	health -= 1
	health_changed.emit(health)
	if (health <= 0):
		die()

# respawn
func die():
	health = 3
	health_changed.emit(health)
	# reset position
	position = Vector3.ZERO
	
	
func _physics_process(delta):
	# check for multiplayer authority to only control our own player
	if not is_multiplayer_authority(): 
		return
		
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("left", "right", "up", "down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
		
	# ensure shooting isn't overriden
	if weapon_animation_player.current_animation == "shoot":
		pass
	# weapon animations for client
	elif input_dir != Vector2.ZERO and is_on_floor():
		weapon_animation_player.play("Walking")
	else:
		weapon_animation_player.play("PistolIdle")
	
	move_and_slide()


func _on_animation_player_weapon_animation_finished(anim_name):
	# if the shooting animation's finished
	if anim_name == "shoot":
		# make sure it plays the PistolIdle animation next - particularly for multiplayer
		weapon_animation_player.play("PistolIdle")
