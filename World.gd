extends Node2D

const HOST: String = "192.168.0.197"
const PORT: int = 30051

# Speed at which the player moves, adjust as needed.
#var player_speed = 200
# Initialize movement vector.
#var player_movement = Vector2.ZERO

#var joystick_start_position = Vector2()
var joystick_axis = {
	"left_joystick": Vector2(),
	"right_joystick": Vector2()
} 
const joystick_max_handle_distance = 25

#TODO: Need calibration and init
var joystick_orientation = {
	"left_joystick": 1,
	"right_joystick": 0
}

var counter = 0

const Client = preload("res://glonax-client.gd")
var _client: Client = Client.new()

enum Direction {
	LEFT = 0,
	RIGHT = 1
}

func _ready():
	# Ensure the handle is centered at start (neutral position).
	#var joystick_handle = get_node("JoystickInnerRight")
	#joystick_start_position = joystick_handle.starting_position
	#joystick_handle.position = joystick_start_position
	
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
	#print("We got message: " + str(message_type) + " with data: " + str(data))
	if message_type == Client.MessageType.ENGINE:
		var engine = Client.EngineMessage.new()
		engine.from_bytes(data)
		#print(engine.get_string_representation())
		$"Engine RPM".text = "Engine RPM: " + str(engine.rpm)
		#$"Engine RPM".text = str(engine.rpm)
	
func _process(delta):
	#var player = get_node("Player") # Adjust the path if necessary.
	#var joystick_handle = get_node("JoystickInnerRight")
	#joystick_handle.position = joystick_handle.start_position + joystick_axis["right_joystick"] * joystick_max_handle_distance
	#print(joystick_handle.position)
	var joystick_handle_right = get_node("JoystickInnerRight")
	joystick_handle_right.position = joystick_handle_right.start_position + joystick_axis["right_joystick"] * joystick_max_handle_distance

	var joystick_handle_left = get_node("JoystickInnerLeft")
	joystick_handle_left.position = joystick_handle_left.start_position + joystick_axis["left_joystick"] * joystick_max_handle_distance

	#player.position += player_movement * player_speed * delta
	
	if counter == 3:
		counter = 0
		_client.send_request(Client.MessageType.ENGINE)
	
	counter += 1
	
#_on_start_motor_pressed():
	#var motion = Client.MotionMessage.new()
	#_client.send(Client.MessageType.START, motion.to_bytes())
	
func _input(event):
	#print("test", event)
	if event is InputEventJoypadMotion:
		#print("test", event.device)	
		if event.device == joystick_orientation["right_joystick"]:		
			if event.axis == 0: # X axis
				joystick_axis["right_joystick"].x = event.axis_value
				handle_attachment(event.axis_value)
			elif event.axis == 1: # Y axis
				joystick_axis["right_joystick"].y = event.axis_value
				handle_boom(event.axis_value)
		elif event.device == joystick_orientation["left_joystick"]:
			if event.axis == 0: # X axis
				joystick_axis["left_joystick"].x = event.axis_value
				handle_slew(event.axis_value)
			elif event.axis == 1: # Y axis
				joystick_axis["left_joystick"].y = event.axis_value
				handle_arm(event.axis_value)
				
func handle_attachment(axis_value: float):
	print("handle_attachment")
	
func handle_boom(axis_value: float):
	print("handle_boom")
	
func handle_slew(axis_value: float):
	print("handle_slew")
	
func handle_arm(axis_value: float):
	print("handle_arm")
	
#func max_boom(direction: Direction):
	#match direction:
		#Direction.LEFT:
			#print("Going left")
			#var motion = Client.MotionMessage.new()
			#motion.command = Client.CHANGE
			#
			#var change_set = Client.MotionChangeSetMessage.new()
			#change_set.actuator = 2
			#change_set.value = 32_000
			#
			#motion.value_list = [change_set]
			#
			#print("Motion bytes: ", motion.to_bytes())
			#_client.send(Client.MessageType.MOTION, motion.to_bytes())
			#
		#Direction.RIGHT:
			#print("Going right")
		#_:
			#print("Unknown direction")
