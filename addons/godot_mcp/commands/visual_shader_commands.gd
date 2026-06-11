@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

func get_commands() -> Dictionary:
	return {
		"create_visual_shader":          _create_visual_shader,
		"add_visual_shader_node":        _add_visual_shader_node,
		"connect_visual_shader_nodes":   _connect_visual_shader_nodes,
		"set_visual_shader_node_param":  _set_visual_shader_node_param,
		"get_visual_shader_graph":       _get_visual_shader_graph,
		"remove_visual_shader_node":     _remove_visual_shader_node,
		"set_visual_shader_mode":        _set_visual_shader_mode,
		"preview_visual_shader":         _preview_visual_shader,
	}

func _load_vs(params: Dictionary) -> Array:
	var res := require_string(params,"shader_path"); if res[1]: return [null,res[1]]
	var path: String = res[0]
	if not ResourceLoader.exists(path): return [null,error_not_found("Shader '%s'" % path)]
	var r: Resource = load(path)
	if not r is VisualShader: return [null,error_invalid_params("Resource is not a VisualShader")]
	return [r as VisualShader, null]

## 1. create_visual_shader
func _create_visual_shader(params: Dictionary) -> Dictionary:
	var vs := VisualShader.new()
	var mode_str: String = optional_string(params,"mode","spatial")
	match mode_str.to_lower():
		"canvas_item","2d": vs.mode = Shader.MODE_CANVAS_ITEM
		"particles":        vs.mode = Shader.MODE_PARTICLES
		"sky":              vs.mode = Shader.MODE_SKY
		_:                  vs.mode = Shader.MODE_SPATIAL
	var save_path: String = optional_string(params,"save_path","res://new_visual_shader.tres")
	var err := ResourceSaver.save(vs, save_path)
	if err != OK: return error_internal("Failed to save VisualShader: %s" % error_string(err))
	return success({"path":save_path,"mode":mode_str})

## 2. add_visual_shader_node
func _add_visual_shader_node(params: Dictionary) -> Dictionary:
	var a := _load_vs(params); if a[1]: return a[1]
	var vs: VisualShader = a[0]
	var type_name: String = optional_string(params,"node_type","VisualShaderNodeVec3Constant")
	var node: VisualShaderNode
	# Instantiate by class name
	if ClassDB.class_exists(type_name) and ClassDB.is_parent_class(type_name,"VisualShaderNode"):
		node = ClassDB.instantiate(type_name)
	else:
		return error_invalid_params("Unknown VisualShaderNode type: %s" % type_name)
	var type_enum: int = VisualShader.TYPE_FRAGMENT
	var t: String = optional_string(params,"shader_type","fragment")
	match t.to_lower():
		"vertex":  type_enum = VisualShader.TYPE_VERTEX
		"light":   type_enum = VisualShader.TYPE_LIGHT
		"process": type_enum = VisualShader.TYPE_PROCESS
		_: type_enum = VisualShader.TYPE_FRAGMENT
	var id: int = vs.get_valid_node_id(type_enum)
	vs.add_node(type_enum, node, Vector2(float(params.get("x",0)),float(params.get("y",0))), id)
	ResourceSaver.save(vs, str(params["shader_path"]))
	return success({"node_id":id,"node_type":type_name,"shader_type":t})

## 3. connect_visual_shader_nodes
func _connect_visual_shader_nodes(params: Dictionary) -> Dictionary:
	var a := _load_vs(params); if a[1]: return a[1]
	var vs: VisualShader = a[0]
	var t: String = optional_string(params,"shader_type","fragment")
	var type_enum: int = VisualShader.TYPE_FRAGMENT
	match t.to_lower():
		"vertex": type_enum = VisualShader.TYPE_VERTEX
		"light":  type_enum = VisualShader.TYPE_LIGHT
	var from_id: int   = optional_int(params,"from_node",0)
	var from_port: int = optional_int(params,"from_port",0)
	var to_id: int     = optional_int(params,"to_node",0)
	var to_port: int   = optional_int(params,"to_port",0)
	var err := vs.connect_nodes(type_enum, from_id, from_port, to_id, to_port)
	if err != OK: return error_internal("connect_nodes failed: %s" % error_string(err))
	ResourceSaver.save(vs, str(params["shader_path"]))
	return success({"from_node":from_id,"from_port":from_port,"to_node":to_id,"to_port":to_port})

