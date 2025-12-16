@tool
extends LineEdit



func _input(event):
	if Input.is_action_pressed("ui_focus_next") and has_focus():
			if find_valid_focus_neighbor(2):
				find_valid_focus_neighbor(2).grab_focus()
			elif find_valid_focus_neighbor(3):
				find_valid_focus_neighbor(3).grab_focus()
			elif find_valid_focus_neighbor(1):
				find_valid_focus_neighbor(1).grab_focus()
			elif find_valid_focus_neighbor(0):
				find_valid_focus_neighbor(0).grab_focus()
			else:
				release_focus()
			return
