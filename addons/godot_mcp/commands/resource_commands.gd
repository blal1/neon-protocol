@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

const PropertyParser := preload("res://addons/godot_mcp/utils/property_parser.gd")

## Resource creation tools: Curve, Gradient, Noise, PhysicsMaterial, AnimationLibrary, Compositor, etc.

func get_commands() -> Dictionary:
	return {
		"read_resource":              _read_resource,
		"edit_resource":              _edit_resource,
		"create_resource":            _create_resource,
		"get_resource_preview":       _get_resource_preview,
		"create_curve":               _create_curve,
		"create_gradient":            _create_gradient,
		"create_noise_texture":       _create_noise_texture,
		"create_physics_material":    _create_physics_material,
		"create_label_settings":      _create_label_settings,
		"create_mesh_library":        _create_mesh_library,
		"list_animation_libraries":   _list_animation_libraries,
		"create_animation_library":   _create_animation_library,
		"add_animation_to_library":   _add_animation_to_library,
		"setup_compositor":           _setup_compositor,
	}

func _col(p: Dictionary, k: String, d: Color) -> Color:
	if not p.has(k): return d
	var v = p[k]
	if v is String: return Color(v)
	if v is Dictionary: return Color(float(v.get("r",d.r)), float(v.get("g",d.g)), float(v.get("b",d.b)), float(v.get("a",d.a)))
	return d

## ── 1. create_curve ──────────────────────────────────────────────────────────

func _create_curve(params: Dictionary) -> Dictionary:
	var save_path: String = optional_string(params, "save_path", "")
	var curve := Curve.new()
	curve.min_value = float(params.get("min_value", 0.0))
	curve.max_value = float(params.get("max_value", 1.0))
	curve.bake_resolution = optional_int(params, "bake_resolution", 100)
	var points: Array = params.get("points", [{"x":0.0,"y":0.0},{"x":1.0,"y":1.0}])
	for pt in points:
		if pt is Dictionary:
			var x := float(pt.get("x", 0.0))
			var y := float(pt.get("y", 0.0))
			var tl := float(pt.get("tangent_left", 0.0))
			var tr := float(pt.get("tangent_right", 0.0))
			curve.add_point(Vector2(x, y), tl, tr)
	if save_path != "":
		var err := ResourceSaver.save(curve, save_path)
		if err != OK: return error_invalid_params("Failed to save Curve to '%s'" % save_path)
		return success({"saved_path": save_path, "point_count": curve.point_count})
	return success({"point_count": curve.point_count, "note": "Curve created in memory; provide save_path to persist"})

## ── 2. create_gradient ───────────────────────────────────────────────────────

func _create_gradient(params: Dictionary) -> Dictionary:
	var save_path: String = optional_string(params, "save_path", "")
	var grad := Gradient.new()
	var interp_str: String = optional_string(params, "interpolation", "linear")
	match interp_str:
		"constant": grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		"cubic":    grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
		_:          grad.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	var stops: Array = params.get("stops", [])
	if not stops.is_empty():
		var offsets := PackedFloat32Array()
		var colors := PackedColorArray()
		for s in stops:
			if s is Dictionary:
				offsets.append(float(s.get("offset", 0.0)))
				colors.append(_col(s, "color", Color.WHITE))
		grad.offsets = offsets
		grad.colors = colors
	if save_path != "":
		var err := ResourceSaver.save(grad, save_path)
		if err != OK: return error_invalid_params("Failed to save Gradient to '%s'" % save_path)
		return success({"saved_path": save_path, "stop_count": grad.offsets.size()})
	return success({"stop_count": grad.offsets.size(), "note": "Gradient created in memory; provide save_path to persist"})

## ── 3. create_noise_texture ──────────────────────────────────────────────────

func _create_noise_texture(params: Dictionary) -> Dictionary:
	var save_path: String = optional_string(params, "save_path", "")
	var noise := FastNoiseLite.new()
	var type_str: String = optional_string(params, "noise_type", "simplex_smooth")
	match type_str:
		"simplex":        noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		"value":          noise.noise_type = FastNoiseLite.TYPE_VALUE
		"value_cubic":    noise.noise_type = FastNoiseLite.TYPE_VALUE_CUBIC
		"perlin":         noise.noise_type = FastNoiseLite.TYPE_PERLIN
		"cellular":       noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		_:                noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = float(params.get("frequency", 0.01))
	noise.fractal_octaves = optional_int(params, "octaves", 5)
	noise.fractal_gain = float(params.get("gain", 0.5))
	noise.fractal_lacunarity = float(params.get("lacunarity", 2.0))
	noise.seed = optional_int(params, "seed", 0)
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.width  = optional_int(params, "width",  256)
	tex.height = optional_int(params, "height", 256)
	tex.seamless = optional_bool(params, "seamless", false)
	tex.as_normal_map = optional_bool(params, "as_normal_map", false)
	if save_path != "":
		var err := ResourceSaver.save(tex, save_path)
		if err != OK: return error_invalid_params("Failed to save NoiseTexture2D to '%s'" % save_path)
		return success({"saved_path": save_path, "size": {"w": tex.width, "h": tex.height}})
	return success({"size": {"w": tex.width, "h": tex.height}, "note": "Texture created in memory; provide save_path to persist"})

