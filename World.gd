extends Node2D

const HOST: String = "127.0.0.1"
const PORT: int = 30051

# Speed at which the player moves, adjust as needed.
var player_speed = 200
# Initialize movement vector.
var player_movement = Vector2.ZERO

var joystick_start_position = Vector2(950, 450)
var joystick_postion = Vector2(950, 450)
var joystick_max_handle_distance = 50

const Client = preload("res://glonax-client.gd")
var _client: Client = Client.new()

enum Direction {
	LEFT = 0,
	RIGHT = 1
}

func _ready():
	# Ensure the handle is centered at start (neutral position).
	var joystick_handle = get_node("LargeHandleFilled")
	joystick_handle.position = joystick_start_position
	
	_client.connected.connect(_handle_client_connected)
	_client.disconnected.connect(_handle_client_disconnected)
	_client.error.connect(_handle_client_error)
	_client.message.connect(_handle_client_message)
	
	add_child(_client)
	
	_client.connect_to_host(HOST, PORT)
	
func _handle_client_connected() -> void:
	print("Client is connected.")

func _handle_client_disconnected() -> void:
	print("Client disconnected from server.")

func _handle_client_error() -> void:
	print("Client error.")
	
func _handle_client_message(message_type: Client.MessageType, data: PackedByteArray) -> void:
	print("We got message: " + str(message_type) + " with data: " + str(data))
	
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
			var motion = Client.MotionMessage.new()
			motion.command = Client.CHANGE
			
			var change_set = Client.MotionChangeSetMessage.new()
			change_set.actuator = 2
			change_set.value = 32_000
			
			motion.value_list = [change_set]
			
			print("Motion bytes: ", motion.to_bytes())
			_client.send(Client.MessageType.MOTION, motion.to_bytes())
			
		Direction.RIGHT:
			print("Going right")
		_:
			print("Unknown direction")
