extends Label

func check_region(grid_size,scn,x:int,y:int,start_point:Vector2,size,columns,rows):
	#var region = Rect2(Vector2(x*grid_size,y*grid_size) + start_point-Vector2((grid_size/2)*size,(grid_size/2)*size),Vector2(grid_size,grid_size)) 
	var region = Rect2(Vector2(x*grid_size,y*grid_size) + start_point-Vector2((grid_size/2)*size,(grid_size/2)*size),Vector2(grid_size,grid_size)) 
	var found_nodes = []
	var result = ""
	var offset = ceil(size/2)
	var x_offset = (((start_point.x + x*grid_size)/grid_size) -5)
	var y_offset = (((start_point.y + y*grid_size)/grid_size) -4) * -1 + rows
	# Iterate over all children or nodes of interest
	for child in scn.get_children():
		if child is Node2D or child is Control:
			if region.has_point(child.global_position):
				found_nodes.append(child)
	if region.has_point(start_point):
		grab_focus()
	#adding name of node to the map, removing tag made by gmap so display only the name
	for node in found_nodes:
		if node.name.find("_GMAP_CREATED_"):
			result += node.name.get_slice("_GMAP_CREATED_",0) + ", "
		else:
			result += node.name + ", "
	
	text = str(int(x_offset)) + "," + str(int(y_offset)) + " " + result
