@tool
extends EditorScenePostImport

# --- Settings ---
const SKIP_NAMES: Array[String] = ["Icosphere_020", "Icosphere.020"]
const MIN_CROSS_LENGTH_SQUARED: float = 1.0e-10


# --- Entry point ---
func _post_import(scene: Node) -> Object:
	_add_collision(scene, scene)
	return scene


# --- Collision ---
func _add_collision(node: Node, root: Node) -> void:
	for child in node.get_children():
		_add_collision(child, root)

	var mesh_node := node as MeshInstance3D
	if mesh_node == null or mesh_node.mesh == null:
		return
	if _should_skip(mesh_node):
		return

	var faces := mesh_node.mesh.get_faces()
	var baked_faces := _transform_to_root(mesh_node, root) * faces
	if not _has_valid_triangle(baked_faces):
		print("No collision (no valid triangles): ", mesh_node.name)
		return

	var trimesh := ConcavePolygonShape3D.new()
	trimesh.set_faces(baked_faces)
	trimesh.backface_collision = true

	var shape := CollisionShape3D.new()
	shape.shape = trimesh

	var body := StaticBody3D.new()
	body.name = "Col_" + str(mesh_node.name)
	root.add_child(body, true)
	body.add_child(shape)
	body.owner = root
	shape.owner = root


# --- Helpers ---
func _transform_to_root(node: Node, root: Node) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current := node
	while current != null and current != root:
		var spatial := current as Node3D
		if spatial != null:
			result = spatial.transform * result
		current = current.get_parent()
	return result


func _has_valid_triangle(faces: PackedVector3Array) -> bool:
	for i in range(0, faces.size() - 2, 3):
		var cross := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
		if cross.length_squared() > MIN_CROSS_LENGTH_SQUARED:
			return true
	return false


func _should_skip(mesh_node: MeshInstance3D) -> bool:
	var mesh_name := str(mesh_node.name)
	for skip_name in SKIP_NAMES:
		if mesh_name.contains(skip_name):
			return true
	return false