## ── 4. create_physics_material ───────────────────────────────────────────────

func _create_physics_material(params: Dictionary) -> Dictionary:
	var save_path: String = optional_string(params, "save_path", "")
	var mat := PhysicsMaterial.new()
	mat.friction   = float(params.get("friction", 1.0))
	mat.rough      = optional_bool(params, "rough", false)
	mat.bounce     = float(params.get("bounce", 0.0))
	mat.absorbent  = optional_bool(params, "absorbent", false)
	if save_path != "":
		var err := ResourceSaver.save(mat, save_path)
		if err != OK: return error_invalid_params("Failed to save PhysicsMaterial")
		return success({"saved_path": save_path, "friction": mat.friction, "bounce": mat.bounce})
	return success({"friction": mat.friction, "bounce": mat.bounce, "note": "Provide save_path to persist"})

## ── 5. create_label_settings ─────────────────────────────────────────────────

func _create_label_settings(params: Dictionary) -> Dictionary:
	var save_path: String = optional_string(params, "save_path", "")
	var ls := LabelSettings.new()
	ls.font_size   = optional_int(params, "font_size", 16)
	ls.font_color  = _col(params, "font_color", Color.WHITE)
	ls.outline_size  = optional_int(params, "outline_size", 0)
	ls.outline_color = _col(params, "outline_color", Color.BLACK)
	ls.shadow_size   = optional_int(params, "shadow_size", 0)
	ls.shadow_color  = _col(params, "shadow_color", Color(0,0,0,0.5))
	ls.shadow_offset = Vector2(float(params.get("shadow_offset_x",1.0)), float(params.get("shadow_offset_y",1.0)))
	if params.has("font"):
		var fp: String = str(params["font"])
		if ResourceLoader.exists(fp): ls.font = load(fp)
	ls.line_spacing = float(params.get("line_spacing", 3.0))
	if save_path != "":
		var err := ResourceSaver.save(ls, save_path)
		if err != OK: return error_invalid_params("Failed to save LabelSettings")
		return success({"saved_path": save_path})
	return success({"font_size": ls.font_size, "note": "Provide save_path to persist"})

## ── 6. create_mesh_library ───────────────────────────────────────────────────

func _create_mesh_library(params: Dictionary) -> Dictionary:
	var save_path: String = require_string(params, "save_path")[0]
	if save_path == "": return error_invalid_params("save_path is required for MeshLibrary")
	var lib := MeshLibrary.new()
	var items: Array = params.get("items", [])
	for item in items:
		if not item is Dictionary: continue
		var id: int = lib.get_last_unused_item_id()
		lib.create_item(id)
		lib.set_item_name(id, str(item.get("name", "Item%d" % id)))
		if item.has("mesh"):
			var mp: String = str(item["mesh"])
			if ResourceLoader.exists(mp): lib.set_item_mesh(id, load(mp))
	var err := ResourceSaver.save(lib, save_path)
	if err != OK: return error_invalid_params("Failed to save MeshLibrary to '%s'" % save_path)
	return success({"saved_path": save_path, "item_count": lib.get_item_list().size()})

## ── 7. list_animation_libraries ──────────────────────────────────────────────

func _list_animation_libraries(params: Dictionary) -> Dictionary:
	var res := require_string(params, "node_path")
	if res[1] != null: return res[1]
	var node := find_node_by_path(res[0])
	if node == null: return error_not_found("Node '%s'" % res[0])
	if not node is AnimationPlayer and not node is AnimationMixer:
		return error_invalid_params("Node must be AnimationPlayer or AnimationMixer")
	var libs: Array = []
	for lib_name in node.get_animation_library_list():
		var lib: AnimationLibrary = node.get_animation_library(lib_name)
		var anim_names: Array = []
		for anim_name in lib.get_animation_list():
			anim_names.append(anim_name)
		libs.append({"library": lib_name, "animations": anim_names})
	return success({"libraries": libs})

