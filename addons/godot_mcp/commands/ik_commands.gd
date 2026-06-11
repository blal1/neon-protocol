@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## IK modifiers, SpringBone, Navigation extras, Lightmap nodes

func get_commands() -> Dictionary:
	return {
		"setup_fabrik_3d":            _setup_fabrik_3d,
		"setup_two_bone_ik":          _setup_two_bone_ik,
		"setup_chain_ik":             _setup_chain_ik,
		"setup_look_at_modifier":     _setup_look_at_modifier,
		"setup_spring_bone":          _setup_spring_bone,
		"setup_spring_bone_collision": _setup_spring_bone_collision,
		"setup_navigation_link":      _setup_navigation_link,
		"setup_navigation_obstacle":  _setup_navigation_obstacle,
		"setup_lightmap_gi":          _setup_lightmap_gi,
		"setup_lightmap_probe":       _setup_lightmap_probe,
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

func _setup_fabrik_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("FABRIK3D"):
		return error_invalid_params("FABRIK3D requires Godot 4.3+")
	var ik = ClassDB.instantiate("FABRIK3D")
	ik.name = optional_string(params, "name", "FABRIK3D")
	if params.has("target_node"): ik.set("target_node", NodePath(str(params["target_node"])))
	if params.has("root_bone"): ik.set("root_bone", str(params["root_bone"]))
	if params.has("tip_bone"): ik.set("tip_bone", str(params["tip_bone"]))
	ik.set("max_iterations", optional_int(params, "max_iterations", 10))
	_add(ik, parent, root, "MCP: Add FABRIK3D")
	return success({"node_path": str(root.get_path_to(ik))})

func _setup_two_bone_ik(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("TwoBoneIK3D"):
		return error_invalid_params("TwoBoneIK3D requires Godot 4.3+")
	var ik = ClassDB.instantiate("TwoBoneIK3D")
	ik.name = optional_string(params, "name", "TwoBoneIK3D")
	if params.has("target_node"): ik.set("target_node", NodePath(str(params["target_node"])))
	if params.has("root_bone"): ik.set("root_bone", str(params["root_bone"]))
	if params.has("mid_bone"): ik.set("mid_bone", str(params["mid_bone"]))
	if params.has("tip_bone"): ik.set("tip_bone", str(params["tip_bone"]))
	if params.has("pole_node"): ik.set("pole_node", NodePath(str(params["pole_node"])))
	_add(ik, parent, root, "MCP: Add TwoBoneIK3D")
	return success({"node_path": str(root.get_path_to(ik))})

func _setup_chain_ik(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("ChainIK3D"):
		return error_invalid_params("ChainIK3D requires Godot 4.3+")
	var ik = ClassDB.instantiate("ChainIK3D")
	ik.name = optional_string(params, "name", "ChainIK3D")
	if params.has("target_node"): ik.set("target_node", NodePath(str(params["target_node"])))
	if params.has("root_bone"): ik.set("root_bone", str(params["root_bone"]))
	if params.has("tip_bone"): ik.set("tip_bone", str(params["tip_bone"]))
	ik.set("max_iterations", optional_int(params, "max_iterations", 10))
	_add(ik, parent, root, "MCP: Add ChainIK3D")
	return success({"node_path": str(root.get_path_to(ik))})

func _setup_look_at_modifier(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("LookAtModifier3D"):
		return error_invalid_params("LookAtModifier3D requires Godot 4.3+")
	var mod = ClassDB.instantiate("LookAtModifier3D")
	mod.name = optional_string(params, "name", "LookAtModifier3D")
	if params.has("bone_name"): mod.set("bone_name", str(params["bone_name"]))
	if params.has("target_node"): mod.set("target_node", NodePath(str(params["target_node"])))
	mod.set("duration", float(params.get("duration", 0.0)))
	_add(mod, parent, root, "MCP: Add LookAtModifier3D")
	return success({"node_path": str(root.get_path_to(mod))})

func _setup_spring_bone(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("SpringBoneSimulator3D"):
		return error_invalid_params("SpringBoneSimulator3D requires Godot 4.4+")
	var sim = ClassDB.instantiate("SpringBoneSimulator3D")
	sim.name = optional_string(params, "name", "SpringBoneSimulator3D")
	sim.set("stiffness", float(params.get("stiffness", 0.5)))
	sim.set("drag_force", float(params.get("drag_force", 0.5)))
	sim.set("gravity", float(params.get("gravity", 0.0)))
	var roots: Array = params.get("root_bones", [])
	if not roots.is_empty():
		sim.set("root_bones", roots)
	_add(sim, parent, root, "MCP: Add SpringBoneSimulator3D")
	return success({"node_path": str(root.get_path_to(sim))})

func _setup_spring_bone_collision(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var shape_type: String = optional_string(params, "shape_type", "sphere")
	var node: Node3D
	if shape_type == "capsule" and ClassDB.class_exists("SpringBoneCollisionCapsule3D"):
		node = ClassDB.instantiate("SpringBoneCollisionCapsule3D")
		node.name = optional_string(params, "name", "SpringBoneCollisionCapsule3D")
		node.set("radius", float(params.get("radius", 0.1)))
		node.set("height", float(params.get("height", 0.5)))
	elif shape_type == "plane" and ClassDB.class_exists("SpringBoneCollisionPlane3D"):
		node = ClassDB.instantiate("SpringBoneCollisionPlane3D")
		node.name = optional_string(params, "name", "SpringBoneCollisionPlane3D")
	else:
		if not ClassDB.class_exists("SpringBoneCollisionSphere3D"):
			return error_invalid_params("SpringBoneCollision requires Godot 4.4+")
		node = ClassDB.instantiate("SpringBoneCollisionSphere3D")
		node.name = optional_string(params, "name", "SpringBoneCollisionSphere3D")
		node.set("radius", float(params.get("radius", 0.1)))
	node.position = _v3(params, "position", Vector3.ZERO)
	_add(node, parent, root, "MCP: Add SpringBoneCollision")
	return success({"node_path": str(root.get_path_to(node)), "shape_type": shape_type})

func _setup_navigation_link(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var dim: String = optional_string(params, "dimension", "3d")
	var node: Node
	if dim == "2d":
		node = NavigationLink2D.new()
		node.name = optional_string(params, "name", "NavigationLink2D")
		node.set("bidirectional", optional_bool(params, "bidirectional", true))
		node.set("start_position", _v2(params, "start_position", Vector2.ZERO))
		node.set("end_position", _v2(params, "end_position", Vector2(64, 0)))
		node.set("navigation_layers", optional_int(params, "navigation_layers", 1))
		node.set("enabled", optional_bool(params, "enabled", true))
	else:
		node = NavigationLink3D.new()
		node.name = optional_string(params, "name", "NavigationLink3D")
		node.set("bidirectional", optional_bool(params, "bidirectional", true))
		node.set("start_position", _v3(params, "start_position", Vector3.ZERO))
		node.set("end_position", _v3(params, "end_position", Vector3(2, 0, 0)))
		node.set("navigation_layers", optional_int(params, "navigation_layers", 1))
		node.set("enabled", optional_bool(params, "enabled", true))
	_add(node, parent, root, "MCP: Add NavigationLink")
	return success({"node_path": str(root.get_path_to(node)), "class": node.get_class()})

func _setup_navigation_obstacle(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var dim: String = optional_string(params, "dimension", "3d")
	var node: Node
	if dim == "2d":
		node = NavigationObstacle2D.new()
		node.name = optional_string(params, "name", "NavigationObstacle2D")
		node.set("radius", float(params.get("radius", 32.0)))
		node.set("avoidance_enabled", optional_bool(params, "avoidance_enabled", true))
		if params.has("vertices"):
			var verts := PackedVector2Array()
			for v in params["vertices"]:
				if v is Dictionary: verts.append(Vector2(float(v.get("x",0)), float(v.get("y",0))))
			node.set("vertices", verts)
	else:
		node = NavigationObstacle3D.new()
		node.name = optional_string(params, "name", "NavigationObstacle3D")
		node.set("radius", float(params.get("radius", 0.5)))
		node.set("height", float(params.get("height", 1.0)))
		node.set("avoidance_enabled", optional_bool(params, "avoidance_enabled", true))
		node.set("use_3d_avoidance", optional_bool(params, "use_3d_avoidance", false))
	_add(node, parent, root, "MCP: Add NavigationObstacle")
	return success({"node_path": str(root.get_path_to(node)), "class": node.get_class()})

func _setup_lightmap_gi(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var lm := LightmapGI.new()
	lm.name = optional_string(params, "name", "LightmapGI")
	var quality_str: String = optional_string(params, "quality", "medium")
	match quality_str:
		"low":    lm.quality = LightmapGI.BAKE_QUALITY_LOW
		"high":   lm.quality = LightmapGI.BAKE_QUALITY_HIGH
		"ultra":  lm.quality = LightmapGI.BAKE_QUALITY_ULTRA
		_:        lm.quality = LightmapGI.BAKE_QUALITY_MEDIUM
	lm.bounces = optional_int(params, "bounces", 3)
	lm.directional = optional_bool(params, "directional", false)
	lm.use_denoiser = optional_bool(params, "use_denoiser", true)
	lm.bias = float(params.get("bias", 0.0005))
	lm.max_texture_size = optional_int(params, "max_texture_size", 16384)
	lm.position = _v3(params, "position", Vector3.ZERO)
	_add(lm, parent, root, "MCP: Add LightmapGI")
	return success({"node_path": str(root.get_path_to(lm)), "quality": quality_str, "bounces": lm.bounces})

func _setup_lightmap_probe(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var probe := LightmapProbe.new()
	probe.name = optional_string(params, "name", "LightmapProbe")
	probe.position = _v3(params, "position", Vector3.ZERO)
	_add(probe, parent, root, "MCP: Add LightmapProbe")
	return success({"node_path": str(root.get_path_to(probe))})
