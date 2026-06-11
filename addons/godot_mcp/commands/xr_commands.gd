@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## Tier 5: XR rigs, OpenXR, WebRTC, ClassDB query, XML parsing, ZIP I/O

func get_commands() -> Dictionary:
	return {
		"setup_xr_rig":             _setup_xr_rig,
		"setup_openxr_hand":        _setup_openxr_hand,
		"get_xr_interfaces":        _get_xr_interfaces,
		"setup_xr_body_modifier":   _setup_xr_body_modifier,
		"setup_webrtc_peer":        _setup_webrtc_peer,
		"setup_webrtc_multiplayer": _setup_webrtc_multiplayer,
		"query_class_db":           _query_class_db,
		"parse_xml":                _parse_xml,
		"zip_pack":                 _zip_pack,
		"zip_read":                 _zip_read,
	}

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

## ── 1. setup_xr_rig ──────────────────────────────────────────────────────────

func _setup_xr_rig(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("XROrigin3D"):
		return error_invalid_params("XR nodes require the XR module (Godot 4.x with OpenXR plugin)")

	var origin = ClassDB.instantiate("XROrigin3D")
	origin.name = optional_string(params, "name", "XROrigin3D")
	_add(origin, parent, root, "MCP: Add XR Rig")

	var added: Array = [str(root.get_path_to(origin))]

	# Camera
	if optional_bool(params, "add_camera", true):
		var cam = ClassDB.instantiate("XRCamera3D")
		cam.name = "XRCamera3D"
		origin.add_child(cam)
		cam.owner = root
		added.append(str(root.get_path_to(cam)))

	# Left controller
	if optional_bool(params, "add_left_controller", true):
		var lc = ClassDB.instantiate("XRController3D")
		lc.name = "LeftController"
		lc.set("tracker", "/user/hand/left")
		lc.set("pose", "grip")
		origin.add_child(lc)
		lc.owner = root
		added.append(str(root.get_path_to(lc)))

	# Right controller
	if optional_bool(params, "add_right_controller", true):
		var rc = ClassDB.instantiate("XRController3D")
		rc.name = "RightController"
		rc.set("tracker", "/user/hand/right")
		rc.set("pose", "grip")
		origin.add_child(rc)
		rc.owner = root
		added.append(str(root.get_path_to(rc)))

	return success({"origin_path": str(root.get_path_to(origin)), "nodes_added": added})

## ── 2. setup_openxr_hand ─────────────────────────────────────────────────────

func _setup_openxr_hand(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("OpenXRHand"):
		return error_invalid_params("OpenXRHand requires the OpenXR plugin")
	var hand = ClassDB.instantiate("OpenXRHand")
	hand.name = optional_string(params, "name", "OpenXRHand")
	var hand_str: String = optional_string(params, "hand", "left")
	# HAND_LEFT = 0, HAND_RIGHT = 1
	hand.set("hand", 0 if hand_str == "left" else 1)
	var motion_range: String = optional_string(params, "motion_range", "unobstructed")
	# MOTION_RANGE_UNOBSTRUCTED = 0, MOTION_RANGE_CONFORM_TO_CONTROLLER = 1
	hand.set("motion_range", 0 if motion_range == "unobstructed" else 1)
	if params.has("hand_skeleton"):
		hand.set("hand_skeleton", NodePath(str(params["hand_skeleton"])))
	_add(hand, parent, root, "MCP: Add OpenXRHand")
	return success({"node_path": str(root.get_path_to(hand)), "hand": hand_str})

## ── 3. get_xr_interfaces ─────────────────────────────────────────────────────

func _get_xr_interfaces(_params: Dictionary) -> Dictionary:
	var server := XRServer
	var count := server.get_interface_count()
	var interfaces: Array = []
	for i in range(count):
		var iface := server.get_interface(i)
		if iface == null: continue
		interfaces.append({
			"name":            iface.get_name(),
			"is_initialized":  iface.is_initialized(),
			"is_primary":      iface == server.primary_interface,
			"tracking_status": str(iface.get_tracking_status()),
		})
	return success({"interface_count": count, "interfaces": interfaces})

## ── 4. setup_xr_body_modifier ────────────────────────────────────────────────

func _setup_xr_body_modifier(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("XRBodyModifier3D"):
		return error_invalid_params("XRBodyModifier3D requires Godot 4.2+ with XR body tracking")
	var mod = ClassDB.instantiate("XRBodyModifier3D")
	mod.name = optional_string(params, "name", "XRBodyModifier3D")
	if params.has("body_tracker"):
		mod.set("body_tracker", str(params["body_tracker"]))
	_add(mod, parent, root, "MCP: Add XRBodyModifier3D")
	return success({"node_path": str(root.get_path_to(mod))})

## ── 5. setup_webrtc_peer ─────────────────────────────────────────────────────

func _setup_webrtc_peer(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("WebRTCPeerConnection"):
		return error_invalid_params("WebRTCPeerConnection requires the WebRTC GDExtension or Godot build with WebRTC")
	var peer = ClassDB.instantiate("WebRTCPeerConnection")
	peer.name = optional_string(params, "name", "WebRTCPeerConnection")
	# Build ICE server config from params
	var ice_servers: Array = params.get("ice_servers", [
		{"urls": ["stun:stun.l.google.com:19302"]}
	])
	var cfg := {"iceServers": ice_servers}
	peer.call("initialize", cfg)
	_add(peer, parent, root, "MCP: Add WebRTCPeerConnection")
	return success({"node_path": str(root.get_path_to(peer)), "ice_servers": ice_servers.size()})

## ── 6. setup_webrtc_multiplayer ──────────────────────────────────────────────

func _setup_webrtc_multiplayer(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	if not ClassDB.class_exists("WebRTCMultiplayerPeer"):
		return error_invalid_params("WebRTCMultiplayerPeer requires the WebRTC GDExtension")
	var mp = ClassDB.instantiate("WebRTCMultiplayerPeer")
	mp.name = optional_string(params, "name", "WebRTCMultiplayerPeer")
	# Optionally configure as server or client in a script (can't finalize mesh without live peers)
	_add(mp, parent, root, "MCP: Add WebRTCMultiplayerPeer")
	return success({
		"node_path": str(root.get_path_to(mp)),
		"note": "Call create_server() or create_client() from a script after attaching peers"
	})

## ── 7. query_class_db ────────────────────────────────────────────────────────

func _query_class_db(params: Dictionary) -> Dictionary:
	var class_name_str: String = optional_string(params, "class_name", "")
	var query: String = optional_string(params, "query", "info")  # info | methods | properties | signals | constants | inherits

	if class_name_str == "":
		# Return all class names
		var all_classes := ClassDB.get_class_list()
		all_classes.sort()
		var filtered: Array = []
		var filter: String = optional_string(params, "filter", "")
		for cn in all_classes:
			if filter == "" or str(cn).to_lower().contains(filter.to_lower()):
				filtered.append(cn)
		return success({"class_count": filtered.size(), "classes": filtered.slice(0, 200)})

	if not ClassDB.class_exists(class_name_str):
		return error_not_found("Class '%s' not found in ClassDB" % class_name_str)

	match query:
		"methods":
			var methods := ClassDB.class_get_method_list(class_name_str, true)
			var names: Array = []
			for m in methods:
				if m is Dictionary: names.append(str(m.get("name", "")))
			names.sort()
			return success({"class": class_name_str, "methods": names})
		"properties":
			var props := ClassDB.class_get_property_list(class_name_str, true)
			var result: Array = []
			for p in props:
				if p is Dictionary and int(p.get("usage", 0)) & PROPERTY_USAGE_EDITOR:
					result.append({"name": str(p.get("name", "")), "type": type_string(int(p.get("type", 0)))})
			result.sort_custom(func(a, b): return a["name"] < b["name"])
			return success({"class": class_name_str, "properties": result})
		"signals":
			var sigs := ClassDB.class_get_signal_list(class_name_str, true)
			var names: Array = []
			for s in sigs:
				if s is Dictionary: names.append(str(s.get("name", "")))
			names.sort()
			return success({"class": class_name_str, "signals": names})
		"constants":
			var consts := ClassDB.class_get_integer_constant_list(class_name_str, true)
			var result: Dictionary = {}
			for c in consts:
				result[str(c)] = ClassDB.class_get_integer_constant(class_name_str, str(c))
			return success({"class": class_name_str, "constants": result})
		"inherits":
			var chain: Array = [class_name_str]
			var current := class_name_str
			while ClassDB.get_parent_class(current) != "":
				current = ClassDB.get_parent_class(current)
				chain.append(current)
			return success({"class": class_name_str, "inheritance_chain": chain})
		_:
			return success({
				"class":          class_name_str,
				"parent":         ClassDB.get_parent_class(class_name_str),
				"is_instantiatable": ClassDB.can_instantiate(class_name_str),
				"method_count":   ClassDB.class_get_method_list(class_name_str, true).size(),
				"property_count": ClassDB.class_get_property_list(class_name_str, true).size(),
				"signal_count":   ClassDB.class_get_signal_list(class_name_str, true).size(),
			})

## ── 8. parse_xml ─────────────────────────────────────────────────────────────

func _parse_xml(params: Dictionary) -> Dictionary:
	var file_path: String = optional_string(params, "file_path", "")
	var xml_string: String = optional_string(params, "xml_string", "")
	if file_path == "" and xml_string == "":
		return error_invalid_params("Provide file_path (res:// path) or xml_string")

	var parser := XMLParser.new()
	var err: int
	if file_path != "":
		err = parser.open(file_path)
	else:
		err = parser.open_buffer(xml_string.to_utf8_buffer())
	if err != OK:
		return error_invalid_params("Failed to open XML: error %d" % err)

	var nodes: Array = []
	var max_nodes: int = optional_int(params, "max_nodes", 200)

	while parser.read() == OK and nodes.size() < max_nodes:
		var node_type := parser.get_node_type()
		match node_type:
			XMLParser.NODE_ELEMENT:
				var attrs: Dictionary = {}
				for i in range(parser.get_attribute_count()):
					attrs[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
				nodes.append({"type": "element", "name": parser.get_node_name(), "attributes": attrs})
			XMLParser.NODE_TEXT:
				var txt := parser.get_node_data().strip_edges()
				if txt != "":
					nodes.append({"type": "text", "content": txt})
			XMLParser.NODE_ELEMENT_END:
				nodes.append({"type": "element_end", "name": parser.get_node_name()})

	return success({"node_count": nodes.size(), "nodes": nodes, "truncated": nodes.size() >= max_nodes})

## ── 9. zip_pack ──────────────────────────────────────────────────────────────

func _zip_pack(params: Dictionary) -> Dictionary:
	var zip_path: String = optional_string(params, "zip_path", "")
	if zip_path == "": return error_invalid_params("zip_path is required (e.g. user://export.zip)")
	var files: Array = params.get("files", [])
	if files.is_empty(): return error_invalid_params("files array is required")

	var packer := ZIPPacker.new()
	var err := packer.open(zip_path)
	if err != OK: return error_invalid_params("Failed to create ZIP at '%s': error %d" % [zip_path, err])

	var packed: Array = []
	var failed: Array = []
	for f in files:
		var src: String = str(f)
		if not FileAccess.file_exists(src):
			failed.append(src)
			continue
		var fa := FileAccess.open(src, FileAccess.READ)
		if fa == null:
			failed.append(src)
			continue
		var data := fa.get_buffer(fa.get_length())
		fa.close()
		var entry_name: String = src.get_file()
		packer.start_file(entry_name)
		packer.write_file(data)
		packer.close_file()
		packed.append(entry_name)

	packer.close()
	return success({"zip_path": zip_path, "packed": packed, "failed": failed})

## ── 10. zip_read ─────────────────────────────────────────────────────────────

func _zip_read(params: Dictionary) -> Dictionary:
	var zip_path: String = optional_string(params, "zip_path", "")
	if zip_path == "": return error_invalid_params("zip_path is required")
	if not FileAccess.file_exists(zip_path):
		return error_not_found("ZIP file '%s' not found" % zip_path)

	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK: return error_invalid_params("Failed to open ZIP '%s': error %d" % [zip_path, err])

	var files := reader.get_files()
	var extract_to: String = optional_string(params, "extract_to", "")
	var extracted: Array = []

	if extract_to != "":
		DirAccess.make_dir_recursive_absolute(extract_to)
		var max_extract: int = optional_int(params, "max_files", 50)
		var extract_to_abs := ProjectSettings.globalize_path(extract_to)
		for i in range(min(files.size(), max_extract)):
			var fname: String = files[i]
			if fname.is_absolute_path() or fname.contains(".."):
				continue  # zip-slip protection: reject absolute paths and parent traversal
			var data := reader.read_file(fname)
			var dest: String = extract_to.path_join(fname)
			var dest_abs := ProjectSettings.globalize_path(dest)
			if not dest_abs.begins_with(extract_to_abs):
				continue  # zip-slip protection: stay within extract_to
			DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
			var fa := FileAccess.open(dest, FileAccess.WRITE)
			if fa != null:
				fa.store_buffer(data)
				fa.close()
				extracted.append(dest)

	reader.close()
	return success({"zip_path": zip_path, "file_count": files.size(), "files": Array(files), "extracted": extracted})
