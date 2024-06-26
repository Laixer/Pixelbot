extends Button


## Called when the node enters the scene tree for the first time.
#func _ready():
	#pass # Replace with function body.
#
#
## Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
	#pass
#
var child_visible = false

func _on_pressed():
	#hide items
	var parent = get_parent()
	var joypad = parent.get_node("JoypadPanel")
	var engine = parent.get_node("EnginePanel")
	if joypad != null:
		if child_visible:
			set_visiblility_all_children(joypad, false)
			set_visiblility_all_children(engine, false)
			child_visible = false
		else:
			set_visiblility_all_children(joypad, true)
			set_visiblility_all_children(engine, true)
			child_visible = true
	else:
		print("No joypad node")
	#pass # Replace with function body.

func set_visiblility_all_children(parent, visibility):
	for child in parent.get_children():
		if child.get_child_count() > 0:
			set_visiblility_all_children(child, visibility)
		if child is CanvasItem:  
			child.visible = visibility