## ── 8. create_animation_library ──────────────────────────────────────────────

func _create_animation_library(params: Dictionary) -> Dictionary:
	var np_res := require_string(params, "node_path")
	if np_res[1] != null: return np_res[1]
	var node := find_node_by_path(np_res[0])
	if node == null: return error_not_found("Node '%s'" % np_res[0])
	if not node is AnimationPlayer and not node is AnimationMixer:
		return error_invalid_params("Node must be AnimationPlayer or AnimationMixer")
	var lib_name: String = optional_string(params, "library_name", "MyLibrary")
	var save_path: String = optional_string(params, "save_path", "")
	if node.has_animation_library(lib_name):
		return error_invalid_params("Library '%s' already exists on this player" % lib_name)
	var lib := AnimationLibrary.new()
	if save_path != "":
		var err := ResourceSaver.save(lib, save_path)
		if err != OK: return error_invalid_params("Failed to save AnimationLibrary")
		lib = load(save_path)
	node.add_animation_library(lib_name, lib)
	return success({"library_name": lib_name, "saved_path": save_path if save_path != "" else "in_memory"})

## ── 9. add_animation_to_library ──────────────────────────────────────────────

func _add_animation_to_library(params: Dictionary) -> Dictionary:
	var np_res := require_string(params, "node_path")
	if np_res[1] != null: return np_res[1]
	var node := find_node_by_path(np_res[0])
	if node == null: return error_not_found("Node '%s'" % np_res[0])
	if not node is AnimationPlayer and not node is AnimationMixer:
		return error_invalid_params("Node must be AnimationPlayer or AnimationMixer")
	var anim_name: String = optional_string(params, "animation_name", "")
	var lib_name: String  = optional_string(params, "library_name", "")
	if anim_name == "": return error_invalid_params("animation_name is required")
	if lib_name  == "": return error_invalid_params("library_name is required")
	if not node.has_animation_library(lib_name):
		return error_not_found("Library '%s' not found on player" % lib_name)
	# Fetch animation from global library "" or another specified source library
	var src_lib: String = optional_string(params, "source_library", "")
	if not node.has_animation_library(src_lib):
		return error_not_found("Source library '%s' not found" % src_lib)
	var src: AnimationLibrary = node.get_animation_library(src_lib)
	if not src.has_animation(anim_name):
		return error_not_found("Animation '%s' not found in source library '%s'" % [anim_name, src_lib])
	var anim: Animation = src.get_animation(anim_name)
	var dest: AnimationLibrary = node.get_animation_library(lib_name)
	dest.add_animation(anim_name, anim)
	src.remove_animation(anim_name)
	return success({"moved": anim_name, "from": src_lib, "to": lib_name})

## ── 10. setup_compositor ─────────────────────────────────────────────────────

func _setup_compositor(params: Dictionary) -> Dictionary:
	var target_path: String = optional_string(params, "target_node", "")
	var save_path: String   = optional_string(params, "save_path", "")
	if not ClassDB.class_exists("Compositor"):
		return error_invalid_params("Compositor requires Godot 4.3+")
	var comp = ClassDB.instantiate("Compositor")
	if save_path != "":
		var err := ResourceSaver.save(comp, save_path)
		if err != OK: return error_invalid_params("Failed to save Compositor to '%s'" % save_path)
		comp = load(save_path)
	if target_path != "":
		var target := find_node_by_path(target_path)
		if target == null: return error_not_found("Target node '%s'" % target_path)
		target.set("compositor", comp)
		return success({"assigned_to": target_path, "saved_path": save_path if save_path != "" else "in_memory"})
	return success({"note": "Compositor created; provide target_node to assign to Camera3D or WorldEnvironment", "saved_path": save_path if save_path != "" else "in_memory"})


## ── read_resource ─────────────────────────────────────────────────────────────

