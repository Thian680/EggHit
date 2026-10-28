extends CharacterBody3D

signal died(player)

# --- Movement settings ---
const SPEED: float = 5.0
const SPRINT_MULTIPLIER: float = 1.6
const AIM_SPEED_MULTIPLIER: float = 0.6
const GROUND_ACCEL: float = 8.0
const FRICTION: float = 6.0
const STOP_SPEED: float = 1.5
const JUMP_STRENGTH: float = 4.5
const MAX_HEALTH: int = 100
const FALL_LIMIT: float = -10.0

# --- Bunny hop settings ---
const AUTO_BHOP: bool = true
const JUMP_BUFFER: float = 0.12
const AIR_ACCEL: float = 10.0
const AIR_CAP: float = 1.5
const MAX_SPEED: float = 20.0

# --- Stair settings ---
const STEP_HEIGHT: float = 0.5
const STEP_LOOKAHEAD: float = 0.15
const MIN_STEP: float = 0.04
const STEP_SMOOTH_MIN: float = 0.06
const STEP_SMOOTH_RATE: float = 12.0

# --- Camera settings ---
const MOUSE_SENSITIVITY: float = 0.003
const AIM_SENSITIVITY_SCALE: float = 0.6
const PITCH_MIN: float = -60.0
const PITCH_MAX: float = 40.0
const NORMAL_FOV: float = 75.0
const AIM_FOV: float = 55.0
const FOV_PER_SPEED: float = 1.5
const MAX_FOV_BOOST: float = 25.0
const FOV_SPEED: float = 8.0
const ARM_LENGTH: float = 2.6
const AIM_ARM_LENGTH: float = 1.7
const ARM_SPEED: float = 10.0

# --- Body settings ---
const TURN_SPEED: float = 12.0
const AIM_FACING_TIME: float = 0.8
const ATTACK_ANIM_SPEED: float = 1.7
const STATIC_ARMS_IN_RUN: bool = true

# --- Hand egg settings ---
const HAND_BONE_NAMES: Array[String] = ["hand.R.002", "hand_R_002"]
const GLOVE_CENTER: Vector3 = Vector3(-0.849, 0.487, 0.0)
const HAND_EGG_OFFSET: Vector3 = Vector3.ZERO
const HAND_EGG_SCALE: Vector3 = Vector3(1.0, 1.3, 1.0)
const FALLBACK_BONE_OFFSET: Vector3 = Vector3(0.02, 0.9, -0.05)

# --- Egg settings ---
const THROW_SPEED: float = 15.0
const FIRE_INTERVAL: float = 0.8
const THROW_RELEASE_DELAY: float = 0.28
const MAGAZINE_SIZE: int = 1
const START_RESERVE: int = 30
const AIM_RANGE: float = 100.0
const MIN_AIM_DISTANCE: float = 1.0
const MAX_ARC_DISTANCE: float = 40.0
const DEBUG_AIM: bool = true

# --- Resources ---
var egg_scene: PackedScene = preload("res://weapons/egg.tscn")

# --- State ---
var alive: bool = true
var aiming: bool = false
var sprinting: bool = false
var attacking: bool = false
var health: int = MAX_HEALTH
var score: int = 0
var loaded: int = MAGAZINE_SIZE
var reserve: int = START_RESERVE
var reload_timer: float = 0.0
var throw_timer: float = 0.0
var aim_facing_timer: float = 0.0

# --- Movement state ---
var wish_direction: Vector3 = Vector3.ZERO
var wish_speed: float = SPEED
var jump_buffer: float = 0.0
var jump_was_down: bool = false
var step_offset: float = 0.0
var pivot_base_y: float = 0.0
var body_base_y: float = 0.0

# --- Hand egg tracking ---
var skeleton: Skeleton3D
var skinned_mesh: MeshInstance3D
var hand_bone: int = -1
var hand_bind: Transform3D = Transform3D.IDENTITY
var has_bind: bool = false

