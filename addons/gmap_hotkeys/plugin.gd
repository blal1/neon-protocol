@tool
extends EditorPlugin

#EDIT after = in format of KEY_(name of key)
# List of valid keys linked in document: 
# https://docs.godotengine.org/en/stable/classes/class_@globalscope.html#enum-globalscope-key

var gmap_ctrl = KEY_CTRL #button that needs to be held along side other ones. 
var inspector_tab = KEY_F6


var file_tab = KEY_F7
var scene_tab = KEY_F8
var node_tab = KEY_F9
var open_scene_tabs = KEY_F10
var import_tab = KEY_F11

var inspector_category = KEY_U
var focus_method_list = KEY_E
var find_error = KEY_SEMICOLON
var open_node_search = KEY_T
var menu_bar = KEY_F10


var plugin

var all_nodes #used to find needed  nodes for hot keys

#ctrl f6-f11 unused by default

var inspector = EditorInterface.get_inspector()
var file_system = EditorInterface.get_file_system_dock()
var script_editor = EditorInterface.get_script_editor()


const HBoxFocusFixer = preload("res://addons/gmap_hotkeys/focus fixer/h_box_focus_fixer.gd")
const VBoxFocusFixer = preload("res://addons/gmap_hotkeys/focus fixer/v_box_focus_fixer.gd")

var focus_remove_list = [] #array of nodes that we disable focus for
#used to search all nodes
const GMAP_NODE_SEARCHING = preload("res://addons/gmap_hotkeys/search/gmap_node_searching.tscn")
var search_box

#playing error noises!
const GMAP_ALERT = preload("res://addons/gmap_hotkeys/gmap_alert.tscn")
const SUCCESSSFX = preload("res://addons/gmap_hotkeys/gmap_success.mp3")
const ALERTSFX = preload("res://addons/gmap_hotkeys/gmap_alert.wav")
var gmap_alert 
#used to track error bar popups during coding
var error_bar 
var error_bar_text = ""
var vis
#runtime error tracking
var error_runtime
var error_runtime_text =""

var debug_timer = 1000
var debug_var
var debug_array = []
var debug_array2 = []

@export var t:int
var check  = KEY_COMMA #used when testing

func _enable_plugin():
	# The autoload can be a scene or script file.
	add_autoload_singleton("GM", "res://addons/gmap_hotkeys/assists/gmap_funcs.gd")
func _disable_plugin():
	remove_autoload_singleton("GM")
	
func _enter_tree():
	gmap_alert = GMAP_ALERT.instantiate()
	add_child(gmap_alert)
	
	#creating search box
	#search_box = GMAP_NODE_SEARCHING.instantiate()
	#get_viewport().set_embedding_subwindows(true)
	#get_viewport().add_child(search_box)
	#search_box.hide()
	#Some nodes we do not want to have focus ever via keyboard or at all.
	focus_remover()
	
func _ready():
	
	replace_event("find_script",KEY_EQUAL,true,true)
	#connecting signal to know when a new container enters
	get_tree().connect("node_added",add_container_reorg)
	add_container_reorg_all()
	#finding error bar so play alert when played.
	var chk = get_parent().find_child("Stack Trace",true,false)
	chk = chk.find_child("*HBoxContainer*",true,false)
	error_runtime = chk.find_child("*Label*",true,false)
	error_runtime.accessibility_live = DisplayServer.LIVE_ASSERTIVE

