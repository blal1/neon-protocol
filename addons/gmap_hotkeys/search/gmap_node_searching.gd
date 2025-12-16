@tool
extends Window


@onready var line_edit: LineEdit = $GMAPLineEdit
@onready var search: Button = $GMAPSearch
@onready var next: Button = $GMAPNext
@onready var label: Label = $GMAPLabel

@onready var ttt: CheckBox = $GMAPToolTipsToggle
@onready var open_only: CheckBox = $GMAPOpenScreenOnly


var search_results #array storing what results came back
var current = 0 #where in array we are checking
var last_search =""

func _enter_tree():
	set_embedding_subwindows(true)


func _on_enter(new_text: String) -> void:
	if new_text == last_search:
		_next_pressed()
	else:
		_search_pressed()

func _search_pressed():
	last_search = line_edit.text #keeping track so pressing enter keps searching
	search_results = []
	search_results = find_node(EditorInterface.get_base_control(),line_edit.text,ttt.button_pressed,open_only.button_pressed)

	current = 0
	if search_results.size() == 0:
		label.text = "No results for " + last_search
	else:
		display_results()

func display_results():
	var result = search_results[current]
	if result.is_visible_in_tree():
		if search_results.size() > 0:
			label.text = "Node focused: " + result.get_class()
			if search_results.size() > 1:
				label.text += " additional results: "+ str(search_results.size())
			if "text" in result:
				label.text = label.text + " Text " + result.text
			if "tooltip_text" in result:
				if result.tooltip_text != "":
					label.text = label.text + " Tool tip: " + result.tooltip_text
			if "label" in result:
				label.text = label.text + " Label: " + result.label
		result.grab_focus()
	else:
		label.text = "Node found, not reachable."+ result.get_class()+ " Additional results available: " + str(search_results.size())+ "Path:" + str(result.get_path())
		
func _next_pressed():
	if current+1 < search_results.size():
		current += 1
		display_results()

func find_node(parent: Node, text: String, tooltip_search : bool,open_only: bool) -> Array:
	var windows = []
# Check each child of the given parent
	for child in parent.get_children():
		#focusable, has text, not a gmap node
		if child.has_method("grab_focus")and child.name.containsn("gmap") == false and child.has_method("set_focus_mode"):
			if child.focus_mode != 0:
				if "text" in child:
					if child.text.containsn(text):
						if open_only == false:
							windows.append(child)
						elif open_only == true and child.is_visible_in_tree():
							windows.append(child)
				#focusable, has tooltip, not a gmap node, tool tip search enabled
				if "tooltip_text" in child and child.has_method("grab_focus") and tooltip_search == true and child.name.containsn("gmap") == false:
					if child.tooltip_text.containsn(text):
						if open_only == false:
							windows.append(child)
						elif open_only == true and child.is_visible_in_tree():
							windows.append(child)
				if "label" in child and child.has_method("grab_focus"):
					if child.label is String:
						if child.label.containsn(text):
							if open_only == false:
								windows.append(child)
							elif open_only == true and child.is_visible_in_tree():
								windows.append(child)
		if  child.name.containsn("gmap") == false:
			windows += find_node(child,text,tooltip_search,open_only)
	return windows

func open():
	show()
	line_edit.grab_focus()

func _on_close_requested() -> void:
	hide()
	pass # Replace with function body.
	
func is_visible_in_tree():
	return false

func _on_window_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		hide()
	pass # Replace with function body.