## 4. set_visual_shader_node_param
func _set_visual_shader_node_param(params: Dictionary) -> Dictionary:
	var a := _load_vs(params); if a[1]: return a[1]
	var vs: VisualShader = a[0]
	var t: String = optional_string(params,"shader_type","fragment")
	var type_enum: int = VisualShader.TYPE_FRAGMENT
	match t.to_lower():
		"vertex": type_enum = VisualShader.TYPE_VERTEX
	var node_id: int = optional_int(params,"node_id",0)
	var node: VisualShaderNode = vs.get_node(type_enum, node_id)
	if node == null: return error_not_found("VisualShaderNode id %d" % node_id)
	var prop: String = optional_string(params,"property","")
	if prop.is_empty(): return error_invalid_params("property is required")
	if prop in node: node.set(prop, params.get("value"))
	else: return error_invalid_params("Property '%s' not found on %s" % [prop, node.get_class()])
	ResourceSaver.save(vs, str(params["shader_path"]))
	return success({"node_id":node_id,"property":prop})

## 5. get_visual_shader_graph
func _get_visual_shader_graph(params: Dictionary) -> Dictionary:
	var a := _load_vs(params); if a[1]: return a[1]
	var vs: VisualShader = a[0]
	var result: Dictionary = {}
	for t_name in ["vertex","fragment","light"]:
		var t_map := {"vertex":VisualShader.TYPE_VERTEX,"fragment":VisualShader.TYPE_FRAGMENT,"light":VisualShader.TYPE_LIGHT}
		var type_enum: int = t_map[t_name]
		var nodes_info: Array = []
		for id in vs.get_node_list(type_enum):
			var n: VisualShaderNode = vs.get_node(type_enum, id)
			var offset: Vector2 = vs.get_node_position(type_enum, id)
			nodes_info.append({"id":id,"type":n.get_class(),"x":offset.x,"y":offset.y})
		result[t_name] = nodes_info
	return success({"graph":result})

## 6. remove_visual_shader_node
func _remove_visual_shader_node(params: Dictionary) -> Dictionary:
	var a := _load_vs(params); if a[1]: return a[1]
	var vs: VisualShader = a[0]
	var t: String = optional_string(params,"shader_type","fragment")
	var type_enum: int = VisualShader.TYPE_FRAGMENT
	match t.to_lower():
		"vertex": type_enum = VisualShader.TYPE_VERTEX
		"light": type_enum = VisualShader.TYPE_LIGHT
	var node_id: int = optional_int(params,"node_id",0)
	vs.remove_node(type_enum, node_id)
	ResourceSaver.save(vs, str(params["shader_path"]))
	return success({"removed_node_id":node_id})

## 7. set_visual_shader_mode
func _set_visual_shader_mode(params: Dictionary) -> Dictionary:
	var a := _load_vs(params); if a[1]: return a[1]
	var vs: VisualShader = a[0]
	var mode_str: String = optional_string(params,"mode","spatial")
	match mode_str.to_lower():
		"canvas_item","2d": vs.mode = Shader.MODE_CANVAS_ITEM
		"particles":        vs.mode = Shader.MODE_PARTICLES
		"sky":              vs.mode = Shader.MODE_SKY
		_:                  vs.mode = Shader.MODE_SPATIAL
	ResourceSaver.save(vs, str(params["shader_path"]))
	return success({"mode":mode_str})

## 8. preview_visual_shader
func _preview_visual_shader(params: Dictionary) -> Dictionary:
	var res := require_string(params,"node_path"); if res[1]: return res[1]
	var a := _load_vs(params); if a[1]: return a[1]
	var vs: VisualShader = a[0]
	var node := find_node_by_path(res[0])
	if node == null: return error_not_found("Node '%s'" % res[0])
	var mat := ShaderMaterial.new()
	mat.shader = vs
	if node is MeshInstance3D:   (node as MeshInstance3D).material_override = mat
	elif node is CSGShape3D:     (node as CSGShape3D).material = mat
	elif node is CanvasItem:     (node as CanvasItem).material = mat
	else: return error_invalid_params("Node does not support material assignment: %s" % node.get_class())
	return success({"node_path":res[0],"shader_path":str(params["shader_path"])})
