@tool
extends VBoxContainer
#Redoes focus whenever a reorganization happens
var children

func attach():
	sort_children.connect(gmap_children_sort)
	
func gmap_children_sort():
	children = find_window(self)
	var c = 0
	for t in children:
		if c != 0:
			t.set_focus_neighbor(1,children[c-1].get_path())  
		if c != children.size() -1:
			t.set_focus_neighbor(3,children[c+1].get_path())  
		c+=1
func find_window(parent: Node) -> Array:
	var windows = []
	
# Check each child of the given parent
	for child in parent.get_children():
		if "focus_mode" in child :
			if child.focus_mode != 0:
				if child.visible == true:
					windows.append(child)
		if child is VBoxContainer and child.visible == true:
			windows += find_window(child)
	return windows
