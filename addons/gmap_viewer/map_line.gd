@tool
extends LineEdit

@onready var auto_complete: ItemList = $AutoComplete
@onready var no_obj: AudioStreamPlayer = $NoObj

var x
var y
var parent
var grid_size
var gmap_node
var scn
#saving
func _on_focus_exited() -> void:
	parent.cell_map[x][y] = text
	parent.save_cell_map()
#setting auto complete exit to come back to parent cell
func _ready():
	var self_path = get_path()
	auto_complete.set_focus_neighbor(0,self_path)
	auto_complete.set_focus_neighbor(1,self_path)
	auto_complete.set_focus_neighbor(2,self_path)
	auto_complete.set_focus_neighbor(3,self_path)
	auto_complete.set_focus_next(self_path)
	auto_complete.set_focus_previous(self_path)


func _input(event):
	if is_editing() and event.is_action("ui_down"):
		var ar = parent.map_ref
		for option in ar:
			if option.begins_with(text):
				auto_complete.add_item(option)
		if auto_complete.item_count > 0:
			auto_complete.visible = true
			auto_complete.grab_focus()
			auto_complete.accessibility_description = str(auto_complete.item_count) + " in autocomplete list"
		else:
			no_obj.play()



func check_region():
	var region = Rect2(Vector2(x*grid_size,y*grid_size),Vector2(grid_size,grid_size))
	var found_nodes = []
	var result
	# Iterate over all children or nodes of interest
	for child in scn.get_children():
		if child.name.count("@") == 0 and (child is Node2D or child is Control):
			if region.has_point(child.global_position):
				found_nodes.append(child)
	if found_nodes.size()> 0:
		return "Other nodes in this range"
	else:
		return ""
	
	return found_nodes


func _on_auto_complete_item_activated(index: int) -> void:
	text = auto_complete.get_item_text(index)
	grab_focus()
	unedit()


func _on_auto_complete_focus_exited() -> void:
	
	auto_complete.clear()
	auto_complete.visible = 0

	grab_focus()
	edit()
	pass # Replace with function body.

func _on_focus_entered():

	#grids someitmes mess up focus, fixing this, and making it so you loop to other side of grid
	#instead of losing focus
	var sheet = get_parent().created_cells
	var le_x = x - 1
	var ri_x = x + 1
	
	var up_y = y - 1
	var bo_y = y + 1
	
	var x_size  = sheet.size() -1
	var y_size = sheet[x].size() - 1

	if le_x < 0:
		le_x = x_size
	if ri_x > x_size:
		ri_x = 0
	
	if up_y < 0:
		up_y = y_size
	if bo_y > x_size:
		bo_y = 0
	
	focus_neighbor_bottom = sheet[x][bo_y].get_path()
	focus_neighbor_left = sheet[le_x][y].get_path()
	focus_previous = sheet[le_x][y].get_path()
	
	focus_neighbor_right = sheet[ri_x][y].get_path()
	focus_next = sheet[ri_x][y].get_path()
	
	focus_neighbor_top = sheet[x][up_y].get_path()