func _read_resource(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Resource '%s'" % path)

	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		return error_internal("Failed to load resource: %s" % path)

	var props: Dictionary = {}
	for prop_info in resource.get_property_list():
		var prop_name: String = prop_info["name"]
		var usage: int = prop_info["usage"]
		if not (usage & PROPERTY_USAGE_EDITOR):
			continue
		if prop_name.begins_with("_") or prop_name == "script" or prop_name == "resource_local_to_scene" or prop_name == "resource_name" or prop_name == "resource_path":
			continue
		props[prop_name] = PropertyParser.serialize_value(resource.get(prop_name))

	return success({
		"path": path,
		"type": resource.get_class(),
		"resource_name": resource.resource_name,
		"properties": props,
	})


## ── edit_resource ────────────────────────────────────────────────────────────

func _edit_resource(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not params.has("properties") or not params["properties"] is Dictionary:
		return error_invalid_params("'properties' dictionary is required")
	var new_props: Dictionary = params["properties"]

	if not FileAccess.file_exists(path):
		return error_not_found("Resource '%s'" % path)

	var resource: Resource = ResourceLoader.load(path)
	if resource == null:
		return error_internal("Failed to load resource: %s" % path)

	var changed: Dictionary = {}
	for prop_name: String in new_props:
		if not prop_name in resource:
			continue
		var old_value: Variant = resource.get(prop_name)
		var target_type := typeof(old_value)
		var new_value: Variant = PropertyParser.parse_value(new_props[prop_name], target_type)
		resource.set(prop_name, new_value)
		changed[prop_name] = {
			"old": PropertyParser.serialize_value(old_value),
			"new": PropertyParser.serialize_value(resource.get(prop_name)),
		}

	if changed.is_empty():
		return success({"path": path, "changed": {}, "message": "No properties were changed"})

	var err := ResourceSaver.save(resource, path)
	if err != OK:
		return error_internal("Failed to save resource: %s" % error_string(err))

	return success({
		"path": path,
		"type": resource.get_class(),
		"changed": changed,
	})


## ── create_resource ──────────────────────────────────────────────────────────

func _create_resource(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	var result2 := require_string(params, "type")
	if result2[1] != null:
		return result2[1]
	var resource_type: String = result2[0]

	if not ClassDB.class_exists(resource_type):
		return error_invalid_params("Unknown resource type: %s" % resource_type)
	if not ClassDB.is_parent_class(resource_type, "Resource"):
		return error_invalid_params("'%s' is not a Resource type" % resource_type)

	var overwrite: bool = optional_bool(params, "overwrite", false)
	if FileAccess.file_exists(path) and not overwrite:
		return error(-32000, "Resource already exists: %s" % path, {"suggestion": "Set overwrite=true to replace"})

	var resource: Resource = ClassDB.instantiate(resource_type)
	if resource == null:
		return error_internal("Failed to instantiate: %s" % resource_type)

	# Apply properties
	var properties: Dictionary = params.get("properties", {})
	for prop_name: String in properties:
		if prop_name in resource:
			var current := resource.get(prop_name)
			resource.set(prop_name, PropertyParser.parse_value(properties[prop_name], typeof(current)))

	var err := ResourceSaver.save(resource, path)
	if err != OK:
		return error_internal("Failed to save resource: %s" % error_string(err))

	# Rescan filesystem
	get_editor().get_resource_filesystem().scan()

	return success({
		"path": path,
		"type": resource_type,
		"properties_set": properties.keys(),
	})


## ── get_resource_preview ─────────────────────────────────────────────────────

func _get_resource_preview(params: Dictionary) -> Dictionary:
	var result := require_string(params, "path")
	if result[1] != null:
		return result[1]
	var path: String = result[0]

	if not FileAccess.file_exists(path):
		return error_not_found("Resource '%s'" % path)

	var max_size: int = optional_int(params, "max_size", 256)
	var image: Image = null

	# Try loading as image file directly
	var ext := path.get_extension().to_lower()
	if ext in ["png", "jpg", "jpeg", "bmp", "webp", "svg"]:
		image = Image.new()
		var err := image.load(path)
		if err != OK:
			return error_internal("Failed to load image: %s" % error_string(err))
	else:
		# Try loading as resource and extracting image
		var resource: Resource = ResourceLoader.load(path)
		if resource == null:
			return error_internal("Failed to load resource: %s" % path)

		if resource is Texture2D:
			image = (resource as Texture2D).get_image()
		elif resource is Image:
			image = resource as Image
		else:
			return error_invalid_params("Resource type '%s' does not have an image preview" % resource.get_class())

	if image == null:
		return error_internal("Could not extract image from resource")

	# Resize if needed
	if image.get_width() > max_size or image.get_height() > max_size:
		var scale_x := float(max_size) / float(image.get_width())
		var scale_y := float(max_size) / float(image.get_height())
		var scale := minf(scale_x, scale_y)
		var new_w := int(image.get_width() * scale)
		var new_h := int(image.get_height() * scale)
		image.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)

	var png_buffer := image.save_png_to_buffer()
	var base64 := Marshalls.raw_to_base64(png_buffer)

	return success({
		"image_base64": base64,
		"width": image.get_width(),
		"height": image.get_height(),
		"format": "png",
		"path": path,
	})
