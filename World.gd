extends Node2D

# Speed at which the player moves, adjust as needed.
var player_speed = 200
# Initialize movement vector.
var player_movement = Vector2.ZERO

var joystick_start_position = Vector2(950, 450)
var joystick_postion = Vector2(950, 450)
var joystick_max_handle_distance = 50

enum Direction {
	LEFT = 0,
	RIGHT = 1
}

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
			if event.axis_value == 1:
				max_boom(Direction.RIGHT)
			elif event.axis_value == -1:
				max_boom(Direction.LEFT)				
		elif event.axis == 1: # Y axis
			player_movement.y = event.axis_value
			joystick_postion.y = event.axis_value * joystick_max_handle_distance

func max_boom(direction: Direction):
	match direction:
		Direction.LEFT:
			print("Going left")
		Direction.RIGHT:
			print("Going right")
		_:
			print("Unknown direction")
