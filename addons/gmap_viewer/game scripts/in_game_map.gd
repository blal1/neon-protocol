extends GridContainer

var last_focused
var action
var waiting = true
func _ready():
	last_focused = get_viewport().gui_get_focus_owner()

func _process(delta):
	if Input.is_action_just_pressed(action) and waiting == false:
		get_tree().paused = false
		queue_free()
		
		if last_focused:
			last_focused.grab_focus()
	waiting = false
