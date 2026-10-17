extends CharacterBody3D

# --- Settings ---
const SPEED: float = 5.0
const JUMP_STRENGTH: float = 4.5
const MOUSE_SENSITIVITY: float = 0.003
const MAX_HEALTH: int = 100
const FALL_LIMIT: float = -10.0
const STEP_HEIGHT: float = 0.5
const STEP_LOOKAHEAD: float = 0.15

# --- Egg settings ---
const THROW_SPEED: float = 15.0
const FIRE_INTERVAL: float = 0.8
const MAGAZINE_SIZE: int = 1
const START_RESERVE: int = 30
const AIM_RANGE: float = 100.0

# --- Resources ---
var egg_scene: PackedScene = preload("res://weapons/egg.tscn")

# --- State ---
var health: int = MAX_HEALTH
var loaded: int = MAGAZINE_SIZE
var reserve: int = START_RESERVE
var reload_timer: float = 0.0

# --- Node references ---
@onready var camera: Camera3D = $Camera3D
@onready var hand_egg: MeshInstance3D = $Camera3D/HandEgg
@onready var health_bar: ProgressBar = $CanvasLayer/ProgressBar
@onready var ammo_label: Label = $CanvasLayer/AmmoLabel


# --- Setup ---
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = STEP_HEIGHT
	health_bar.max_value = MAX_HEALTH
	health_bar.value = health
	_update_ammo_ui()


# --- Input ---
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_look(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click()


func _look(motion: Vector2) -> void:
	rotate_y(-motion.x * MOUSE_SENSITIVITY)
	camera.rotate_x(-motion.y * MOUSE_SENSITIVITY)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-89), deg_to_rad(89))


func _on_click() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		throw_egg()


# --- Movement ---
func _physics_process(delta: float) -> void:
	_apply_gravity(delta)
	_handle_jump()
	_handle_walk()
	_try_step_up()
	move_and_slide()
	_check_fall()
	_update_reload(delta)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


func _handle_jump() -> void:
	if Input.is_physical_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_STRENGTH


func _handle_walk() -> void:
	var input_dir := _get_input_direction()
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED


func _get_input_direction() -> Vector2:
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		dir.y += 1
	if Input.is_physical_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		dir.x += 1
	return dir


func _try_step_up() -> void:
	var flat_velocity := Vector3(velocity.x, 0, velocity.z)
	if not is_on_floor() or flat_velocity.is_zero_approx():
		return

	var motion := flat_velocity.normalized() * STEP_LOOKAHEAD
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, motion, hit):
		return
	if hit.get_normal().y > 0.7:
		return

	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, lift):
		return
	if test_move(global_transform.translated(lift), motion):
		return

	global_position += lift


func _check_fall() -> void:
	if global_position.y < FALL_LIMIT:
		die()


# --- Health ---
func take_damage(amount: int) -> void:
	health -= amount
	health_bar.value = health
	if health <= 0:
		die()


func die() -> void:
	print("You died!")
	get_tree().reload_current_scene()


# --- Eggs ---
func throw_egg() -> void:
	if loaded <= 0:
		return

	loaded -= 1
	_spawn_egg()
	if reserve > 0:
		reload_timer = FIRE_INTERVAL
	_update_ammo_ui()


func _spawn_egg() -> void:
	var egg: RigidBody3D = egg_scene.instantiate()
	get_tree().current_scene.add_child(egg)

	var start := _get_spawn_point()
	var offset := _get_aim_point() - start
	var direction := -camera.global_transform.basis.z
	if offset.length() > 0.1:
		direction = offset.normalized()

	egg.global_position = start
	egg.add_collision_exception_with(self)
	egg.linear_velocity = direction * THROW_SPEED


func _get_spawn_point() -> Vector3:
	var hand_position := hand_egg.global_position
	var hit := _raycast(camera.global_position, hand_position)
	if hit.is_empty():
		return hand_position
	return hit.position + hit.normal * 0.15


func _get_aim_point() -> Vector3:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * AIM_RANGE
	var hit := _raycast(from, to)
	if hit.is_empty():
		return to
	return hit.position


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)


# --- Ammo ---
func _update_reload(delta: float) -> void:
	if reload_timer <= 0.0:
		return

	reload_timer -= delta
	if reload_timer <= 0.0:
		reserve -= 1
		loaded += 1
		_update_ammo_ui()


func _update_ammo_ui() -> void:
	ammo_label.text = "%d / %d" % [loaded, reserve]
	hand_egg.visible = loaded > 0
