extends StaticBody3D

# --- Settings ---
const MAX_HEALTH: int = 60
const RESPAWN_DELAY: float = 3.0

# --- State ---
var health: int = MAX_HEALTH

# --- Node references ---
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var shape: CollisionShape3D = $CollisionShape3D


# --- Damage ---
func take_damage(amount: int, attacker = null) -> void:
	if health <= 0:
		return

	health -= amount
	if health <= 0:
		_defeat(attacker)


func _defeat(attacker) -> void:
	if attacker != null and attacker.has_method("add_score"):
		attacker.call("add_score", 1)

	_set_active(false)
	await get_tree().create_timer(RESPAWN_DELAY).timeout
	health = MAX_HEALTH
	_set_active(true)


func _set_active(active: bool) -> void:
	mesh.visible = active
	shape.set_deferred("disabled", not active)
