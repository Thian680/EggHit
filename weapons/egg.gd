extends RigidBody3D

# --- Settings ---
const DAMAGE: int = 20
const GRAVITY_SCALE: float = 1.0
const LIFETIME: float = 10.0
const SPLAT_TEXTURE: Texture2D = preload("res://weapons/splat.png")
const SPLAT_SIZE: float = 1.2
const SPLAT_OFFSET: float = 0.03
const SPLAT_LIFETIME: float = 8.0

# --- State ---
var broken: bool = false
var thrower: Node = null


# --- Setup ---
func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 1
	continuous_cd = true
	collision_layer = 2
	collision_mask = 1
	gravity_scale = GRAVITY_SCALE
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	get_tree().create_timer(LIFETIME).timeout.connect(queue_free)


# --- Impact ---
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if broken or state.get_contact_count() == 0:
		return
	broken = true

	var point := state.get_contact_collider_position(0)
	var normal := state.get_contact_local_normal(0)
	if normal.dot(global_position - point) < 0:
		normal = -normal

	_apply_damage(state.get_contact_collider_object(0))
	_splat.call_deferred(point, normal)


func _apply_damage(target: Object) -> void:
	if target == null or not target.has_method("take_damage"):
		return

	var attacker: Node = thrower if is_instance_valid(thrower) else null
	target.call_deferred("take_damage", DAMAGE, attacker)


# --- Splat ---
func _splat(point: Vector3, normal: Vector3) -> void:
	var splat := MeshInstance3D.new()
	splat.mesh = _build_quad()
	get_tree().current_scene.add_child(splat)
	splat.global_transform = Transform3D(_surface_basis(normal), point + normal * SPLAT_OFFSET)

	get_tree().create_timer(SPLAT_LIFETIME).timeout.connect(splat.queue_free)
	queue_free()


func _build_quad() -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(SPLAT_SIZE, SPLAT_SIZE)

	var material := StandardMaterial3D.new()
	material.albedo_texture = SPLAT_TEXTURE
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = material
	return quad


func _surface_basis(normal: Vector3) -> Basis:
	var ref := Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var x := ref.cross(normal).normalized()
	var y := normal.cross(x)
	return Basis(x, y, normal).rotated(normal, randf() * TAU)
