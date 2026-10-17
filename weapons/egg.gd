# This script goes on the Egg. It makes the egg break when it hits something.
extends RigidBody3D

# Stops the egg from breaking twice if it touches two things at once
var broken = false


func _ready():
	# "When this egg touches something, run the function called break_egg"
	body_entered.connect(break_egg)


func break_egg(_body):
	if broken:
		return
	broken = true

	# Make a flat yellow blob to look like a splat
	var splat = MeshInstance3D.new()
	var blob = SphereMesh.new()
	blob.radius = 0.3
	blob.height = 0.6
	splat.mesh = blob

	# Give the blob a yellow color
	var color = StandardMaterial3D.new()
	color.albedo_color = Color(1, 0.85, 0.2)
	splat.material_override = color

	# Squash it flat
	splat.scale = Vector3(1, 0.3, 1)

	# Put the splat in the world, right where the egg was
	get_tree().current_scene.add_child(splat)
	splat.global_position = global_position

	# Remove the splat after 5 seconds so they don't pile up
	get_tree().create_timer(5.0).timeout.connect(splat.queue_free)

	# Remove the egg itself
	queue_free()
