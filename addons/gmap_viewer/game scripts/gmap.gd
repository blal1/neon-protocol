
extends Node2D
var in_game_map: GridContainer 
const GMAP_LABEL = preload("res://addons/gmap_viewer/game scripts/gmap_in_game_label.tscn")
const IN_GAME_MAP = preload("res://addons/gmap_viewer/game scripts/in_game_map.tscn")
const GMAP_MAP_LAYER = preload("res://addons/gmap_viewer/game scripts/gmap_map_layer.tscn")
var map_layer

var map_dict = {}
@export var node_size: int

#@export var map_ref: Array[String]
#@export var scene_ref: Array[PackedScene]

var map_ref: Array[String]
var scene_ref: Array[PackedScene]

@export var rows: int = 5
@export var columns : int = 5
	
func _enter_tree():
	map_layer = GMAP_MAP_LAYER.instantiate()
	add_child(map_layer)
	var found_files= dir_contents("res://")
	for n in map_ref.size():
		add_mapping(map_ref[n],scene_ref[n])
	create_obj()
	


func _gmap_check():
	pass

func add_mapping(key:String,value_loaded:PackedScene):
	#var value_loaded = preload(value)
	map_dict[key] = value_loaded
	pass
	
func create_obj(): #using the cell map array, creates the items
	var ar = load_cell_map()
	var inst
	var created 
	for n in ar.size():
		for t in ar[n].size():
			if map_dict.has(ar[n][t]):
				inst = map_dict[ar[n][t]]
				created = inst.instantiate()
				add_child(created)
				created.name = ar[n][t]+"_GMAP_CREATED_" + str(n) + "_" +str(t) 
				created.position = Vector2(n * node_size,t * node_size)


# Function to load a 2D array from a file
func load_cell_map() -> Array:
	var scn_path = scene_file_path
	var saved_path = scn_path.left(scn_path.length() - 4)+"gmap"
	var file = FileAccess.open(saved_path, FileAccess.READ)
	if file:
		var json_data = file.get_as_text()
		file.close()
		return(str_to_var(json_data))
	else:
		return []

#reutnring what cell on the map the called section is
func gmap_get_cell(pos:Vector2):
	var mod_x =round(pos.x/node_size) #getting the x of "square" we are in.Going to be what we are centered on
	var mod_y =round(pos.y/node_size) *-1 +rows - 1  #getting the y of "square" we are in.Going to be what we are centered on
	return(Vector2(mod_x,mod_y))
	
	pass
#generating the in game viewable map
func gmap_view_map(start:Vector2,size:int,action):
	var total_size = size * size # how many squares we are making.
	var round_x =round(start.x/node_size) * node_size  #getting the x of "square" we are in.Going to be what we are centered on
	var round_y =round(start.y/node_size) * node_size  #getting the y of "square" we are in.Going to be what we are centered on
	var label
	#creating the map area!
	in_game_map = IN_GAME_MAP.instantiate()
	map_layer.add_child(in_game_map,false,Node.INTERNAL_MODE_BACK)
	
	in_game_map.columns = size
	in_game_map.action = action
	
	for t in range(total_size): # making each cell of the map, and putting in their values.
		label = GMAP_LABEL.instantiate()
		in_game_map.add_child(label)
		label.check_region(node_size,self,t % size,round(t/size),Vector2(round_x,round_y),size,columns,rows)#custom function of the label
		
	in_game_map.process_mode = Node.PROCESS_MODE_ALWAYS
	in_game_map.visible = true
	get_tree().paused = true

func dir_contents(path):
	var dir = DirAccess.open(path)
	if dir:
		
		dir.list_dir_begin()
		var file_name = dir.get_next()

		while file_name != "": 
			if dir.current_is_dir() and (file_name != 'addons') :
				dir_contents(path.path_join(file_name))
			else:
				if file_name.get_extension() == "tscn":
					var full_path = path.path_join(file_name)
					var loaded_scene = load(full_path)
					scene_ref.append(loaded_scene)
					map_ref.append(file_name.substr(0, file_name.length() - 5))
			file_name = dir.get_next()
	else:
		print("An error occurred when trying to access the path.")
	return 
