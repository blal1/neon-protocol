@tool
extends GridContainer
var rows: int 
var grid_size: int
var cell_map = []
var created_cells

var saved_path = ""
var gmap_node
var map_ref = []

const MAP_LINE = preload("res://addons/gmap_viewer/map_line.tscn")


func reload_map(scn):
	var scn_path
	if get_child_count() > 0:
		for obj in get_children():
			remove_child(obj)
			obj.queue_free()
				
	if scn:
		scn_path = scn.scene_file_path


	else:
		focus_mode = Control.FOCUS_ALL#cancelling out if not saved
		accessibility_description = "Scene has not been saved. Save scene to continue."
		grab_focus()
		return
	saved_path = scn_path.left(scn_path.length() - 4)+"gmap"
	
	if scn.has_method("_gmap_check"): #cancelling out if no GMAP node in scene
		gmap_node = scn 
		grid_size = gmap_node.node_size
		columns = gmap_node.columns
		rows = gmap_node.rows
		map_ref = []
		dir_contents("res://")
		accessibility_description = "Welcome to GMAP, press tab to change focus to cells."
	else:
		focus_mode = Control.FOCUS_ALL 
		accessibility_description = "This is not a GMAP node."
		grab_focus()
		return
			
	var map_size =  columns * rows
	

	# creating array to store values from map
	cell_map = load_cell_map()
	#expanding array to fit resized map
	while cell_map.size() < rows:
		cell_map.append([])
	for row in cell_map:
		while row.size() < columns:
			row.append("")
	
	#making a copy to store the created cells
	created_cells = cell_map.duplicate(true)
	
# creating the correct number of map cells, assigning loaded file items to them, and cords
	for n in map_size:
		var cell = MAP_LINE.instantiate()
		var x = n % columns
		var y = round(n/rows)
 #giving coordinate to accessibility section
		cell.x = x
		cell.y = y
		cell.parent = self 
		cell.grid_size = grid_size #used to see if something exists in the location of the cell
		
		cell.text = cell_map[x][y]
		cell.scn = scn
		cell.gmap_node = gmap_node
		cell.accessibility_name = str(x) + " " + str(y)+" " + cell.check_region() #saying if region overlaps with other nodes.
		add_child(cell)
		created_cells[x][y] = cell
	#setting focus to be the top left cell
	created_cells[0][0].grab_focus()
# Function to save a 2D array to a file
func save_cell_map() -> void:
	var file_path = saved_path
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		var json_data = JSON.stringify(cell_map)
		file.store_string(json_data)
		file.close()


	
# Function to load a 2D array from a file
func load_cell_map() -> Array:
	var file = FileAccess.open(saved_path, FileAccess.READ)
	
	if file:# loading if array is present
		var json_data = file.get_as_text()
		file.close()
		return(str_to_var(json_data))
	else:
		var empty_array = []
		for i in range(columns): 
			empty_array.append([])
			for j in range(rows): 
				empty_array[i].append("")
		return empty_array

#Finding valid objects
func dir_contents(path):
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "": 
			if dir.current_is_dir() and (file_name != 'addons')and (file_name != '.godot'):
				
				dir_contents(path.path_join(file_name))
			else:
				if file_name.get_extension() == "tscn":
					var full_path = path.path_join(file_name)
					map_ref.append(file_name.substr(0, file_name.length() - 5))
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	return 
