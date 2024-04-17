extends Node2D

# Speed at which the player moves, adjust as needed.
var player_speed = 200
# Initialize movement vector.
var player_movement = Vector2.ZERO

var joystick_start_position = Vector2(950, 450)
var joystick_postion = Vector2(950, 450)
var joystick_max_handle_distance = 50

func _ready():
	# Ensure the handle is centered at start (neutral position).
	var joystick_handle = get_node("LargeHandleFilled")
	joystick_handle.position = joystick_start_position
	
func _process(delta):
	var player = get_node("Player") # Adjust the path if necessary.
	var joystick_handle = get_node("LargeHandleFilled")
	joystick_handle.position = joystick_start_position + joystick_postion
	player.position += player_movement * player_speed * delta

func _input(event):
	#print("test", event)
	if event is InputEventJoypadMotion:
		#print("test", event)	
		if event.axis == 0: # X axis
			player_movement.x = event.axis_value
			joystick_postion.x = event.axis_value * joystick_max_handle_distance
		elif event.axis == 1: # Y axis
			player_movement.y = event.axis_value
			joystick_postion.y = event.axis_value * joystick_max_handle_distance
