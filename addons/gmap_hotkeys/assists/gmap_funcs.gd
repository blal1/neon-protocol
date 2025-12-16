extends Node
const PIXEL = preload("res://addons/gmap_hotkeys/assists/pixel.png")

func create_collide_rect(x :int,y: int, targ: Node,box: bool = false,col: Color = Color.BLACK):
	#creating the collision box
	var collider = CollisionShape2D.new()
	#Creating a rectangle that can be assigned to collision boxes.
	var shape_rect = RectangleShape2D.new()
	#The rectangle only needs 2 values, width then height
	shape_rect.size = Vector2(x,y)
	#assign the shape to the collider, so the collider now has a shape, and anything with a collision box
	#On the same collision layer with a mask will interact with one another
	collider.shape = shape_rect
	targ.add_child(collider)
	
	if box == true:
		var col_box = Sprite2D.new()
		col_box.texture= PIXEL
		col_box.scale = Vector2(x,y)
		col_box.modulate = col
		targ.add_child(col_box)
		
func add_event(event_name:String,new_key):
	#input key class being assigned the key
	var e1 = InputEventKey.new()
	e1.physical_keycode = new_key
	#if an event already exists, we won't create it, simply add to it.
	if InputMap.has_action(event_name) == false:
		InputMap.add_action(event_name)
	InputMap.action_add_event(event_name, e1)
	accessibility_live =DisplayServer.LIVE_ASSERTIVE