# --- Node references ---
@onready var camera_pivot: Node3D = $CameraPivot
@onready var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var body: Node3D = $Body
@onready var anim: AnimationPlayer = body.find_child("AnimationPlayer", true, false)
@onready var hand_egg: Node3D = body.find_child("HandEgg", true, false)
@onready var health_bar: ProgressBar = $CanvasLayer/ProgressBar
@onready var ammo_label: Label = $CanvasLayer/AmmoLabel
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var message_label: Label = $CanvasLayer/MessageLabel
@onready var speed_label: Label = get_node_or_null("CanvasLayer/SpeedLabel")


# --- Setup ---
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	floor_snap_length = STEP_HEIGHT
	spring_arm.add_excluded_object(get_rid())
	pivot_base_y = camera_pivot.position.y
	body_base_y = body.position.y
	health_bar.max_value = MAX_HEALTH
	health_bar.value = health
	message_label.hide()
	_setup_body()
	_setup_hand_egg()
	_update_ammo_ui()
	_update_score_ui()


# --- Input ---
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_look(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_click()


func _look(motion: Vector2) -> void:
	var sensitivity := MOUSE_SENSITIVITY * (AIM_SENSITIVITY_SCALE if aiming else 1.0)
	camera_pivot.rotation.y -= motion.x * sensitivity
	var pitch := camera_pivot.rotation.x - motion.y * sensitivity
	camera_pivot.rotation.x = clamp(pitch, deg_to_rad(PITCH_MIN), deg_to_rad(PITCH_MAX))


func _on_click() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		throw_egg()


# --- Camera ---
func _process(delta: float) -> void:
	aiming = alive \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
		and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	_update_camera(delta)
	if speed_label != null:
		speed_label.text = "Speed: %.1f" % _get_horizontal_speed()


func _update_camera(delta: float) -> void:
	var speed_boost := clampf((_get_horizontal_speed() - SPEED) * FOV_PER_SPEED, 0.0, MAX_FOV_BOOST)
	var target_fov := AIM_FOV if aiming else NORMAL_FOV + speed_boost
	camera.fov = lerpf(camera.fov, target_fov, FOV_SPEED * delta)

	var target_length := AIM_ARM_LENGTH if aiming else ARM_LENGTH
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_length, ARM_SPEED * delta)


func _get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


# --- Movement ---
func _physics_process(delta: float) -> void:
	if not alive:
		return

	var previous_y := global_position.y
	var was_on_floor := is_on_floor()

	_move_player(delta)
	_try_step_up()
	move_and_slide()
	_smooth_vertical_snap(previous_y, was_on_floor, delta)

	_update_body_facing(delta)
	_update_animation()
	_check_fall()
	_update_reload(delta)
	_update_throw(delta)


func _move_player(delta: float) -> void:
	_update_wish()
	_update_jump_buffer(delta)

	if is_on_floor():
		if _wants_jump():
			velocity.y = JUMP_STRENGTH
			jump_buffer = 0.0
			_air_move(delta)
		else:
			_ground_move(delta)
	else:
		velocity += get_gravity() * delta
		_air_move(delta)


