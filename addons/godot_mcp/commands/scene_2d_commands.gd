@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## 2D-specific editor tools: lights, skeleton, paths, parallax, animated sprites, etc.


func get_commands() -> Dictionary:
	return {
		"setup_light_2d":        _setup_light_2d,
		"setup_skeleton_2d":     _setup_skeleton_2d,
		"setup_path_2d":         _setup_path_2d,
		"setup_polygon_2d":      _setup_polygon_2d,
		"setup_line_2d":         _setup_line_2d,
		"setup_parallax":        _setup_parallax,
		"setup_canvas_layer":    _setup_canvas_layer,
		"setup_animated_sprite_2d": _setup_animated_sprite_2d,
		"get_sprite_frames":     _get_sprite_frames,
		"add_sprite_frame":      _add_sprite_frame,
		"setup_tilemap_layer":   _setup_tilemap_layer,
		"setup_cpu_particles_2d": _setup_cpu_particles_2d,
		"setup_light_occluder":  _setup_light_occluder,
		"setup_back_buffer_copy": _setup_back_buffer_copy,
	}


## ── Helpers ──────────────────────────────────────────────────────────────────

func _parse_v2(params: Dictionary, key: String, def: Vector2) -> Vector2:
	if not params.has(key): return def
	var v = params[key]
	if v is Dictionary: return Vector2(float(v.get("x", def.x)), float(v.get("y", def.y)))
	if v is Array and v.size() >= 2: return Vector2(float(v[0]), float(v[1]))
	return def

func _parse_color(params: Dictionary, key: String, def: Color) -> Color:
	if not params.has(key): return def
	var v = params[key]
	if v is String: return Color(v)
	if v is Dictionary: return Color(float(v.get("r", def.r)), float(v.get("g", def.g)), float(v.get("b", def.b)), float(v.get("a", def.a)))
	return def

func _add_child_undo(node: Node, parent: Node, root: Node, label: String) -> void:
	var ur := get_undo_redo()
	ur.create_action(label)
	ur.add_do_method(parent, "add_child", node)
	ur.add_do_method(node, "set_owner", root)
	ur.add_do_reference(node)
	ur.add_undo_method(parent, "remove_child", node)
	ur.commit_action()

func _get_parent_and_root(params: Dictionary) -> Array:
	var root := get_edited_root()
	if root == null: return [null, null, error_no_scene()]
	var pp: String = optional_string(params, "parent_path", ".")
	var parent := find_node_by_path(pp)
	if parent == null: return [null, null, error_not_found("Parent '%s'" % pp)]
	return [parent, root, null]


## ── 1. setup_light_2d ────────────────────────────────────────────────────────

