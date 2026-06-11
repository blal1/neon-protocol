@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Physics body setup: RigidBody, CharacterBody, AnimatableBody, Area nodes

func get_commands() -> Dictionary:
	return {
		"setup_rigid_body_2d":       _setup_rigid_body_2d,
		"setup_rigid_body_3d":       _setup_rigid_body_3d,
		"setup_character_body_2d":   _setup_character_body_2d,
		"setup_character_body_3d":   _setup_character_body_3d,
		"setup_animatable_body_2d":  _setup_animatable_body_2d,
		"setup_animatable_body_3d":  _setup_animatable_body_3d,
		"setup_area_2d":             _setup_area_2d,
		"setup_area_3d":             _setup_area_3d,
		"setup_physical_bones":      _setup_physical_bones,
	}

func _v2(p: Dictionary, k: String, d: Vector2) -> Vector2:
	if not p.has(k): return d
	var v = p[k]
	if v is Dictionary: return Vector2(float(v.get("x", d.x)), float(v.get("y", d.y)))
	if v is Array and v.size() >= 2: return Vector2(float(v[0]), float(v[1]))
	return d

func _v3(p: Dictionary, k: String, d: Vector3) -> Vector3:
	if not p.has(k): return d
	var v = p[k]
	if v is Dictionary: return Vector3(float(v.get("x", d.x)), float(v.get("y", d.y)), float(v.get("z", d.z)))
	if v is Array and v.size() >= 3: return Vector3(float(v[0]), float(v[1]), float(v[2]))
	return d

func _pr(params: Dictionary) -> Array:
	var root := get_edited_root()
	if root == null: return [null, null, error_no_scene()]
	var pp: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(pp)
	if parent == null: return [null, null, error_not_found("Parent node not found")]
	return [parent, root, null]

func _add(node: Node, parent: Node, root: Node, label: String) -> void:
	var ur := get_undo_redo()
	ur.create_action(label)
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

func _add_col_shape_2d(parent: Node, root: Node, shape_type: String, params: Dictionary) -> void:
	var cs := CollisionShape2D.new()
	cs.name = "CollisionShape2D"
	match shape_type:
		"capsule":
			var cap := CapsuleShape2D.new()
			cap.radius = float(params.get("radius", 16.0))
			cap.height = float(params.get("height", 48.0))
			cs.shape = cap
		"rect":
			var rs := RectangleShape2D.new()
			rs.size = _v2(params, "size", Vector2(32, 32))
			cs.shape = rs
		_:
			var circ := CircleShape2D.new()
			circ.radius = float(params.get("radius", 16.0))
			cs.shape = circ
	parent.add_child(cs)
	cs.owner = root

func _add_col_shape_3d(parent: Node, root: Node, shape_type: String, params: Dictionary) -> void:
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	match shape_type:
		"box":
			var bs := BoxShape3D.new()
			bs.size = _v3(params, "size", Vector3(1, 1, 1))
			cs.shape = bs
		"capsule":
			var cap := CapsuleShape3D.new()
			cap.radius = float(params.get("radius", 0.5))
			cap.height = float(params.get("height", 2.0))
			cs.shape = cap
		_:
			var ss := SphereShape3D.new()
			ss.radius = float(params.get("radius", 0.5))
			cs.shape = ss
	parent.add_child(cs)
	cs.owner = root

func _setup_rigid_body_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var rb := RigidBody2D.new()
	rb.name = optional_string(params, "name", "RigidBody2D")
	rb.mass = float(params.get("mass", 1.0))
	rb.gravity_scale = float(params.get("gravity_scale", 1.0))
	rb.linear_damp = float(params.get("linear_damp", 0.0))
	rb.angular_damp = float(params.get("angular_damp", 0.0))
	rb.can_sleep = optional_bool(params, "can_sleep", true)
	rb.lock_rotation = optional_bool(params, "lock_rotation", false)
	var freeze_mode_str: String = optional_string(params, "freeze_mode", "")
	if freeze_mode_str == "static":
		rb.freeze_mode = RigidBody2D.FREEZE_MODE_STATIC
		rb.freeze = true
	elif freeze_mode_str == "kinematic":
		rb.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		rb.freeze = true
	rb.position = _v2(params, "position", Vector2.ZERO)
	_add(rb, parent, root, "MCP: Add RigidBody2D")
	if optional_bool(params, "add_collision_shape", true):
		_add_col_shape_2d(rb, root, optional_string(params, "shape_type", "circle"), params)
	return success({"node_path": str(root.get_path_to(rb)), "mass": rb.mass})