func _update_wish() -> void:
	var input_dir := _get_input_direction()
	sprinting = Input.is_physical_key_pressed(KEY_SHIFT) and input_dir != Vector2.ZERO and not aiming

	wish_speed = SPEED
	if sprinting:
		wish_speed *= SPRINT_MULTIPLIER
	elif aiming:
		wish_speed *= AIM_SPEED_MULTIPLIER

	var yaw_basis := Basis(Vector3.UP, camera_pivot.rotation.y)
	wish_direction = (yaw_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()


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


func _update_jump_buffer(delta: float) -> void:
	var down := Input.is_physical_key_pressed(KEY_SPACE)
	if down and not jump_was_down:
		jump_buffer = JUMP_BUFFER
	jump_was_down = down
	jump_buffer = maxf(jump_buffer - delta, 0.0)


func _wants_jump() -> bool:
	return jump_buffer > 0.0 or (AUTO_BHOP and jump_was_down)


func _ground_move(delta: float) -> void:
	_apply_friction(delta)
	_accelerate(wish_direction, wish_speed, GROUND_ACCEL, delta)


func _apply_friction(delta: float) -> void:
	var speed := _get_horizontal_speed()
	if speed < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var control := maxf(speed, STOP_SPEED)
	var new_speed := maxf(speed - control * FRICTION * delta, 0.0)
	velocity.x *= new_speed / speed
	velocity.z *= new_speed / speed


func _accelerate(direction: Vector3, target_speed: float, accel: float, delta: float) -> void:
	if direction == Vector3.ZERO:
		return

	var current_speed := Vector3(velocity.x, 0.0, velocity.z).dot(direction)
	var add_speed := target_speed - current_speed
	if add_speed <= 0.0:
		return

	var accel_speed := minf(accel * target_speed * delta, add_speed)
	velocity.x += direction.x * accel_speed
	velocity.z += direction.z * accel_speed


func _air_move(delta: float) -> void:
	if wish_direction != Vector3.ZERO:
		var capped_speed := minf(wish_speed, AIR_CAP)
		var current_speed := Vector3(velocity.x, 0.0, velocity.z).dot(wish_direction)
		var add_speed := capped_speed - current_speed
		if add_speed > 0.0:
			var accel_speed := minf(AIR_ACCEL * SPEED * delta, add_speed)
			velocity.x += wish_direction.x * accel_speed
			velocity.z += wish_direction.z * accel_speed
	_limit_speed()


func _limit_speed() -> void:
	var speed := _get_horizontal_speed()
	if speed > MAX_SPEED:
		velocity.x *= MAX_SPEED / speed
		velocity.z *= MAX_SPEED / speed


# --- Stairs ---
func _try_step_up() -> void:
	if not is_on_floor() or wish_direction == Vector3.ZERO:
		return

	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if flat_velocity.length() < 0.1:
		return

	var forward := flat_velocity.normalized() * maxf(flat_velocity.length() * get_physics_process_delta_time(), STEP_LOOKAHEAD)
	var hit := KinematicCollision3D.new()
	if not test_move(global_transform, forward, hit):
		return
	if hit.get_normal().y > 0.7:
		return

	var lift := Vector3.UP * STEP_HEIGHT
	if test_move(global_transform, lift):
		return
	var raised := global_transform.translated(lift)
	if test_move(raised, forward):
		return

	var down_hit := KinematicCollision3D.new()
	var down := Vector3.DOWN * (STEP_HEIGHT + 0.05)
	if not test_move(raised.translated(forward), down, down_hit):
		return
	if down_hit.get_normal().y < 0.7:
		return

	var rise := STEP_HEIGHT - down_hit.get_travel().length()
	if rise < MIN_STEP:
		return

	global_position.y += rise


func _smooth_vertical_snap(previous_y: float, was_on_floor: bool, delta: float) -> void:
	var change := global_position.y - previous_y
	var snapped_to_ground := was_on_floor and is_on_floor()
	if snapped_to_ground and absf(change) >= STEP_SMOOTH_MIN and absf(change) <= STEP_HEIGHT + 0.1:
		step_offset = clampf(step_offset - change, -STEP_HEIGHT, STEP_HEIGHT)

	step_offset = lerpf(step_offset, 0.0, minf(STEP_SMOOTH_RATE * delta, 1.0))
	camera_pivot.position.y = pivot_base_y + step_offset
	body.position.y = body_base_y + step_offset


func _check_fall() -> void:
	if global_position.y < FALL_LIMIT:
		die()


# --- Health and score ---
func take_damage(amount: int, attacker = null) -> void:
	if not alive:
		return

	health -= amount
	health_bar.value = health
	if health <= 0:
		die(attacker)


func die(attacker = null) -> void:
	if not alive:
		return

	alive = false
	aiming = false
	sprinting = false
	attacking = false
	throw_timer = 0.0
	message_label.text = "You died"
	message_label.show()
	anim.play("die", 0.1)

	if attacker != null and attacker != self and attacker.has_method("add_score"):
		attacker.call("add_score", 1)

	died.emit(self)


func respawn(spawn_position: Vector3) -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	loaded = MAGAZINE_SIZE
	reserve = START_RESERVE
	reload_timer = 0.0
	throw_timer = 0.0
	aim_facing_timer = 0.0
	jump_buffer = 0.0
	step_offset = 0.0
	alive = true
	anim.play("idle", 0.1)

	health_bar.value = health
	message_label.hide()
	_update_ammo_ui()


func add_score(amount: int) -> void:
	score += amount
	_update_score_ui()


func _update_score_ui() -> void:
	score_label.text = "Eliminations: %d" % score


# --- Body and animation ---
func _setup_body() -> void:
	for anim_name in ["idle", "run"]:
		anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	if STATIC_ARMS_IN_RUN:
		_hold_arms_still_in_run()
	anim.animation_finished.connect(_on_animation_finished)
	anim.play("idle")


func _hold_arms_still_in_run() -> void:
	var run := anim.get_animation("run")
	var idle := anim.get_animation("idle")

	for i in range(run.get_track_count() - 1, -1, -1):
		if _is_arm_track(run.track_get_path(i)):
			run.remove_track(i)

	for i in idle.get_track_count():
		if not _is_arm_track(idle.track_get_path(i)):
			continue
		idle.copy_track(i, run)
		var new_track := run.get_track_count() - 1
		for key in range(run.track_get_key_count(new_track) - 1, 0, -1):
			run.track_remove_key(new_track, key)


func _is_arm_track(path: NodePath) -> bool:
	var text := str(path).to_lower()
	return text.contains("hand") or text.contains("finger")


func _update_body_facing(delta: float) -> void:
	aim_facing_timer = maxf(aim_facing_timer - delta, 0.0)

	var travel := Vector3(velocity.x, 0.0, velocity.z)
	var target_yaw := 0.0
	if aiming or aim_facing_timer > 0.0:
		target_yaw = camera_pivot.rotation.y
	elif travel.length() > 0.5:
		target_yaw = atan2(-travel.x, -travel.z)
	else:
		return

	body.rotation.y = lerp_angle(body.rotation.y, target_yaw + PI, minf(TURN_SPEED * delta, 1.0))


func _update_animation() -> void:
	if attacking:
		return

	var horizontal_speed := _get_horizontal_speed()
	var target := "run" if horizontal_speed > 0.5 else "idle"
	anim.speed_scale = clampf(horizontal_speed / SPEED, 0.7, 2.0) if target == "run" else 1.0
	if anim.current_animation != target:
		anim.play(target, 0.15)


func _play_attack() -> void:
	attacking = true
	anim.speed_scale = 1.0
	anim.play("attack", 0.1, ATTACK_ANIM_SPEED)


func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == "attack":
		attacking = false


# --- Hand egg ---
func _setup_hand_egg() -> void:
	skeleton = body.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		push_warning("Player: no Skeleton3D found under Body.")
		return

	hand_bone = _find_bone(HAND_BONE_NAMES)
	if hand_bone == -1:
		push_warning("Player: hand bone not found. Bones are: " + ", ".join(_get_bone_names()))
		return

	var meshes := skeleton.find_children("*", "MeshInstance3D", true, false)
	if not meshes.is_empty():
		skinned_mesh = meshes[0] as MeshInstance3D
	_find_hand_bind()

	hand_egg.top_level = true
	skeleton.skeleton_updated.connect(_update_hand_egg)
	_update_hand_egg()


func _find_bone(names: Array[String]) -> int:
	for bone_name in names:
		var index := skeleton.find_bone(bone_name)
		if index != -1:
			return index
	return -1


func _get_bone_names() -> PackedStringArray:
	var names := PackedStringArray()
	for i in skeleton.get_bone_count():
		names.append(skeleton.get_bone_name(i))
	return names


func _find_hand_bind() -> void:
	if skinned_mesh == null or skinned_mesh.skin == null:
		return

	var skin := skinned_mesh.skin
	var hand_name := skeleton.get_bone_name(hand_bone)
	for i in skin.get_bind_count():
		if skin.get_bind_bone(i) == hand_bone or skin.get_bind_name(i) == hand_name:
			hand_bind = skin.get_bind_pose(i)
			has_bind = true
			return


func _update_hand_egg() -> void:
	var bone_pose := skeleton.get_bone_global_pose(hand_bone)
	var reference := skeleton.global_transform
	var local_position := bone_pose * FALLBACK_BONE_OFFSET
	if has_bind:
		reference = skinned_mesh.global_transform
		local_position = (bone_pose * hand_bind) * (GLOVE_CENTER + HAND_EGG_OFFSET)

	var upright := body.global_transform.basis.orthonormalized()
	var scaled_basis := Basis(
		upright.x * HAND_EGG_SCALE.x,
		upright.y * HAND_EGG_SCALE.y,
		upright.z * HAND_EGG_SCALE.z
	)
	hand_egg.global_transform = Transform3D(scaled_basis, reference * local_position)


# --- Eggs ---
func throw_egg() -> void:
	if not alive or loaded <= 0 or throw_timer > 0.0:
		return

	throw_timer = THROW_RELEASE_DELAY
	aim_facing_timer = AIM_FACING_TIME
	_play_attack()


func _update_throw(delta: float) -> void:
	if throw_timer <= 0.0:
		return

	throw_timer -= delta
	if throw_timer <= 0.0:
		_release_egg()


func _release_egg() -> void:
	loaded -= 1
	_spawn_egg()
	if reserve > 0:
		reload_timer = FIRE_INTERVAL
	_update_ammo_ui()


func _spawn_egg() -> void:
	var egg: RigidBody3D = egg_scene.instantiate()
	get_tree().current_scene.add_child(egg)

	var start := _get_spawn_point()
	egg.global_position = start
	egg.add_collision_exception_with(self)
	egg.set("thrower", self)
	egg.linear_velocity = _get_launch_velocity(start, THROW_SPEED, egg.gravity_scale)

	if DEBUG_AIM:
		_show_debug_marker(_get_aim_point())


func _get_launch_velocity(start: Vector3, speed: float, gravity_scale: float) -> Vector3:
	var forward := -camera.global_transform.basis.z
	var offset := _get_aim_point() - start
	if offset.length() < MIN_AIM_DISTANCE:
		return forward * speed

	var to_target := offset.normalized() * minf(offset.length(), MAX_ARC_DISTANCE)
	var flight_time := to_target.length() / speed
	return to_target / flight_time - 0.5 * get_gravity() * gravity_scale * flight_time


func _get_spawn_point() -> Vector3:
	var hand_position := hand_egg.global_position
	var hit := _raycast(global_position, hand_position)
	if hit.is_empty():
		return hand_position
	return hit.position + hit.normal * 0.15


func _get_aim_point() -> Vector3:
	var forward := -camera.global_transform.basis.z
	var from := camera.global_position + forward * camera.global_position.distance_to(global_position)
	var to := from + forward * AIM_RANGE
	var hit := _raycast(from, to)
	if hit.is_empty():
		return to
	return hit.position


func _raycast(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_ray(query)


func _show_debug_marker(point: Vector3) -> void:
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.RED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = material
	marker.mesh = sphere
	get_tree().current_scene.add_child(marker)
	marker.global_position = point
	get_tree().create_timer(2.0).timeout.connect(marker.queue_free)


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
