extends Node2D

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

const Client = preload ("res://glonax-client.gd")
var _client: Client = Client.new("godot/4.2")

enum ExcavatorState {
	UNKNOWN,
	STARTED,
	STOPPED,
	SHUTDOWN
}

var excavatorState = {
	"previous_state": ExcavatorState.UNKNOWN,
	"current_state": ExcavatorState.UNKNOWN,
	"WorkMode": WorkModes.UNKNOWN
}

enum Direction {
	LEFT = 0,
	RIGHT = 1
}

enum WorkModes {
	UNKNOWN,
	IDLE_1,
	IDLE_2,
	FINE_1,
	FINE_2,
	FINE_3,
	GENERAL_1,
	GENERAL_2,
	GENERAL_3,
	HIGH,
	POWER_MAX
}

const WorkModeNames = {
	WorkModes.UNKNOWN: "UNKNOWN",
	WorkModes.IDLE_1: "Idle 1",
	WorkModes.IDLE_2: "Idle 2",
	WorkModes.FINE_1: "Fine 1",
	WorkModes.FINE_2: "Fine 2",
	WorkModes.FINE_3: "Fine 3",
	WorkModes.GENERAL_1: "General 1",
	WorkModes.GENERAL_2: "General 2",
	WorkModes.GENERAL_3: "General 3",
	WorkModes.HIGH: "High",
	WorkModes.POWER_MAX: "Power Boost"
}

enum {
	IDLE_1 = 800,
	IDLE_2 = 1000,
	FINE_1 = 1200,
	FINE_2 = 1300,
	FINE_3 = 1400,
	GENERAL_1 = 1500,
	GENERAL_2 = 1600,
	GENERAL_3 = 1700,
	HIGH = 1800,
	POWER_MAX = 1900
}

const WorkModeRPM = {
	WorkModes.UNKNOWN: 0,
	WorkModes.IDLE_1: IDLE_1,
	WorkModes.IDLE_2: IDLE_2,
	WorkModes.FINE_1: FINE_1,
	WorkModes.FINE_2: FINE_2,
	WorkModes.FINE_3: FINE_3,
	WorkModes.GENERAL_1: GENERAL_1,
	WorkModes.GENERAL_2: GENERAL_2,
	WorkModes.GENERAL_3: GENERAL_3,
	WorkModes.HIGH: HIGH,
	WorkModes.POWER_MAX: POWER_MAX
}

func _ready():
	# Ensure the handle is centered at start (neutral position).
	#var joystick_handle = get_node("JoystickInnerRight")
	#joystick_start_position = joystick_handle.starting_position
	#joystick_handle.position = joystick_start_position
	$"WorkModeSlider/WorkModeLabel".text = "Requested Work Mode: None"
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	_client.connected.connect(_handle_client_connected)
	_client.disconnected.connect(_handle_client_disconnected)
	_client.error.connect(_handle_client_error)
	_client.message.connect(_handle_client_message)
	
	add_child(_client)

	#TODO: Connect once, not once per scene
	_client.connect_to_host(Global.host, Global.port)

func _handle_client_connected() -> void:
	print("Client is connected.")
	$Hostname.text = "Connected to: " + Global.host + ":" + str(Global.port)
	$Instance.text = "Instance ID: " + _client._instance.instance_id.hex_encode()
	$Name.text = "Name: " + _client._instance.name

func _handle_client_disconnected() -> void:
	print("Client disconnected from server.")

func _handle_client_error() -> void:
	print("Client error.")
	
func _handle_client_message(message_type: Client.MessageType, data: PackedByteArray) -> void:
	#print("We got message: " + str(message_type) + " with data: " + str(data))
	if message_type == Client.MessageType.ENGINE:
		var engine = Client.EngineMessage.from_bytes(data)
		#engine.from_bytes(data)
		#print(engine.get_string_representation())
		$"EngineRPM".text = "Engine RPM: " + str(engine.rpm)
		#$"Engine RPM".text = str(engine.rpm)
		# TODO: if rpm == 0 Set work mode disabled
		# TODO: if rpm == 0 Set shutdown disabled
	
func _process(delta):
	#var player = get_node("Player") # Adjust the path if necessary.
	#var joystick_handle = get_node("JoystickInnerRight")
	#joystick_handle.position = joystick_handle.start_position + joystick_axis["right_joystick"] * joystick_max_handle_distance
	#print(joystick_handle.position)
	#var joystick_handle_right = get_node("JoystickInnerRight")
	#$JoystickInnerRight.position = $JoystickInnerRight.start_position + joystick_axis["right_joystick"] * joystick_max_handle_distance

	#var joystick_handle_left = get_node("JoystickInnerLeft")
	#$JoystickInnerLeft.position = $JoystickInnerLeft.start_position + joystick_axis["left_joystick"] * joystick_max_handle_distance
	
	if counter == 3:
		counter = 0
		_client.send_request(Client.MessageType.ENGINE)
	
	counter += 1
	