func _setup_rigid_body_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var rb := RigidBody3D.new()
	rb.name = optional_string(params, "name", "RigidBody3D")
	rb.mass = float(params.get("mass", 1.0))
	rb.gravity_scale = float(params.get("gravity_scale", 1.0))
	rb.linear_damp = float(params.get("linear_damp", 0.0))
	rb.angular_damp = float(params.get("angular_damp", 0.0))
	rb.can_sleep = optional_bool(params, "can_sleep", true)
	rb.lock_rotation_x = optional_bool(params, "lock_rotation_x", false)
	rb.lock_rotation_y = optional_bool(params, "lock_rotation_y", false)
	rb.lock_rotation_z = optional_bool(params, "lock_rotation_z", false)
	var freeze_str: String = optional_string(params, "freeze_mode", "")
	if freeze_str == "static":
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		rb.freeze = true
	elif freeze_str == "kinematic":
		rb.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		rb.freeze = true
	rb.position = _v3(params, "position", Vector3.ZERO)
	_add(rb, parent, root, "MCP: Add RigidBody3D")
	if optional_bool(params, "add_collision_shape", true):
		_add_col_shape_3d(rb, root, optional_string(params, "shape_type", "sphere"), params)
	return success({"node_path": str(root.get_path_to(rb)), "mass": rb.mass})

func _setup_character_body_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var cb := CharacterBody2D.new()
	cb.name = optional_string(params, "name", "CharacterBody2D")
	var mode_str: String = optional_string(params, "motion_mode", "grounded")
	cb.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED if mode_str == "grounded" else CharacterBody2D.MOTION_MODE_FLOATING
	cb.up_direction = _v2(params, "up_direction", Vector2.UP)
	cb.floor_stop_on_slope = optional_bool(params, "floor_stop_on_slope", false)
	cb.floor_max_angle = deg_to_rad(float(params.get("floor_max_angle_deg", 45.0)))
	cb.position = _v2(params, "position", Vector2.ZERO)
	_add(cb, parent, root, "MCP: Add CharacterBody2D")
	if optional_bool(params, "add_collision_shape", true):
		_add_col_shape_2d(cb, root, optional_string(params, "shape_type", "capsule"), params)
	return success({"node_path": str(root.get_path_to(cb)), "motion_mode": mode_str})

func _setup_character_body_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var cb := CharacterBody3D.new()
	cb.name = optional_string(params, "name", "CharacterBody3D")
	cb.up_direction = _v3(params, "up_direction", Vector3.UP)
	cb.floor_stop_on_slope = optional_bool(params, "floor_stop_on_slope", false)
	cb.floor_max_angle = deg_to_rad(float(params.get("floor_max_angle_deg", 45.0)))
	cb.position = _v3(params, "position", Vector3.ZERO)
	_add(cb, parent, root, "MCP: Add CharacterBody3D")
	if optional_bool(params, "add_collision_shape", true):
		_add_col_shape_3d(cb, root, optional_string(params, "shape_type", "capsule"), params)
	return success({"node_path": str(root.get_path_to(cb))})

func _setup_animatable_body_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var ab := AnimatableBody2D.new()
	ab.name = optional_string(params, "name", "AnimatableBody2D")
	ab.sync_to_physics = optional_bool(params, "sync_to_physics", true)
	ab.position = _v2(params, "position", Vector2.ZERO)
	_add(ab, parent, root, "MCP: Add AnimatableBody2D")
	if optional_bool(params, "add_collision_shape", true):
		_add_col_shape_2d(ab, root, optional_string(params, "shape_type", "rect"), params)
	return success({"node_path": str(root.get_path_to(ab))})

