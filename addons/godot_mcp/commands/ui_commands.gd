@tool
extends "res://addons/godot_mcp/commands/base_command.gd"

## UI Control node setup: Label, Label3D, Button variants, LineEdit, ProgressBar, RichTextLabel, Containers

func get_commands() -> Dictionary:
	return {
		"setup_label":            _setup_label,
		"setup_label_3d":         _setup_label_3d,
		"setup_button":           _setup_button,
		"setup_line_edit":        _setup_line_edit,
		"setup_progress_bar":     _setup_progress_bar,
		"setup_rich_text_label":  _setup_rich_text_label,
		"setup_vbox_container":   _setup_vbox_container,
		"setup_hbox_container":   _setup_hbox_container,
		"setup_grid_container":   _setup_grid_container,
		"setup_panel_container":  _setup_panel_container,
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
	if v is Dictionary: return Color(float(v.get("r",d.r)), float(v.get("g",d.g)), float(v.get("b",d.b)), float(v.get("a",d.a)))
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

func _apply_anchor_preset(ctrl: Control, preset: String) -> void:
	match preset:
		"full_rect":    ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		"top_left":     ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		"top_right":    ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		"bottom_left":  ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
		"bottom_right": ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		"center":       ctrl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		"top_wide":     ctrl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		"bottom_wide":  ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		"left_wide":    ctrl.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		"right_wide":   ctrl.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)

func _apply_halign(node, val: String) -> void:
	match val:
		"left":   node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		"right":  node.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		"fill":   node.horizontal_alignment = HORIZONTAL_ALIGNMENT_FILL
		_:        node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _apply_valign(node, val: String) -> void:
	match val:
		"top":    node.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		"bottom": node.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		"fill":   node.vertical_alignment = VERTICAL_ALIGNMENT_FILL
		_:        node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

## ── 1. setup_label ───────────────────────────────────────────────────────────