func _setup_light_2d(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var light_type: String = optional_string(params, "light_type", "PointLight2D")
	var node_name: String = optional_string(params, "name", light_type)

	var light: Light2D
	match light_type:
		"PointLight2D":      light = PointLight2D.new()
		"DirectionalLight2D": light = DirectionalLight2D.new()
		_: return error_invalid_params("light_type must be PointLight2D or DirectionalLight2D")

	light.name = node_name
	light.color        = _parse_color(params, "color", Color.WHITE)
	light.energy       = float(params.get("energy", 1.0))
	light.shadow_enabled = optional_bool(params, "shadow_enabled", false)

	if light is PointLight2D:
		var pl := light as PointLight2D
		pl.texture_scale = float(params.get("texture_scale", 1.0))
		if params.has("texture"):
			var tp: String = params["texture"]
			if ResourceLoader.exists(tp): pl.texture = load(tp)

	light.position = _parse_v2(params, "position", Vector2.ZERO)
	_add_child_undo(light, parent, root, "MCP: Add %s" % light_type)
	return success({"node_path": str(root.get_path_to(light)), "light_type": light_type})


## ── 2. setup_skeleton_2d ─────────────────────────────────────────────────────

func _setup_skeleton_2d(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var skel := Skeleton2D.new()
	skel.name = optional_string(params, "name", "Skeleton2D")

	var bones: Array = params.get("bones", [])
	var bone_nodes: Array = []
	for b in bones:
		if not b is Dictionary: continue
		var bone := Bone2D.new()
		bone.name = str(b.get("name", "Bone2D"))
		bone.position = _parse_v2(b, "position", Vector2.ZERO)
		bone.rotation = float(b.get("rotation", 0.0))
		bone.set_default_length(float(b.get("length", 16.0)))
		skel.add_child(bone)
		bone.owner = root
		bone_nodes.append(str(skel.get_path_to(bone)))

	_add_child_undo(skel, parent, root, "MCP: Add Skeleton2D")
	return success({"node_path": str(root.get_path_to(skel)), "bone_count": bone_nodes.size(), "bones": bone_nodes})


## ── 3. setup_path_2d ─────────────────────────────────────────────────────────

func _setup_path_2d(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var path_node := Path2D.new()
	path_node.name = optional_string(params, "name", "Path2D")
	var curve := Curve2D.new()
	var points: Array = params.get("points", [])
	for p in points:
		if p is Dictionary:
			var pos := _parse_v2(p, "position", Vector2.ZERO)
			var ti  := _parse_v2(p, "in",  Vector2.ZERO)
			var to  := _parse_v2(p, "out", Vector2.ZERO)
			curve.add_point(pos, ti, to)
		elif p is Array and p.size() >= 2:
			curve.add_point(Vector2(float(p[0]), float(p[1])))
	path_node.curve = curve
	_add_child_undo(path_node, parent, root, "MCP: Add Path2D")

	var added: Array = []
	if optional_bool(params, "add_follow", false):
		var follow := PathFollow2D.new()
		follow.name = "PathFollow2D"
		path_node.add_child(follow)
		follow.owner = root
		added.append("PathFollow2D")

	return success({"node_path": str(root.get_path_to(path_node)), "point_count": curve.point_count, "added_children": added})


## ── 4. setup_polygon_2d ──────────────────────────────────────────────────────

func _setup_polygon_2d(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var poly := Polygon2D.new()
	poly.name = optional_string(params, "name", "Polygon2D")
	poly.color = _parse_color(params, "color", Color.WHITE)

	var verts: Array = params.get("vertices", [])
	if verts.is_empty():
		# Default square
		verts = [{"x": -50,"y": -50}, {"x": 50,"y": -50}, {"x": 50,"y": 50}, {"x": -50,"y": 50}]

	var packed := PackedVector2Array()
	for v in verts:
		if v is Dictionary: packed.append(Vector2(float(v.get("x", 0)), float(v.get("y", 0))))
		elif v is Array and v.size() >= 2: packed.append(Vector2(float(v[0]), float(v[1])))
	poly.polygon = packed

	if params.has("texture"):
		var tp: String = params["texture"]
		if ResourceLoader.exists(tp): poly.texture = load(tp)

	poly.position = _parse_v2(params, "position", Vector2.ZERO)
	_add_child_undo(poly, parent, root, "MCP: Add Polygon2D")
	return success({"node_path": str(root.get_path_to(poly)), "vertex_count": packed.size()})


## ── 5. setup_line_2d ─────────────────────────────────────────────────────────

func _setup_line_2d(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var line := Line2D.new()
	line.name    = optional_string(params, "name", "Line2D")
	line.width   = float(params.get("width", 4.0))
	line.default_color = _parse_color(params, "color", Color.WHITE)

	var points: Array = params.get("points", [])
	var packed := PackedVector2Array()
	for p in points:
		if p is Dictionary: packed.append(Vector2(float(p.get("x", 0)), float(p.get("y", 0))))
		elif p is Array and p.size() >= 2: packed.append(Vector2(float(p[0]), float(p[1])))
	if packed.is_empty():
		packed = PackedVector2Array([Vector2.ZERO, Vector2(100, 0)])
	line.points = packed

	var cap_str: String = optional_string(params, "end_cap_mode", "none")
	match cap_str.to_lower():
		"box":  line.end_cap_mode = Line2D.LINE_CAP_BOX
		"round": line.end_cap_mode = Line2D.LINE_CAP_ROUND
		_:      line.end_cap_mode = Line2D.LINE_CAP_NONE

	_add_child_undo(line, parent, root, "MCP: Add Line2D")
	return success({"node_path": str(root.get_path_to(line)), "point_count": packed.size()})


## ── 6. setup_parallax ────────────────────────────────────────────────────────

func _setup_parallax(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var bg := ParallaxBackground.new()
	bg.name = optional_string(params, "name", "ParallaxBackground")

	var layers: Array = params.get("layers", [{"scroll_scale": {"x": 0.5, "y": 0.5}}])
	var layer_paths: Array = []

	for i in range(layers.size()):
		var ld = layers[i]
		var layer := ParallaxLayer.new()
		layer.name = "ParallaxLayer%d" % i
		if ld is Dictionary:
			layer.motion_scale = _parse_v2(ld, "scroll_scale", Vector2(0.5, 0.5))
			layer.motion_offset = _parse_v2(ld, "offset", Vector2.ZERO)
			if ld.has("texture"):
				var tp: String = ld["texture"]
				if ResourceLoader.exists(tp):
					var spr := Sprite2D.new()
					spr.name = "Sprite2D"
					spr.texture = load(tp)
					layer.add_child(spr)
					spr.owner = root
		bg.add_child(layer)
		layer.owner = root
		layer_paths.append(str(bg.get_path_to(layer)))

	_add_child_undo(bg, parent, root, "MCP: Add ParallaxBackground")
	return success({"node_path": str(root.get_path_to(bg)), "layer_count": layers.size(), "layers": layer_paths})


## ── 7. setup_canvas_layer ────────────────────────────────────────────────────

func _setup_canvas_layer(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var cl := CanvasLayer.new()
	cl.name   = optional_string(params, "name", "CanvasLayer")
	cl.layer  = optional_int(params, "layer", 1)
	cl.follow_viewport_enabled = optional_bool(params, "follow_viewport", false)
	cl.offset = _parse_v2(params, "offset", Vector2.ZERO)

	_add_child_undo(cl, parent, root, "MCP: Add CanvasLayer")
	return success({"node_path": str(root.get_path_to(cl)), "layer": cl.layer})


## ── 8. setup_animated_sprite_2d ──────────────────────────────────────────────

func _setup_animated_sprite_2d(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var spr := AnimatedSprite2D.new()
	spr.name = optional_string(params, "name", "AnimatedSprite2D")

	var frames := SpriteFrames.new()
	var animations: Array = params.get("animations", [])
	if animations.is_empty():
		animations = [{"name": "default", "fps": 10.0, "loop": true, "textures": []}]

	for anim in animations:
		if not anim is Dictionary: continue
		var anim_name: String = str(anim.get("name", "default"))
		if anim_name != "default" and not frames.has_animation(anim_name):
			frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, float(anim.get("fps", 10.0)))
		frames.set_animation_loop(anim_name, bool(anim.get("loop", true)))
		for tex_path in anim.get("textures", []):
			if ResourceLoader.exists(str(tex_path)):
				frames.add_frame(anim_name, load(str(tex_path)))

	spr.sprite_frames = frames
	spr.animation = optional_string(params, "default_animation", "default")
	spr.position = _parse_v2(params, "position", Vector2.ZERO)
	spr.scale    = _parse_v2(params, "scale", Vector2.ONE)

	_add_child_undo(spr, parent, root, "MCP: Add AnimatedSprite2D")
	return success({"node_path": str(root.get_path_to(spr)), "animations": frames.get_animation_names()})


## ── 9. get_sprite_frames ─────────────────────────────────────────────────────

func _get_sprite_frames(params: Dictionary) -> Dictionary:
	var res := require_string(params, "node_path")
	if res[1] != null: return res[1]
	var node := find_node_by_path(res[0])
	if node == null: return error_not_found("Node '%s'" % res[0])

	var frames: SpriteFrames = null
	if node is AnimatedSprite2D:   frames = (node as AnimatedSprite2D).sprite_frames
	elif node is AnimatedSprite3D: frames = (node as AnimatedSprite3D).sprite_frames
	if frames == null: return error_invalid_params("Node has no SpriteFrames resource")

	var result: Dictionary = {}
	for anim_name in frames.get_animation_names():
		result[anim_name] = {
			"fps":        frames.get_animation_speed(anim_name),
			"loop":       frames.get_animation_loop(anim_name),
			"frame_count": frames.get_frame_count(anim_name),
		}
	return success({"animations": result})


## ── 10. add_sprite_frame ─────────────────────────────────────────────────────

func _add_sprite_frame(params: Dictionary) -> Dictionary:
	var res := require_string(params, "node_path")
	if res[1] != null: return res[1]
	var tp_res := require_string(params, "texture_path")
	if tp_res[1] != null: return tp_res[1]

	var node := find_node_by_path(res[0])
	if node == null: return error_not_found("Node '%s'" % res[0])
	if not node is AnimatedSprite2D and not node is AnimatedSprite3D:
		return error_invalid_params("Node must be AnimatedSprite2D or AnimatedSprite3D")

	var frames: SpriteFrames
	if node is AnimatedSprite2D:   frames = (node as AnimatedSprite2D).sprite_frames
	elif node is AnimatedSprite3D: frames = (node as AnimatedSprite3D).sprite_frames
	if frames == null: return error_invalid_params("Node has no SpriteFrames assigned")

	var anim_name: String = optional_string(params, "animation", "default")
	if not frames.has_animation(anim_name): frames.add_animation(anim_name)

	var tex_path: String = tp_res[0]
	if not ResourceLoader.exists(tex_path): return error_not_found("Texture '%s'" % tex_path)
	var tex: Texture2D = load(tex_path)
	var at_index: int = optional_int(params, "at_index", -1)
	if at_index < 0: at_index = frames.get_frame_count(anim_name)
	frames.add_frame(anim_name, tex, 1.0, at_index)

	return success({"animation": anim_name, "frame_count": frames.get_frame_count(anim_name)})


## ── 11. setup_tilemap_layer ──────────────────────────────────────────────────

func _setup_tilemap_layer(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	# Try TileMapLayer (Godot 4.3+), fall back to TileMap
	var node: Node
	var class_name_used: String
	if ClassDB.class_exists("TileMapLayer"):
		node = ClassDB.instantiate("TileMapLayer")
		class_name_used = "TileMapLayer"
	else:
		node = TileMap.new()
		class_name_used = "TileMap"
	node.name = optional_string(params, "name", class_name_used)

	if params.has("tile_set"):
		var ts_path: String = params["tile_set"]
		if ResourceLoader.exists(ts_path):
			var ts: Resource = load(ts_path)
			if ts is TileSet: node.set("tile_set", ts)

	node.set("position", _parse_v2(params, "position", Vector2.ZERO))

	_add_child_undo(node, parent, root, "MCP: Add %s" % class_name_used)
	return success({"node_path": str(root.get_path_to(node)), "class": class_name_used})


## ── 12. setup_cpu_particles_2d ───────────────────────────────────────────────

func _setup_cpu_particles_2d(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var p := CPUParticles2D.new()
	p.name        = optional_string(params, "name", "CPUParticles2D")
	p.amount      = optional_int(params, "amount", 32)
	p.lifetime    = float(params.get("lifetime", 2.0))
	p.explosiveness = float(params.get("explosiveness", 0.0))
	p.emitting    = optional_bool(params, "emitting", true)
	p.color       = _parse_color(params, "color", Color.WHITE)
	p.gravity     = _parse_v2(params, "gravity", Vector2(0, 98))
	p.initial_velocity_min = float(params.get("velocity_min", 50.0))
	p.initial_velocity_max = float(params.get("velocity_max", 100.0))
	p.position    = _parse_v2(params, "position", Vector2.ZERO)

	if params.has("texture"):
		var tp: String = params["texture"]
		if ResourceLoader.exists(tp): p.texture = load(tp)

	_add_child_undo(p, parent, root, "MCP: Add CPUParticles2D")
	return success({"node_path": str(root.get_path_to(p)), "amount": p.amount})


## ── 13. setup_light_occluder ─────────────────────────────────────────────────

func _setup_light_occluder(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var occ := LightOccluder2D.new()
	occ.name = optional_string(params, "name", "LightOccluder2D")
	occ.sdf_collision = optional_bool(params, "sdf_collision", true)
	occ.occluder_light_mask = optional_int(params, "light_mask", 1)

	var poly := OccluderPolygon2D.new()
	var verts: Array = params.get("polygon", [])
	var packed := PackedVector2Array()
	for v in verts:
		if v is Dictionary: packed.append(Vector2(float(v.get("x", 0)), float(v.get("y", 0))))
		elif v is Array and v.size() >= 2: packed.append(Vector2(float(v[0]), float(v[1])))
	if packed.is_empty():
		packed = PackedVector2Array([Vector2(-32,-32), Vector2(32,-32), Vector2(32,32), Vector2(-32,32)])
	poly.polygon = packed
	poly.closed  = optional_bool(params, "closed", true)
	occ.occluder = poly

	occ.position = _parse_v2(params, "position", Vector2.ZERO)
	_add_child_undo(occ, parent, root, "MCP: Add LightOccluder2D")
	return success({"node_path": str(root.get_path_to(occ)), "vertex_count": packed.size()})


## ── 14. setup_back_buffer_copy ───────────────────────────────────────────────

func _setup_back_buffer_copy(params: Dictionary) -> Dictionary:
	var arr := _get_parent_and_root(params)
	if arr[2] != null: return arr[2]
	var parent: Node = arr[0]; var root: Node = arr[1]

	var bbc := BackBufferCopy.new()
	bbc.name = optional_string(params, "name", "BackBufferCopy")

	var mode_str: String = optional_string(params, "copy_mode", "viewport")
	match mode_str.to_lower():
		"disabled": bbc.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
		"rect":     bbc.copy_mode = BackBufferCopy.COPY_MODE_RECT
		_:          bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT

	if params.has("rect"):
		var r = params["rect"]
		if r is Dictionary:
			bbc.rect = Rect2(
				float(r.get("x", -100)), float(r.get("y", -100)),
				float(r.get("w", 200)),  float(r.get("h", 200))
			)

	_add_child_undo(bbc, parent, root, "MCP: Add BackBufferCopy")
	return success({"node_path": str(root.get_path_to(bbc)), "copy_mode": mode_str})