#_on_start_motor_pressed():
	#var motion = Client.MotionMessage.new()
	#_client.send(Client.MessageType.START, motion.to_bytes())
	
func map_float_to_int_range(value: float, min_float: float, max_float: float, min_int: int, max_int: int) -> int:
	var normalized = (value - min_float) / (max_float - min_float)
	var scaled = min_int + normalized * (max_int - min_int)
	return int(round(scaled))
	
func _input(event):
	if event is InputEventJoypadMotion:
		if event.device == joystick_orientation["right_joystick"]:
			if event.axis == 0: # X axis
				$JoystickInnerRight.position.x = $JoystickInnerRight.start_position.x + event.axis_value * joystick_max_handle_distance
				handle_attachment(event.axis_value)
			elif event.axis == 1: # Y axis
				$JoystickInnerRight.position.y = $JoystickInnerRight.start_position.y + event.axis_value * joystick_max_handle_distance
				handle_boom(event.axis_value)
			elif event.axis == 3: # Slider
				var work_mode = map_float_to_int_range(event.axis_value, 1.0, -1.0, 1, 10)
				handle_work_mode(work_mode)
				# if $WorkModeSlider.editable:
				# 	$WorkModeSlider.value = map_float_to_int_range(event.axis_value, 1.0, -1.0, 0, 9)
		elif event.device == joystick_orientation["left_joystick"]:
			if event.axis == 0: # X axis
				$JoystickInnerLeft.position.x = $JoystickInnerLeft.start_position.x + event.axis_value * joystick_max_handle_distance
				handle_slew(event.axis_value)
			elif event.axis == 1: # Y axis
				$JoystickInnerLeft.position.y = $JoystickInnerLeft.start_position.y + event.axis_value * joystick_max_handle_distance
				handle_arm(event.axis_value)
	elif event is InputEventJoypadButton:
		if event.device == joystick_orientation["right_joystick"]:
			# print(event)
			if event.button_index == 9: # Middle right
				handle_stop(event.pressed)
			elif event.button_index == 10: # Bottom left
				handle_start(event.pressed)
			elif event.button_index == 11: # Bottom right
				handle_shutdown(event.pressed)

func handle_shutdown(pressed: bool):
	if pressed:
		if get_state() == ExcavatorState.STARTED or get_state() == ExcavatorState.UNKNOWN:
			print("shutdown")
			if request_shutdown():
				set_state(ExcavatorState.SHUTDOWN)
				$Shutdown.set_pressed(true)
				$"WorkModeSlider/WorkModeLabel".text = "Shutdown"
				$WorkModeSlider.value = WorkModes.IDLE_1
				$WorkModeSlider.editable = false
	else:
		$Shutdown.set_pressed(false)

func handle_start(pressed: bool):
	if pressed:
		if get_state() == ExcavatorState.SHUTDOWN or get_state() == ExcavatorState.UNKNOWN:
			print("start")
			$WorkModeSlider.editable = true
			if request_start_motor():
				set_state(ExcavatorState.STARTED)
				$StartMotor.set_pressed(true)
	else:
		$StartMotor.set_pressed(false)
	# $WorkModeSlider.editable = true
	# $WorkModeSlider.value = WorkModes.IDLE_1

# func toggle_button(button):
# 	if button.is_pressed():
# 		button.set_pressed_no_signal(false)
# 	else:
# 		button.set_pressed_no_signal(true)
# 		button.emit_signal("pressed")

func handle_stop(pressed: bool):
	if pressed:
		if request_stop_motion():
			set_state(ExcavatorState.STOPPED)
			$StopMotion.set_pressed(true)
	else:
		request_resume_motion()
		revert_state()
		$StopMotion.set_pressed(false)
		
func set_state(state: ExcavatorState):
	excavatorState["previous_state"] = excavatorState["current_state"]
	excavatorState["current_state"] = state

func get_state():
	return excavatorState["current_state"]

func revert_state():
	excavatorState["current_state"] = excavatorState["previous_state"]
					
func handle_attachment(axis_value: float) -> bool:
	print("handle_attachment ", axis_value)
	var motion = Client.MotionMessage.new()
	motion.command = Client.CHANGE
	
	var change_set = Client.MotionChangeSetMessage.new()
	change_set.actuator = 5
	change_set.value = map_float_to_int_range(axis_value, -1.0, 1.0, 0, 32_000)
	
	motion.value_list = [change_set]
	
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())
	