func _setup_label(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var lbl := Label.new()
	lbl.name = optional_string(params, "name", "Label")
	lbl.text = optional_string(params, "text", "Label")
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if optional_bool(params, "autowrap", false) else TextServer.AUTOWRAP_OFF
	_apply_halign(lbl, optional_string(params, "horizontal_alignment", "left"))
	_apply_valign(lbl, optional_string(params, "vertical_alignment", "top"))
	if params.has("custom_minimum_size"):
		lbl.custom_minimum_size = _v2(params, "custom_minimum_size", Vector2.ZERO)
	if params.has("anchor_preset"):
		_apply_anchor_preset(lbl, str(params["anchor_preset"]))
	if params.has("label_settings"):
		var lsp: String = str(params["label_settings"])
		if ResourceLoader.exists(lsp): lbl.label_settings = load(lsp)
	_add(lbl, parent, root, "MCP: Add Label")
	return success({"node_path": str(root.get_path_to(lbl))})

## ── 2. setup_label_3d ────────────────────────────────────────────────────────

func _setup_label_3d(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var lbl := Label3D.new()
	lbl.name = optional_string(params, "name", "Label3D")
	lbl.text = optional_string(params, "text", "Label3D")
	lbl.font_size = optional_int(params, "font_size", 32)
	lbl.pixel_size = float(params.get("pixel_size", 0.01))
	lbl.double_sided = optional_bool(params, "double_sided", true)
	lbl.no_depth_test = optional_bool(params, "no_depth_test", false)
	lbl.modulate = _col(params, "modulate", Color.WHITE)
	lbl.outline_size = optional_int(params, "outline_size", 0)
	lbl.outline_modulate = _col(params, "outline_color", Color.BLACK)
	if optional_bool(params, "billboard", false):
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = _v3(params, "position", Vector3.ZERO)
	_add(lbl, parent, root, "MCP: Add Label3D")
	return success({"node_path": str(root.get_path_to(lbl))})

## ── 3. setup_button ──────────────────────────────────────────────────────────

func _setup_button(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var btn_type: String = optional_string(params, "button_type", "button")
	var btn: Button
	match btn_type:
		"checkbox":     btn = CheckBox.new();     btn.name = optional_string(params, "name", "CheckBox")
		"checkbutton":  btn = CheckButton.new();  btn.name = optional_string(params, "name", "CheckButton")
		_:              btn = Button.new();        btn.name = optional_string(params, "name", "Button")
	btn.text = optional_string(params, "text", "Button")
	btn.disabled = optional_bool(params, "disabled", false)
	btn.toggle_mode = optional_bool(params, "toggle_mode", false)
	btn.button_pressed = optional_bool(params, "button_pressed", false)
	btn.flat = optional_bool(params, "flat", false)
	_apply_halign(btn, optional_string(params, "horizontal_alignment", "center"))
	if params.has("icon"):
		var ip: String = str(params["icon"])
		if ResourceLoader.exists(ip): btn.icon = load(ip)
	if params.has("custom_minimum_size"):
		btn.custom_minimum_size = _v2(params, "custom_minimum_size", Vector2.ZERO)
	if params.has("anchor_preset"):
		_apply_anchor_preset(btn, str(params["anchor_preset"]))
	_add(btn, parent, root, "MCP: Add Button")
	return success({"node_path": str(root.get_path_to(btn)), "button_type": btn_type})

## ── 4. setup_line_edit ───────────────────────────────────────────────────────

func _setup_line_edit(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var le := LineEdit.new()
	le.name = optional_string(params, "name", "LineEdit")
	le.text = optional_string(params, "text", "")
	le.placeholder_text = optional_string(params, "placeholder_text", "")
	le.max_length = optional_int(params, "max_length", 0)
	le.secret = optional_bool(params, "secret", false)
	le.editable = optional_bool(params, "editable", true)
	le.clear_button_enabled = optional_bool(params, "clear_button_enabled", false)
	_apply_halign(le, optional_string(params, "alignment", "left"))
	if params.has("custom_minimum_size"):
		le.custom_minimum_size = _v2(params, "custom_minimum_size", Vector2.ZERO)
	if params.has("anchor_preset"):
		_apply_anchor_preset(le, str(params["anchor_preset"]))
	_add(le, parent, root, "MCP: Add LineEdit")
	return success({"node_path": str(root.get_path_to(le))})

## ── 5. setup_progress_bar ────────────────────────────────────────────────────

func _setup_progress_bar(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var pb := ProgressBar.new()
	pb.name = optional_string(params, "name", "ProgressBar")
	pb.min_value = float(params.get("min_value", 0.0))
	pb.max_value = float(params.get("max_value", 100.0))
	pb.value     = float(params.get("value", 0.0))
	pb.step      = float(params.get("step", 1.0))
	pb.show_percentage = optional_bool(params, "show_percentage", true)
	var fill_str: String = optional_string(params, "fill_mode", "begin_to_end")
	match fill_str:
		"end_to_begin": pb.fill_mode = ProgressBar.FILL_END_TO_BEGIN
		"top_to_bottom": pb.fill_mode = ProgressBar.FILL_TOP_TO_BOTTOM
		"bottom_to_top": pb.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		_: pb.fill_mode = ProgressBar.FILL_BEGIN_TO_END
	if params.has("custom_minimum_size"):
		pb.custom_minimum_size = _v2(params, "custom_minimum_size", Vector2.ZERO)
	if params.has("anchor_preset"):
		_apply_anchor_preset(pb, str(params["anchor_preset"]))
	_add(pb, parent, root, "MCP: Add ProgressBar")
	return success({"node_path": str(root.get_path_to(pb)), "value": pb.value, "max_value": pb.max_value})

## ── 6. setup_rich_text_label ─────────────────────────────────────────────────

func _setup_rich_text_label(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var rtl := RichTextLabel.new()
	rtl.name = optional_string(params, "name", "RichTextLabel")
	rtl.bbcode_enabled = optional_bool(params, "bbcode_enabled", true)
	rtl.text = optional_string(params, "text", "")
	rtl.fit_content = optional_bool(params, "fit_content", false)
	rtl.scroll_active = optional_bool(params, "scroll_active", true)
	rtl.selection_enabled = optional_bool(params, "selection_enabled", false)
	if params.has("custom_minimum_size"):
		rtl.custom_minimum_size = _v2(params, "custom_minimum_size", Vector2.ZERO)
	if params.has("anchor_preset"):
		_apply_anchor_preset(rtl, str(params["anchor_preset"]))
	_add(rtl, parent, root, "MCP: Add RichTextLabel")
	return success({"node_path": str(root.get_path_to(rtl))})

## ── 7. setup_vbox_container ──────────────────────────────────────────────────

func _setup_vbox_container(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var vb := VBoxContainer.new()
	vb.name = optional_string(params, "name", "VBoxContainer")
	vb.add_theme_constant_override("separation", optional_int(params, "separation", 4))
	if params.has("custom_minimum_size"):
		vb.custom_minimum_size = _v2(params, "custom_minimum_size", Vector2.ZERO)
	if params.has("anchor_preset"):
		_apply_anchor_preset(vb, str(params["anchor_preset"]))
	_add(vb, parent, root, "MCP: Add VBoxContainer")
	return success({"node_path": str(root.get_path_to(vb))})

## ── 8. setup_hbox_container ──────────────────────────────────────────────────

func _setup_hbox_container(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var hb := HBoxContainer.new()
	hb.name = optional_string(params, "name", "HBoxContainer")
	hb.add_theme_constant_override("separation", optional_int(params, "separation", 4))
	if params.has("custom_minimum_size"):
		hb.custom_minimum_size = _v2(params, "custom_minimum_size", Vector2.ZERO)
	if params.has("anchor_preset"):
		_apply_anchor_preset(hb, str(params["anchor_preset"]))
	_add(hb, parent, root, "MCP: Add HBoxContainer")
	return success({"node_path": str(root.get_path_to(hb))})

## ── 9. setup_grid_container ──────────────────────────────────────────────────

func _setup_grid_container(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var gc := GridContainer.new()
	gc.name = optional_string(params, "name", "GridContainer")
	gc.columns = optional_int(params, "columns", 2)
	gc.add_theme_constant_override("h_separation", optional_int(params, "h_separation", 4))
	gc.add_theme_constant_override("v_separation", optional_int(params, "v_separation", 4))
	if params.has("custom_minimum_size"):
		gc.custom_minimum_size = _v2(params, "custom_minimum_size", Vector2.ZERO)
	if params.has("anchor_preset"):
		_apply_anchor_preset(gc, str(params["anchor_preset"]))
	_add(gc, parent, root, "MCP: Add GridContainer")
	return success({"node_path": str(root.get_path_to(gc)), "columns": gc.columns})

## ── 10. setup_panel_container ─────────────────────────────────────────────────

func _setup_panel_container(params: Dictionary) -> Dictionary:
	var a := _pr(params); if a[2]: return a[2]
	var parent: Node = a[0]; var root: Node = a[1]
	var pc := PanelContainer.new()
	pc.name = optional_string(params, "name", "PanelContainer")
	if params.has("custom_minimum_size"):
		pc.custom_minimum_size = _v2(params, "custom_minimum_size", Vector2.ZERO)
	if params.has("anchor_preset"):
		_apply_anchor_preset(pc, str(params["anchor_preset"]))
	_add(pc, parent, root, "MCP: Add PanelContainer")
	return success({"node_path": str(root.get_path_to(pc))})
