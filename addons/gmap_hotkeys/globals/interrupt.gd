extends Node

var delay = 0
var targ:Node = null
var text:String = ""
var new = false
var label

func change(target,input):
	text = input
	targ = target
	target.focus_mode = 0
	if label:
		label.queue_free()
	label = Label.new()
	target.add_child(label)
	label.grab_focus()
	label.text = text
	

func resend():
	if targ:
		if label:
			label.queue_free()
		label = Label.new()
		targ.add_child(label)
		label.grab_focus()
		label.text = text
