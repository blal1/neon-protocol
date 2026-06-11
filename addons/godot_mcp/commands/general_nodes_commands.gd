@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

func get_commands() -> Dictionary:
	return {
		"setup_sprite_2d": _setup_sprite_2d,
		"setup_camera_2d": _setup_camera_2d,
		"setup_canvas_modulate": _setup_canvas_modulate,
		"setup_raycast_2d": _setup_raycast_2d,
		"setup_shape_cast_2d": _setup_shape_cast_2d,
		"setup_remote_transform_2d": _setup_remote_transform_2d,
		"setup_visible_notifier_2d": _setup_visible_notifier_2d,
		"setup_marker_2d": _setup_marker_2d,
		"setup_sprite_3d": _setup_sprite_3d,
		"setup_shape_cast_3d": _setup_shape_cast_3d,
		"setup_remote_transform_3d": _setup_remote_transform_3d,
		"setup_visible_notifier_3d": _setup_visible_notifier_3d,
		"setup_marker_3d": _setup_marker_3d,
		"setup_bone_attachment": _setup_bone_attachment,
		"setup_timer": _setup_timer,
		"setup_subviewport": _setup_subviewport,
		"setup_nine_patch_rect": _setup_nine_patch_rect,
		"setup_video_player": _setup_video_player,
		"setup_gpu_particles_2d": _setup_gpu_particles_2d,
		"setup_gpu_particles_3d": _setup_gpu_particles_3d,
		"setup_audio_listener": _setup_audio_listener,
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

func _col(p: Dictionary, k: String, d: Color) -> Color:
	if not p.has(k): return d
	var v = p[k]
	if v is String: return Color(v)
	if v is Dictionary: return Color(float(v.get("r", d.r)), float(v.get("g", d.g)), float(v.get("b", d.b)), float(v.get("a", d.a)))
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

func _setup_sprite_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var s := Sprite2D.new()
	s.name = optional_string(params, "name", "Sprite2D")
	if params.has("texture") and ResourceLoader.exists(str(params["texture"])):
		s.texture = load(str(params["texture"]))
	s.hframes = optional_int(params, "hframes", 1)
	s.vframes = optional_int(params, "vframes", 1)
	s.frame = optional_int(params, "frame", 0)
	s.centered = optional_bool(params, "centered", true)
	s.flip_h = optional_bool(params, "flip_h", false)
	s.flip_v = optional_bool(params, "flip_v", false)
	if params.has("region_rect"):
		var r = params["region_rect"]
		if r is Dictionary:
			s.region_enabled = true
			s.region_rect = Rect2(float(r.get("x",0)), float(r.get("y",0)), float(r.get("w",32)), float(r.get("h",32)))
	s.position = _v2(params, "position", Vector2.ZERO)
	s.scale = _v2(params, "scale", Vector2.ONE)
	_add(s, parent, root, "MCP: Add Sprite2D")
	return success({"node_path": str(root.get_path_to(s))})

func _setup_camera_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var c := Camera2D.new()
	c.name = optional_string(params, "name", "Camera2D")
	c.zoom = _v2(params, "zoom", Vector2.ONE)
	c.position_smoothing_enabled = optional_bool(params, "smoothing_enabled", false)
	c.position_smoothing_speed = float(params.get("smoothing_speed", 5.0))
	c.drag_horizontal_enabled = optional_bool(params, "drag_horizontal", false)
	c.drag_vertical_enabled = optional_bool(params, "drag_vertical", false)
	c.enabled = optional_bool(params, "enabled", true)
	c.position = _v2(params, "position", Vector2.ZERO)
	_add(c, parent, root, "MCP: Add Camera2D")
	if optional_bool(params, "make_current", true): c.make_current()
	return success({"node_path": str(root.get_path_to(c))})

func _setup_canvas_modulate(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var cm := CanvasModulate.new()
	cm.name = optional_string(params, "name", "CanvasModulate")
	cm.color = _col(params, "color", Color.WHITE)
	_add(cm, parent, root, "MCP: Add CanvasModulate")
	return success({"node_path": str(root.get_path_to(cm))})

func _setup_raycast_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var rc := RayCast2D.new()
	rc.name = optional_string(params, "name", "RayCast2D")
	rc.target_position = _v2(params, "target_position", Vector2(0, 50))
	rc.collision_mask = optional_int(params, "collision_mask", 1)
	rc.enabled = optional_bool(params, "enabled", true)
	rc.collide_with_areas = optional_bool(params, "collide_with_areas", false)
	rc.collide_with_bodies = optional_bool(params, "collide_with_bodies", true)
	rc.position = _v2(params, "position", Vector2.ZERO)
	_add(rc, parent, root, "MCP: Add RayCast2D")
	return success({"node_path": str(root.get_path_to(rc))})

func _setup_shape_cast_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var sc := ShapeCast2D.new()
	sc.name = optional_string(params, "name", "ShapeCast2D")
	sc.target_position = _v2(params, "target_position", Vector2(0, 50))
	sc.collision_mask = optional_int(params, "collision_mask", 1)
	sc.enabled = optional_bool(params, "enabled", true)
	var shape_type: String = optional_string(params, "shape_type", "circle")
	if shape_type == "rect":
		var rs := RectangleShape2D.new()
		rs.size = _v2(params, "size", Vector2(10, 10))
		sc.shape = rs
	else:
		var cs := CircleShape2D.new()
		cs.radius = float(params.get("radius", 10.0))
		sc.shape = cs
	sc.position = _v2(params, "position", Vector2.ZERO)
	_add(sc, parent, root, "MCP: Add ShapeCast2D")
	return success({"node_path": str(root.get_path_to(sc)), "shape": shape_type})

func _setup_remote_transform_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var rt := RemoteTransform2D.new()
	rt.name = optional_string(params, "name", "RemoteTransform2D")
	if params.has("remote_path"): rt.remote_path = NodePath(str(params["remote_path"]))
	rt.update_position = optional_bool(params, "update_position", true)
	rt.update_rotation = optional_bool(params, "update_rotation", true)
	rt.update_scale = optional_bool(params, "update_scale", true)
	rt.use_global_coordinates = optional_bool(params, "use_global_coordinates", false)
	rt.position = _v2(params, "position", Vector2.ZERO)
	_add(rt, parent, root, "MCP: Add RemoteTransform2D")
	return success({"node_path": str(root.get_path_to(rt))})

func _setup_visible_notifier_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var use_enabler: bool = optional_bool(params, "use_enabler", false)
	var node: Node2D
	if use_enabler:
		node = VisibleOnScreenEnabler2D.new()
		node.name = optional_string(params, "name", "VisibleOnScreenEnabler2D")
	else:
		node = VisibleOnScreenNotifier2D.new()
		node.name = optional_string(params, "name", "VisibleOnScreenNotifier2D")
	if params.has("rect"):
		var r = params["rect"]
		if r is Dictionary:
			node.set("rect", Rect2(float(r.get("x",-10)), float(r.get("y",-10)), float(r.get("w",20)), float(r.get("h",20))))
	node.position = _v2(params, "position", Vector2.ZERO)
	_add(node, parent, root, "MCP: Add VisibleOnScreenNotifier2D")
	return success({"node_path": str(root.get_path_to(node)), "class": node.get_class()})

func _setup_marker_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var m := Marker2D.new()
	m.name = optional_string(params, "name", "Marker2D")
	m.gizmo_extents = float(params.get("gizmo_extents", 10.0))
	m.position = _v2(params, "position", Vector2.ZERO)
	_add(m, parent, root, "MCP: Add Marker2D")
	return success({"node_path": str(root.get_path_to(m))})

func _setup_sprite_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var s := Sprite3D.new()
	s.name = optional_string(params, "name", "Sprite3D")
	if params.has("texture") and ResourceLoader.exists(str(params["texture"])):
		s.texture = load(str(params["texture"]))
	s.pixel_size = float(params.get("pixel_size", 0.01))
	s.double_sided = optional_bool(params, "double_sided", true)
	s.centered = optional_bool(params, "centered", true)
	s.flip_h = optional_bool(params, "flip_h", false)
	s.flip_v = optional_bool(params, "flip_v", false)
	s.hframes = optional_int(params, "hframes", 1)
	s.vframes = optional_int(params, "vframes", 1)
	if optional_bool(params, "billboard", false):
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.position = _v3(params, "position", Vector3.ZERO)
	_add(s, parent, root, "MCP: Add Sprite3D")
	return success({"node_path": str(root.get_path_to(s))})

func _setup_shape_cast_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var sc := ShapeCast3D.new()
	sc.name = optional_string(params, "name", "ShapeCast3D")
	sc.target_position = _v3(params, "target_position", Vector3(0, -1, 0))
	sc.collision_mask = optional_int(params, "collision_mask", 1)
	sc.enabled = optional_bool(params, "enabled", true)
	var shape_type: String = optional_string(params, "shape_type", "sphere")
	if shape_type == "box":
		var bs := BoxShape3D.new()
		bs.size = _v3(params, "size", Vector3(0.5, 0.5, 0.5))
		sc.shape = bs
	elif shape_type == "capsule":
		var caps := CapsuleShape3D.new()
		caps.radius = float(params.get("radius", 0.3))
		caps.height = float(params.get("height", 1.0))
		sc.shape = caps
	else:
		var ss := SphereShape3D.new()
		ss.radius = float(params.get("radius", 0.5))
		sc.shape = ss
	sc.position = _v3(params, "position", Vector3.ZERO)
	_add(sc, parent, root, "MCP: Add ShapeCast3D")
	return success({"node_path": str(root.get_path_to(sc)), "shape": shape_type})

func _setup_remote_transform_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var rt := RemoteTransform3D.new()
	rt.name = optional_string(params, "name", "RemoteTransform3D")
	if params.has("remote_path"): rt.remote_path = NodePath(str(params["remote_path"]))
	rt.update_position = optional_bool(params, "update_position", true)
	rt.update_rotation = optional_bool(params, "update_rotation", true)
	rt.update_scale = optional_bool(params, "update_scale", true)
	rt.use_global_coordinates = optional_bool(params, "use_global_coordinates", false)
	rt.position = _v3(params, "position", Vector3.ZERO)
	_add(rt, parent, root, "MCP: Add RemoteTransform3D")
	return success({"node_path": str(root.get_path_to(rt))})

func _setup_visible_notifier_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var use_enabler: bool = optional_bool(params, "use_enabler", false)
	var node: Node3D
	if use_enabler:
		node = VisibleOnScreenEnabler3D.new()
		node.name = optional_string(params, "name", "VisibleOnScreenEnabler3D")
	else:
		node = VisibleOnScreenNotifier3D.new()
		node.name = optional_string(params, "name", "VisibleOnScreenNotifier3D")
	if params.has("aabb"):
		var b = params["aabb"]
		if b is Dictionary:
			node.set("aabb", AABB(
				Vector3(float(b.get("px",0)), float(b.get("py",0)), float(b.get("pz",0))),
				Vector3(float(b.get("sx",1)), float(b.get("sy",1)), float(b.get("sz",1)))))
	node.position = _v3(params, "position", Vector3.ZERO)
	_add(node, parent, root, "MCP: Add VisibleOnScreenNotifier3D")
	return success({"node_path": str(root.get_path_to(node)), "class": node.get_class()})

func _setup_marker_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var m := Marker3D.new()
	m.name = optional_string(params, "name", "Marker3D")
	m.gizmo_extents = float(params.get("gizmo_extents", 0.25))
	m.position = _v3(params, "position", Vector3.ZERO)
	_add(m, parent, root, "MCP: Add Marker3D")
	return success({"node_path": str(root.get_path_to(m))})

func _setup_bone_attachment(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var ba := BoneAttachment3D.new()
	ba.name = optional_string(params, "name", "BoneAttachment3D")
	if params.has("bone_name"): ba.bone_name = str(params["bone_name"])
	if params.has("bone_index"): ba.bone_idx = optional_int(params, "bone_index", 0)
	ba.override_pose = optional_bool(params, "override_pose", false)
	_add(ba, parent, root, "MCP: Add BoneAttachment3D")
	return success({"node_path": str(root.get_path_to(ba)), "bone_name": ba.bone_name})

func _setup_timer(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var t := Timer.new()
	t.name = optional_string(params, "name", "Timer")
	t.wait_time = float(params.get("wait_time", 1.0))
	t.one_shot = optional_bool(params, "one_shot", false)
	t.autostart = optional_bool(params, "autostart", false)
	if optional_string(params, "process_callback", "idle") == "physics":
		t.process_callback = Timer.TIMER_PROCESS_PHYSICS
	else:
		t.process_callback = Timer.TIMER_PROCESS_IDLE
	_add(t, parent, root, "MCP: Add Timer")
	return success({"node_path": str(root.get_path_to(t)), "wait_time": t.wait_time, "one_shot": t.one_shot})

func _setup_subviewport(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var container := SubViewportContainer.new()
	container.name = optional_string(params, "container_name", "SubViewportContainer")
	container.stretch = optional_bool(params, "stretch", true)
	var sz = params.get("size", {"x": 320, "y": 240})
	if sz is Dictionary:
		container.custom_minimum_size = Vector2(float(sz.get("x",320)), float(sz.get("y",240)))
	var vp := SubViewport.new()
	vp.name = optional_string(params, "name", "SubViewport")
	if sz is Dictionary:
		vp.size = Vector2i(int(sz.get("x",320)), int(sz.get("y",240)))
	var upd: String = optional_string(params, "update_mode", "always")
	match upd:
		"once": vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		"when_visible": vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
		"when_parent_visible": vp.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
		_: vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = optional_bool(params, "transparent_bg", false)
	container.add_child(vp)
	vp.owner = root
	_add(container, parent, root, "MCP: Add SubViewport")
	return success({"container_path": str(root.get_path_to(container)), "viewport_path": str(root.get_path_to(vp)), "size": {"x": vp.size.x, "y": vp.size.y}})

func _setup_nine_patch_rect(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var np := NinePatchRect.new()
	np.name = optional_string(params, "name", "NinePatchRect")
	if params.has("texture") and ResourceLoader.exists(str(params["texture"])):
		np.texture = load(str(params["texture"]))
	np.patch_margin_left   = optional_int(params, "margin_left",   16)
	np.patch_margin_right  = optional_int(params, "margin_right",  16)
	np.patch_margin_top    = optional_int(params, "margin_top",    16)
	np.patch_margin_bottom = optional_int(params, "margin_bottom", 16)
	np.draw_center = optional_bool(params, "draw_center", true)
	_add(np, parent, root, "MCP: Add NinePatchRect")
	return success({"node_path": str(root.get_path_to(np))})

func _setup_video_player(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var vp := VideoStreamPlayer.new()
	vp.name = optional_string(params, "name", "VideoStreamPlayer")
	vp.autoplay = optional_bool(params, "autoplay", false)
	vp.loop = optional_bool(params, "loop", false)
	vp.volume_db = float(params.get("volume_db", 0.0))
	vp.expand = optional_bool(params, "expand", true)
	if params.has("stream") and ResourceLoader.exists(str(params["stream"])):
		vp.stream = load(str(params["stream"]))
	_add(vp, parent, root, "MCP: Add VideoStreamPlayer")
	return success({"node_path": str(root.get_path_to(vp))})

func _setup_gpu_particles_2d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var p := GPUParticles2D.new()
	p.name = optional_string(params, "name", "GPUParticles2D")
	p.amount = optional_int(params, "amount", 32)
	p.lifetime = float(params.get("lifetime", 2.0))
	p.emitting = optional_bool(params, "emitting", true)
	p.one_shot = optional_bool(params, "one_shot", false)
	p.explosiveness = float(params.get("explosiveness", 0.0))
	p.randomness = float(params.get("randomness", 0.0))
	p.local_coords = optional_bool(params, "local_coords", false)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = float(params.get("spread", 45.0))
	mat.initial_velocity_min = float(params.get("velocity_min", 50.0))
	mat.initial_velocity_max = float(params.get("velocity_max", 100.0))
	mat.gravity = Vector3(0, 98, 0)
	p.process_material = mat
	if params.has("texture") and ResourceLoader.exists(str(params["texture"])):
		p.texture = load(str(params["texture"]))
	p.position = _v2(params, "position", Vector2.ZERO)
	_add(p, parent, root, "MCP: Add GPUParticles2D")
	return success({"node_path": str(root.get_path_to(p)), "amount": p.amount})

func _setup_gpu_particles_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var p := GPUParticles3D.new()
	p.name = optional_string(params, "name", "GPUParticles3D")
	p.amount = optional_int(params, "amount", 32)
	p.lifetime = float(params.get("lifetime", 2.0))
	p.emitting = optional_bool(params, "emitting", true)
	p.one_shot = optional_bool(params, "one_shot", false)
	p.explosiveness = float(params.get("explosiveness", 0.0))
	p.randomness = float(params.get("randomness", 0.0))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, 1, 0)
	mat.spread = float(params.get("spread", 45.0))
	mat.initial_velocity_min = float(params.get("velocity_min", 1.0))
	mat.initial_velocity_max = float(params.get("velocity_max", 3.0))
	p.process_material = mat
	if params.has("mesh") and ResourceLoader.exists(str(params["mesh"])):
		p.draw_pass_1 = load(str(params["mesh"]))
	p.position = _v3(params, "position", Vector3.ZERO)
	_add(p, parent, root, "MCP: Add GPUParticles3D")
	return success({"node_path": str(root.get_path_to(p)), "amount": p.amount})

func _setup_audio_listener(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var dim: String = optional_string(params, "dimension", "3d")
	var node: Node
	if dim == "2d":
		node = AudioListener2D.new()
		node.name = optional_string(params, "name", "AudioListener2D")
		node.set("position", _v2(params, "position", Vector2.ZERO))
	else:
		node = AudioListener3D.new()
		node.name = optional_string(params, "name", "AudioListener3D")
		node.set("position", _v3(params, "position", Vector3.ZERO))
	_add(node, parent, root, "MCP: Add AudioListener")
	return success({"node_path": str(root.get_path_to(node)), "class": node.get_class()})