func _process(float):
	#Going to inspector f6 by default
	if Input.is_key_pressed(inspector_tab) and Input.is_key_pressed(gmap_ctrl):# focusing on the inspector
		var inspector_grandparent = inspector.get_parent().get_parent()
		inspector_grandparent.get_tab_bar().grab_focus()
		for i in range(inspector_grandparent.get_tab_count()):
			if inspector_grandparent.get_tab_title(i) == "Inspector":
				inspector_grandparent.current_tab = i
				break
	#going to the top category of inspector, Ctrl U by default
	if Input.is_key_pressed(inspector_category) and Input.is_key_pressed(gmap_ctrl):# focusing on the inspector category
		var editor_interface = get_editor_interface()
		var sc = editor_interface.get_edited_scene_root()
		var focused = get_viewport().gui_get_focus_owner()
		var searchedmulti = inspector.find_children("@EditorInspectorCategory*","",true,false)
		for k in searchedmulti:
			if k.tooltip_text:
				k.grab_focus()
				break
	
	#going to FileSystem F7 by default
	if Input.is_key_pressed(file_tab) and Input.is_key_pressed(gmap_ctrl):# focusing on the inspector
		var file_system_parent = file_system.get_parent()
		file_system_parent.get_tab_bar().grab_focus()
		for i in range(file_system_parent.get_tab_count()):
			if file_system_parent.get_tab_title(i) == "FileSystem":
				file_system_parent.current_tab = i
				break
	#getting to scene tree F8 by default
	if Input.is_key_pressed(scene_tab) and Input.is_key_pressed(gmap_ctrl):
		var scene_tree = get_parent().find_child("@SceneTreeEditor*",true,false)
		var scene_tab = (scene_tree.get_parent().get_parent())
		scene_tab.get_tab_bar().grab_focus()
		for i in range(scene_tab.get_tab_count()):
			if scene_tab.get_tab_title(i) == "Scene":
				scene_tab.current_tab = i
				break
	#getting to node tree F9 by default
	if Input.is_key_pressed(node_tab) and Input.is_key_pressed(gmap_ctrl):
		var node_tab = get_parent().find_child("Signals*",true,false)
		var node_parent = (node_tab.get_parent().get_parent())
		node_parent.get_tab_bar().grab_focus()
		for i in range(node_parent.get_tab_count()):
			if node_parent.get_tab_title(i) == "Node":
				node_parent.current_tab = i
				break
	#Focuses on the tab bar full of active nodes
	if Input.is_key_pressed(open_scene_tabs) and Input.is_key_pressed(gmap_ctrl):
		var parent_node = get_parent().find_child("*EditorSceneTabs*",true,false)
		var tab_bar = parent_node.find_child("*TabBar*",true,false)
		tab_bar.grab_focus()
		
	elif Input.is_key_pressed(menu_bar):
		var parent_node = get_parent().find_child("*EditorTitleBar*",true,false)
		parent_node.get_child(0).grab_focus()
	
	#KEY_E by default
	if Input.is_key_pressed(focus_method_list) and Input.is_key_pressed(gmap_ctrl):
		var parent_node = get_parent().find_child("*ScriptEditor*",true,false)
		var list = parent_node.find_children("*LineEdit*","",true,false)
		
		for t in list:
			if t.placeholder_text == "Filter Methods":
				t.grab_focus()
				break
	
	#KEY_SEMICOLON by default to find errors
	if Input.is_key_pressed(find_error) and Input.is_key_pressed(gmap_ctrl):# 
		if error_bar.text != "" and get_viewport().gui_get_focus_owner() != error_bar:
			error_bar.grab_focus()
		elif error_runtime.text != "":
			error_runtime.grab_focus()
			
	#ctrl f11 to go to import tab
	if Input.is_key_pressed(import_tab) and Input.is_key_pressed(gmap_ctrl):
		var scene_tree = get_parent().find_child("@SceneTreeEditor*",true,false)
		var scene_tab = (scene_tree.get_parent().get_parent())
		scene_tab.get_tab_bar().grab_focus()
		for i in range(scene_tab.get_tab_count()):
			if scene_tab.get_tab_title(i) == "Import":
				scene_tab.current_tab = i
				break
				
#opening and focusing on, T by default
	if Input.is_key_pressed(menu_bar):
		var parent_node = get_parent().find_child("*EditorTitleBar*",true,false)
		parent_node.get_child(0).grab_focus()
		#search_box.open()
		
	#breaking focus if 	cancel held
	if Input.is_action_pressed("ui_cancel"):
		debug_timer -= 1
		if debug_timer <= 0:
			debug_timer = 100
			break_focus()
	else: 
		debug_timer = 100
	#jumps to script of selected node, or button to make it.
	if Input.is_action_just_pressed("find_script") :# 
		script_create()
		
	if Input.is_action_just_pressed("ui_end"):
		focus_checking()
	
	error_line() #plays sound if error code appears as a result of script edit.
	error_runtime_check() #plays sound if there is, a run time error

func break_focus():
	var current = get_viewport().gui_get_focus_owner()
	if current:
		if current.find_valid_focus_neighbor(2):
			current.find_valid_focus_neighbor(2).grab_focus()
		elif current.find_valid_focus_neighbor(3):
			current.find_valid_focus_neighbor(3).grab_focus()
		elif current.find_valid_focus_neighbor(1):
			current.find_valid_focus_neighbor(1).grab_focus()
		elif current.find_valid_focus_neighbor(0):
			current.find_valid_focus_neighbor(0).grab_focus()
		else:
			current.release_focus()

func script_create():
	var picked_node = get_editor_interface().get_selection().get_selected_nodes()[0]
	if picked_node.get_script():
		get_editor_interface().edit_script(picked_node.get_script())
	else:
		var scene_tree = get_parent().find_child("@SceneTreeEditor*",true,false)
		var scene_tab = (scene_tree.get_parent())
		var scene_bar = scene_tab.get_child(0)
		var button = scene_bar.get_child(3)
		if button.visible == true:
			button.grab_focus()