func handle_boom(axis_value: float) -> bool:
	print("handle_boom ", axis_value)
	var motion = Client.MotionMessage.new()
	motion.command = Client.CHANGE
	
	var change_set = Client.MotionChangeSetMessage.new()
	change_set.actuator = 0
	change_set.value = map_float_to_int_range(axis_value, -1.0, 1.0, 0, 32_000)
	
	motion.value_list = [change_set]
	
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())
	
func handle_slew(axis_value: float) -> bool:
	print("handle_slew ", axis_value)
	var motion = Client.MotionMessage.new()
	motion.command = Client.CHANGE
	
	var change_set = Client.MotionChangeSetMessage.new()
	change_set.actuator = 1
	change_set.value = map_float_to_int_range(axis_value, -1.0, 1.0, 0, 32_000)
	
	motion.value_list = [change_set]
	
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())
	
func handle_arm(axis_value: float) -> bool:
	print("handle_arm ", axis_value)
	var motion = Client.MotionMessage.new()
	motion.command = Client.CHANGE
	
	var change_set = Client.MotionChangeSetMessage.new()
	change_set.actuator = 4
	change_set.value = map_float_to_int_range(axis_value, -1.0, 1.0, 0, 32_000)
	
	motion.value_list = [change_set]
	
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())

func request_start_motor() -> bool:
	if request_work_mode(WorkModes.IDLE_1):
		change_work_mode_text(WorkModes.IDLE_1)
		excavatorState["work_mode"] = WorkModes.IDLE_1
		return true
	return false
	
func request_shutdown() -> bool:
	var control = Client.ControlMessage.new()
	control.control_type = Client.ControlType.ENGINE_SHUTDOWN
	return _client.send(Client.MessageType.CONTROL, control.to_bytes())

func request_stop_motion() -> bool:
	print("stop motion")
	var motion = Client.MotionMessage.stop_all()
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())

func request_resume_motion() -> bool:
	var motion = Client.MotionMessage.resume_all()
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())

func request_work_mode(work_mode: WorkModes) -> bool:
	var control = Client.ControlMessage.new()
	control.control_type = Client.ControlType.ENGINE_REQUEST
	control.value = WorkModeRPM[work_mode]
	return _client.send(Client.MessageType.CONTROL, control.to_bytes())

func change_work_mode_text(work_mode: WorkModes):
	$WorkModeSlider.value = work_mode
	$"WorkModeSlider/WorkModeLabel".text = "Requested Work Mode: " + WorkModeNames[work_mode]
	
# func _on_stop_motion_pressed():
# 	print("stop motor")
# 	request_stop_motion()
# 	state = ExcavatorState.STOPPED
# 	#$"WorkModeSlider/WorkModeLabel".text = "Stopped"
# 	#$WorkModeSlider.editable = false	

# func _on_stop_motion_button_up():
# 	print("resume motor")
# 	request_stop_motion()
# 	#state = ExcavatorState.STOPPED
# 	pass # Replace with function body.

# func _on_stop_motion_button_down():
# 	print("stop motor")
# 	request_stop_motion()
# 	state = ExcavatorState.STOPPED
# 	pass # Replace with function body.

# func _on_start_motor_pressed():
# 	print("start motor")
# 	$WorkModeSlider.editable = true
	
# 	# TODO: Change this to something more explicit
# 	# Changing the slider value will trigger a rpm engine request
# 	$WorkModeSlider.value = WorkModes.IDLE_1
	
# 	state = ExcavatorState.STARTED
	
# func _on_shutdown_pressed():
# 	print("shutdown")
# 	request_shutdown()
# 	state = ExcavatorState.SHUTDOWN
# 	#change_slider_value_without_signal()
# 	$"WorkModeSlider/WorkModeLabel".text = "Shutdown"
# 	$WorkModeSlider.editable = false
	
# func change_slider_value_without_signal(slider, value: int):
# 	slider.disconnect("value_changed", self, "_on_work_mode_slider_value_changed")
# 	slider.value = value
# 	slider.connect("value_changed", self, "_on_work_mode_slider_value_changed")

# func _on_work_mode_slider_value_changed(value):
# 	if get_state() != ExcavatorState.STARTED:
# 		#$"WorkModeSlider/WorkModeLabel".text = "Excavator not started, cannot set work mode"
# 		return
	
# 	var work_mode = int(value)
# 	if work_mode in WorkModes.values():
# 		request_work_mode(work_mode)

func handle_work_mode(work_mode_value: int):
	if get_state() != ExcavatorState.STARTED:
		return

	if work_mode_value not in WorkModes.values():
		return
	
	if work_mode_value > (excavatorState["work_mode"] + 1) or work_mode_value < (excavatorState["work_mode"] - 1):
		return
	   
	if request_work_mode(work_mode_value):
		change_work_mode_text(work_mode_value)
		excavatorState["work_mode"] = work_mode_value