func _setup_animatable_body_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var ab := AnimatableBody3D.new()
	ab.name = optional_string(params, "name", "AnimatableBody3D")
	ab.sync_to_physics = optional_bool(params, "sync_to_physics", true)
	ab.position = _v3(params, "position", Vector3.ZERO)
	_add(ab, parent, root, "MCP: Add AnimatableBody3D")
	if optional_bool(params, "add_collision_shape", true):
		_add_col_shape_3d(ab, root, optional_string(params, "shape_type", "box"), params)
	return success({"node_path": str(root.get_path_to(ab))})

func _setup_area_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var area := Area2D.new()
	area.name = optional_string(params, "name", "Area2D")
	area.monitoring = optional_bool(params, "monitoring", true)
	area.monitorable = optional_bool(params, "monitorable", true)
	area.collision_layer = optional_int(params, "collision_layer", 1)
	area.collision_mask = optional_int(params, "collision_mask", 1)
	area.gravity = float(params.get("gravity", 980.0))
	area.gravity_point = optional_bool(params, "gravity_point", false)
	area.position = _v2(params, "position", Vector2.ZERO)
	_add(area, parent, root, "MCP: Add Area2D")
	if optional_bool(params, "add_collision_shape", true):
		_add_col_shape_2d(area, root, optional_string(params, "shape_type", "rect"), params)
	return success({"node_path": str(root.get_path_to(area))})

func _setup_area_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var area := Area3D.new()
	area.name = optional_string(params, "name", "Area3D")
	area.monitoring = optional_bool(params, "monitoring", true)
	area.monitorable = optional_bool(params, "monitorable", true)
	area.collision_layer = optional_int(params, "collision_layer", 1)
	area.collision_mask = optional_int(params, "collision_mask", 1)
	area.gravity = float(params.get("gravity", 9.8))
	area.priority = optional_int(params, "priority", 0)
	area.position = _v3(params, "position", Vector3.ZERO)
	_add(area, parent, root, "MCP: Add Area3D")
	if optional_bool(params, "add_collision_shape", true):
		_add_col_shape_3d(area, root, optional_string(params, "shape_type", "box"), params)
	return success({"node_path": str(root.get_path_to(area))})

func _setup_physical_bones(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	# Find Skeleton3D in parent or by path
	var skel_path: String = optional_string(params, "skeleton_path", "")
	var skel: Skeleton3D = null
	if skel_path != "":
		var n := find_node_by_path(skel_path)
		if n is Skeleton3D: skel = n
	if skel == null:
		for child in parent.get_children():
			if child is Skeleton3D: skel = child; break
	if skel == null:
		return error_not_found("Skeleton3D not found; provide skeleton_path or place under Skeleton3D parent")
	# Add PhysicalBoneSimulator3D
	var sim := PhysicalBoneSimulator3D.new()
	sim.name = optional_string(params, "name", "PhysicalBoneSimulator3D")
	_add(sim, skel, root, "MCP: Add PhysicalBoneSimulator3D")
	# Add PhysicalBone3D per bone name in list (or all if none specified)
	var bone_names: Array = optional_array(params, "bones", []).duplicate()
	var added_bones: Array = []
	if bone_names.is_empty():
		for i in range(skel.get_bone_count()):
			bone_names.append(skel.get_bone_name(i))
	for bone_name in bone_names:
		var idx := skel.find_bone(str(bone_name))
		if idx < 0: continue
		var pb := PhysicalBone3D.new()
		pb.name = str(bone_name) + "_PhysicalBone"
		pb.bone_name = str(bone_name)
		var cs := CollisionShape3D.new()
		cs.name = "CollisionShape3D"
		var ss := SphereShape3D.new()
		ss.radius = float(params.get("bone_radius", 0.1))
		cs.shape = ss
		pb.add_child(cs)
		cs.owner = root
		sim.add_child(pb)
		pb.owner = root
		added_bones.append(str(bone_name))
	return success({"simulator_path": str(root.get_path_to(sim)), "bones_added": added_bones})