func focus_checking(): #debug function to check focus of things
	var focused = get_viewport().gui_get_focus_owner()
	print(focused)
	print(focused.text)

#going through and fixing focus for different container types
func add_container_reorg_all():
	find_container(get_node("/root"),"HBoxContainer",HBoxFocusFixer)
	find_container(get_node("/root"),"VBoxContainer",VBoxFocusFixer)
	pass
	
#VBoxFocusFixer
func add_container_reorg(node):
	if node.get_class() == "HBoxContainer" and node.get_script() == null:
		node.set_script(HBoxFocusFixer)
		node.attach()
		
	elif node.get_class() == "VBoxContainer" and node.get_script() == null:
		node.set_script(VBoxFocusFixer)
		node.attach()
	#disabling focus for nodes we don't like
	if node.get_class() in focus_remove_list and node.focus_mode != 1 and node.focus_mode != 0:
		node.focus_mode = 1
	elif node is BaseButton:
		if node is TextureButton:
			if node.accessibility_description == "":
				node.accessibility_description = node.tooltip_text
		elif node.text == "" and node.accessibility_description == "":
			node.accessibility_description =  node.tooltip_text
			
			
		
	

func find_container(parent: Node,type,script) -> Array:
	var windows = []
	for child in parent.get_children():
		if child.get_class() == type:
			#if previously added for some reason, script
			if child.get_script() == null:
				child.set_script(script)
				child.attach()
				
			windows.append(child)
		if child.get_children():
			windows += find_container(child,type,script)
	return windows

	
func _exit_tree():
	remove_inspector_plugin(plugin)

func error_runtime_check():
	if error_runtime.text != error_runtime_text:
		error_runtime_text = error_runtime.text
		if error_runtime.text != "" and error_runtime.text != "Debug session closed."and error_runtime.text != "Debug session started.":
			gmap_alert.stream = ALERTSFX
			gmap_alert.play()
			
func focus_remover():
	focus_remove_list = ["SplitContainerDragger","CanvasItemEditorViewport","VScrollBar","HScrollBar"]
	var root = get_node("/root")
	#some nodes can have focus that we can not want to ever have focus via keyboard
	var draggers = root.find_children("*SplitContainerDragger*","",true,false)
	for f in draggers:
		f.focus_mode =1
		
	var viewer2d = root.find_children("*CanvasItemEditorViewport*","",true,false)
	for i in viewer2d:
		i.focus_mode = 1
		
	var vscrolls = root.find_children("*VScrollBar*","",true,false)
	for i in vscrolls:
		i.focus_mode = 1
		
	var vscrolls2 = root.find_children("_v_scroll","",true,false)
	for i in vscrolls2:
		i.focus_mode = 1
		
	var hscrolls = root.find_children("*HScrollBar*","",true,false)
	for i in hscrolls:
		i.focus_mode = 1

func error_line():
#below the text editor there is a little line that will display syntax error messages.
#This code finds where that is. 
	if error_bar:
		if vis.visible == true:
			if error_bar_text != error_bar.text:
				error_bar_text = error_bar.text
				if error_bar.text != "":
					gmap_alert.stream = ALERTSFX
					gmap_alert.play()
				elif error_bar.text == "":
					gmap_alert.stream = SUCCESSSFX
					gmap_alert.play()
		else:
			error_bar = null
	else:
		#making the error bar assertive, and getting it stored so can beep if found.
		#Has to wait until certain assets are loaded to find. Giant pain, but why it's in a loop like this.
		var chk
		var chk2
		chk2 = script_editor.get_current_editor()
		vis = chk2
		if chk2:
			chk2 = chk2.find_child("*VSplitContainer*",true,false)
			if chk2 == null:
				return
			
			chk2 = chk2.find_child("*CodeTextEditor*",true,false)
			chk2 = chk2.find_child("*HBoxContainer*",true,false)
			chk2 = chk2.find_child("*ScrollContainer*",true,false)
			error_bar = chk2.get_child(0)
			error_bar.accessibility_live = DisplayServer.LIVE_ASSERTIVE

func replace_event(event_name:String,new_key,control = false, shift = false):
	#input key class being assigned the key
	var e1 = InputEventKey.new()
	e1.physical_keycode = new_key
	e1.ctrl_pressed = control
	e1.shift_pressed = false
	
	if InputMap.has_action(event_name):
		InputMap.erase_action(event_name)
		
	InputMap.add_action(event_name)
	InputMap.action_add_event(event_name, e1)
