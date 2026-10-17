# This script goes on the Player node. It makes the player move, look, and jump.
extends CharacterBody3D

# --- Settings you can tweak ---
const SPEED = 5.0               # How fast the player walks
const JUMP_STRENGTH = 4.5       # How high the player jumps
const MOUSE_SENSITIVITY = 0.003 # How fast the camera turns with the mouse

const MAX_HEALTH = 100          # The most health the player can have
var health = MAX_HEALTH         # The player's current health

const THROW_SPEED = 15.0                      # How fast the egg flies
var egg_scene = preload("res://weapons/egg.tscn")     # Loads the egg we made

# A shortcut to the health bar we just made
@onready var health_bar = $CanvasLayer/ProgressBar

# A shortcut to the Camera3D we added under the Player
@onready var camera = $Camera3D


# Runs once when the game starts
func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Set up the health bar so it starts full
	health_bar.max_value = MAX_HEALTH
	health_bar.value = health


# Runs every time the player does something (moves the mouse, presses a key)
func _input(event):
	# If the mouse moved, turn the view
	if event is InputEventMouseMotion:
		# Mouse left/right: turn the whole body
		rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		# Mouse up/down: tilt only the camera (like nodding your head)
		camera.rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		# Stop the camera from flipping upside down
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))

	# Pressing Escape gives the mouse cursor back
	if event is InputEventKey and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Left mouse click throws an egg
		# Left mouse click: get back into the game, or throw an egg
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # Re-lock the mouse to the game
		else:
			throw_egg()                                    # Mouse is already locked, so throw


# Runs many times per second; this is where movement happens
func _physics_process(delta):
	# Gravity: if we're in the air, pull downward
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump: only allowed while standing on the ground
	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_STRENGTH

	# Work out which direction the player wants to walk (W, A, S, D)
	var input_dir = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input_dir.y -= 1   # forward
	if Input.is_physical_key_pressed(KEY_S):
		input_dir.y += 1   # backward
	if Input.is_physical_key_pressed(KEY_A):
		input_dir.x -= 1   # left
	if Input.is_physical_key_pressed(KEY_D):
		input_dir.x += 1   # right

	# Convert that into a direction relative to where the player is facing
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Apply the walking speed (or stop if no key is pressed)
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	# Actually move the player and handle bumping into walls/floor
	move_and_slide()
	
		# If the player has fallen far below the map, they die
		# If the player falls off the map, they die
	if position.y < -10:
		die()

# Call this whenever the player gets hurt, e.g. take_damage(10)
func take_damage(amount):
	health -= amount           # Lower the health
	health_bar.value = health  # Update the bar on screen
	if health <= 0:            # No health left?
		die()


# What happens when the player dies
func die():
	print("You died!")
	get_tree().reload_current_scene()  # Restart the level
	
# Creates an egg and launches it forward from the camera
func throw_egg():
	# Make a new copy of the egg and add it to the world
	var egg = egg_scene.instantiate()
	get_tree().current_scene.add_child(egg)

	# The camera's "forward" direction (Godot uses -Z as forward)
	var forward = -camera.global_transform.basis.z

	# Start the egg a little in front of the camera
	egg.global_position = camera.global_position + forward * 0.8

	# Stop the egg from colliding with the player who threw it
	egg.add_collision_exception_with(self)

	# Launch it
	egg.linear_velocity = forward * THROW_SPEED
