@tool
extends EditorPlugin

const MainPanel = preload("res://addons/gmap_viewer/main_panel.tscn")

# referencing panel
var main_panel_instance: GridContainer

# button combo to go to the "Gmap Viewer" tab, can be changed.
var main_hokey = KEY_F2 + KEY_CTRL

func _enter_tree() -> void:
	main_panel_instance = MainPanel.instantiate()
	# Add the main panel to the editor's main viewport.
	
	get_editor_interface().get_editor_main_screen().add_child(main_panel_instance)
	# Hide the main panel. Very much required.
	_make_visible(false)
	add_custom_type("GMAP", "Node2D", preload("game scripts/gmap.gd"), preload("icon.png")) #adds GMAP to game
	self.connect("scene_changed",update_scene_change)# when scene is changed, send signal to change what the editor is editing calling.
	#registering hotkey
	var key = InputEventKey.new()
	key.physical_keycode = KEY_F2
	
	if !InputMap.has_action("GMAP_focus"):
		InputMap.add_action("GMAP_focus")
		InputMap.action_add_event("GMAP_focus", key)

 #hotkey hack
func _process(float):
	if Input.is_action_just_pressed("GMAP_focus"):
		EditorInterface.set_main_screen_editor("Gmap Viewer")
		main_panel_instance.reload_map(get_editor_interface().get_edited_scene_root())
		
		
func update_scene_change(scn):
	if main_panel_instance.is_visible_in_tree():
		main_panel_instance.reload_map(scn)


func _exit_tree() -> void:
	if main_panel_instance:
		main_panel_instance.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible: bool) -> void:
	if main_panel_instance:
		main_panel_instance.visible = visible


# If your plugin doesn't handle any node types, you can remove this method.
func _handles(object: Object) -> bool:
	return is_instance_of(object, preload("res://addons/gmap_viewer/handled_by_main_screen.gd"))


func _get_plugin_name() -> String:
	return "Gmap Viewer"


func _get_plugin_icon() -> Texture2D:
	return get_editor_interface().get_base_control().get_theme_icon("Node", "EditorIcons")
