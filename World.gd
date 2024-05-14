extends Node2D

const JOYSTICK_MAX_HANDLE_DISTANCE = 25

const ENGINE_START_RPM = 500

#TODO: Need calibration and init
var joystick_orientation = {
	"left_joystick": 1,
	"right_joystick": 0
}

var delta_sum = 0

const Client = preload ("res://glonax-client.gd")
var _client: Client = Client.new("godot/4.2")

enum EngineState {
	RUNNING,
	SHUTDOWN
}

enum MotionState {
	LOCKED,
	UNLOCKED
}

var demo_mode = false
var engine_state_changed = false

# TODO: Use glonax to poll state instead 
var excavator = {
	"engine_state": EngineState.SHUTDOWN,
	"motion_state": MotionState.LOCKED,
}

enum WorkMode {
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

const WorkModeName = {
	WorkMode.IDLE_1: "Idle 1",
	WorkMode.IDLE_2: "Idle 2",
	WorkMode.FINE_1: "Fine 1",
	WorkMode.FINE_2: "Fine 2",
	WorkMode.FINE_3: "Fine 3",
	WorkMode.GENERAL_1: "General 1",
	WorkMode.GENERAL_2: "General 2",
	WorkMode.GENERAL_3: "General 3",
	WorkMode.HIGH: "High",
	WorkMode.POWER_MAX: "Power Boost"
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
	WorkMode.IDLE_1: IDLE_1,
	WorkMode.IDLE_2: IDLE_2,
	WorkMode.FINE_1: FINE_1,
	WorkMode.FINE_2: FINE_2,
	WorkMode.FINE_3: FINE_3,
	WorkMode.GENERAL_1: GENERAL_1,
	WorkMode.GENERAL_2: GENERAL_2,
	WorkMode.GENERAL_3: GENERAL_3,
	WorkMode.HIGH: HIGH,
	WorkMode.POWER_MAX: POWER_MAX
}

func _ready():
	# Ensure the handle is centered at start (neutral position).
	#$"WorkModeHud".text = "Requested Work Mode: None"
	#$Shutdown.disabled = true
	#Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	
	_client.connected.connect(_handle_client_connected)
	_client.disconnected.connect(_handle_client_disconnected)
	_client.error.connect(_handle_client_error)
	_client.message.connect(_handle_client_message)
	
	add_child(_client)

	#TODO: Connect once, not once per scene
	_client.connect_to_host(Global.host, Global.port)
	$StatusPanelLeft/Mode.text = "Mode: Normal"

func _handle_client_connected() -> void:
	print("Client is connected.")
	#$Hostname.text = "Connected to: " + Global.host + ":" + str(Global.port)
	#$Instance.text = "Instance ID: " + _client._instance.instance_id.hex_encode()
	#$Name.text = "Name: " + _client._instance.name

func _handle_client_disconnected() -> void:
	print("Client disconnected from server.")

func _handle_client_error() -> void:
	print("Client error.")
	
func _handle_client_message(message_type: Client.MessageType, data: PackedByteArray) -> void:
	#print("We got message: " + str(message_type) + " with data: " + str(data))
	# print(message_type)
	if message_type == Client.MessageType.ENGINE:
		var engine = Client.EngineMessage.from_bytes(data)
		update_rpm(engine.rpm)
	# elif message_type == Client.MessageType.ECHO:
	# 	print(_client._latency)
	# 	pass

func update_rpm(rpm: int):
	$"EngineRPM".text = "Engine RPM:\n" + str(rpm)
	if rpm == 0:
		excavator["engine_state"] = EngineState.SHUTDOWN
		#$ShutdownIndicator.set_indicator(true)
		#$StartMotorIndicator.set_indicator(false)
		engine_state_changed = true
	elif rpm >= ENGINE_START_RPM:
		excavator["engine_state"] = EngineState.RUNNING
		#$ShutdownIndicator.set_indicator(false)
		#$StartMotorIndicator.set_indicator(true)
		if engine_state_changed:
			excavator["motion_state"] = MotionState.LOCKED
			engine_state_changed = false
			
func _physics_process(delta):
	#TODO: Thread
	if delta_sum >= 0.01:
		delta_sum = 0
		# _client.probe()
		_client.send_request(Client.MessageType.ENGINE)
		
			# update_indicators()
		if excavator["engine_state"] == EngineState.SHUTDOWN:
			$ShutdownIndicator.set_indicator(true)
			$StartMotorIndicator.set_indicator(false)
		elif excavator["engine_state"] == EngineState.RUNNING:
			$ShutdownIndicator.set_indicator(false)
			$StartMotorIndicator.set_indicator(true)

		if excavator["motion_state"] == MotionState.LOCKED:
			$StopMotionIndicator.set_indicator(true)
		elif excavator["motion_state"] == MotionState.UNLOCKED:
			$StopMotionIndicator.set_indicator(false)
	
	delta_sum += delta
	
func map_float_to_int_range(value: float, min_float: float, max_float: float, min_int: int, max_int: int) -> int:
	var normalized = (value - min_float) / (max_float - min_float)
	var scaled = min_int + normalized * (max_int - min_int)
	return int(round(scaled))
	
func _input(event):
	if event is InputEventJoypadMotion:
		if event.device == joystick_orientation["right_joystick"]:
			if event.axis == 3: # Slider
				var work_mode = map_float_to_int_range(event.axis_value, 1.0, -1.0, 0, 9)
				handle_work_mode(work_mode)
			
			# Ignore drift
			if abs(event.axis_value) < 0.05:
				return
				
			if !motion_allowed(false):
				$JoystickOuterRight.toggle_color_duration(0.1)
				return
		
			if event.axis == 0: # X axis
				handle_attachment(event.axis_value)
			elif event.axis == 1: # Y axis
				handle_boom(event.axis_value)
			# # TODO: These requests are redundant requests most of the time, find a better method
			# # Send rpm request when joystick is moved and previously the rpm was ignored (because of shutdown)
			# var slider_value = Input.get_joy_axis(joystick_orientation["right_joystick"], 3)
			# var work_mode = map_float_to_int_range(slider_value, 1.0, -1.0, 0, 9)
			# handle_work_mode(work_mode) 

		elif event.device == joystick_orientation["left_joystick"]:
			#TODO: handle_left_joystick(event.axis, event.axis_value)
			if event.axis == 3: # Slider
				if demo_mode:
					var rpm = map_float_to_int_range(event.axis_value, 1.0, -1.0, 0, 2000)
					update_rpm(rpm)
			
			# Ignore drift
			if abs(event.axis_value) < 0.05:
				return
				
			if !motion_allowed(false):
				$JoystickOuterLeft.toggle_color_duration(0.1)				
				return
				 
			if event.axis == 0: # X axis
				handle_slew(event.axis_value)
			elif event.axis == 1: # Y axis
				handle_arm(event.axis_value)
			# # TODO: These requests are redundant requests most of the time, find a better method
			# # Send rpm request when joystick is moved and previously the rpm was ignored (because of shutdownn)
			# var slider_value = Input.get_joy_axis(joystick_orientation["right_joystick"], 3)
			# var work_mode = map_float_to_int_range(slider_value, 1.0, -1.0, 0, 9)
			# handle_work_mode(work_mode) 

	elif event is InputEventJoypadButton:
		if event.device == joystick_orientation["right_joystick"]:
			# print(event)
			if event.button_index == 8: # Middle Left
				toggle_demo_mode(event.pressed)
			elif event.button_index == 9: # Middle right
				handle_stop(event.pressed)
			elif event.button_index == 10: # Bottom left
				handle_start(event.pressed)
			elif event.button_index == 11: # Bottom right
				handle_shutdown(event.pressed)

func toggle_demo_mode(pressed: bool):
	if !pressed:
		return
	demo_mode = !demo_mode
	if demo_mode:
		_client.message.disconnect(_handle_client_message)
		$StatusPanelLeft/Mode.text = "Mode: Demo"
	else:
		_client.message.connect(_handle_client_message)
		$StatusPanelLeft/Mode.text = "Mode: Normal"

func handle_shutdown(pressed: bool):
	if !pressed:
		$Shutdown.set_pressed(false)
		return

	if excavator["engine_state"] == EngineState.SHUTDOWN:
		# TODO: Set border to indicate pressed but not correct 
		print("Engine is already shutdown")
		return
	
	if !request_shutdown():
		print("Request shutdown communication error")
		return

	$Shutdown.set_pressed(true)

func handle_start(pressed: bool):
	if !pressed:
		$StartMotor.set_pressed(false)
		return
	
	if excavator["engine_state"] == EngineState.RUNNING:
		print("Engine is already running")
		return

	#if excavator["motion_state"] == MotionState.LOCKED:
		#print("Motion is locked, engine cannot be started")
		#return

	if !request_start_motor():
		print("Request start motor communication error")
		return

	$StartMotor.set_pressed(true)

func handle_stop(pressed: bool):
	if pressed:
		if request_stop_motion():
			$StopMotion.set_pressed(true)
			$StopMotionIndicator.set_indicator(true)
			excavator["motion_state"] = MotionState.LOCKED
	else:
		if request_resume_motion():
			$StopMotion.set_pressed(false)
			$StopMotionIndicator.set_indicator(false)
			excavator["motion_state"] = MotionState.UNLOCKED

					
func handle_attachment(axis_value: float) -> bool:
	#print("handle_attachment ", axis_value)
	$JoystickInnerRight.position.x = $JoystickInnerRight.start_position.x + axis_value * JOYSTICK_MAX_HANDLE_DISTANCE

	var motion = Client.MotionMessage.new()
	motion.command = Client.CHANGE
	
	var change_set = Client.MotionChangeSetMessage.new()
	change_set.actuator = 5
	change_set.value = map_float_to_int_range(axis_value, -1.0, 1.0, 0, 32_000)
	
	motion.value_list = [change_set]
	
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())
	
func handle_boom(axis_value: float) -> bool:
	#print("handle_boom ", axis_value)
	$JoystickInnerRight.position.y = $JoystickInnerRight.start_position.y + axis_value * JOYSTICK_MAX_HANDLE_DISTANCE

	var motion = Client.MotionMessage.new()
	motion.command = Client.CHANGE
	
	var change_set = Client.MotionChangeSetMessage.new()
	change_set.actuator = 0
	change_set.value = map_float_to_int_range(axis_value, -1.0, 1.0, 0, 32_000)
	
	motion.value_list = [change_set]
	
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())

func handle_slew(axis_value: float) -> bool:
	#print("handle_slew ", axis_value)
	$JoystickInnerLeft.position.x = $JoystickInnerLeft.start_position.x + axis_value * JOYSTICK_MAX_HANDLE_DISTANCE

	var motion = Client.MotionMessage.new()
	motion.command = Client.CHANGE
	
	var change_set = Client.MotionChangeSetMessage.new()
	change_set.actuator = 1
	change_set.value = map_float_to_int_range(axis_value, -1.0, 1.0, 0, 32_000)
	
	motion.value_list = [change_set]
	
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())
	
func handle_arm(axis_value: float) -> bool:
	#print("handle_arm ", axis_value)
	$JoystickInnerLeft.position.y = $JoystickInnerLeft.start_position.y + axis_value * JOYSTICK_MAX_HANDLE_DISTANCE

	var motion = Client.MotionMessage.new()
	motion.command = Client.CHANGE
	
	var change_set = Client.MotionChangeSetMessage.new()
	change_set.actuator = 4
	change_set.value = map_float_to_int_range(axis_value, -1.0, 1.0, 0, 32_000)
	
	motion.value_list = [change_set]
	
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())

func motion_allowed(print_error: bool) -> bool:
	if excavator["engine_state"] != EngineState.RUNNING:
		if print_error:
			print("Engine not started")
		return false

	if excavator["motion_state"] == MotionState.LOCKED:
		if print_error:
			print("Stop motion enabled")
		return false

	return true

func request_start_motor() -> bool:
	if request_work_mode(WorkMode.IDLE_1):
		#change_work_mode_text(WorkMode.IDLE_1)
		$WorkModeHud/WorkModeSlider.value = WorkMode.IDLE_1
		return true
	return false
	
func request_shutdown() -> bool:
	var engine = Client.EngineMessage.new()
	engine.rpm = 0
	return _client.send(Client.MessageType.ENGINE, engine.to_bytes())
	# var control = Client.ControlMessage.new()
	# control.control_type = Client.ControlType.ENGINE_SHUTDOWN
	# return _client.send(Client.MessageType.CONTROL, control.to_bytes())

func request_stop_motion() -> bool:
	print("stop motion")
	var motion = Client.MotionMessage.stop_all()
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())

func request_resume_motion() -> bool:
	print("resume motion")
	var motion = Client.MotionMessage.resume_all()
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())

func request_work_mode(work_mode: WorkMode) -> bool:
	print("sending work mode request")

	# var control = Client.ControlMessage.new()
	# control.control_type = Client.ControlType.ENGINE_REQUEST
	# control.value = WorkModeRPM[work_mode]
	# return _client.send(Client.MessageType.CONTROL, control.to_bytes())

	var engine = Client.EngineMessage.new()
	engine.rpm = WorkModeRPM[work_mode]
	return _client.send(Client.MessageType.ENGINE, engine.to_bytes())

# func change_work_mode_text(work_mode: WorkMode):
# 	$WorkModeHud/WorkModeSlider.value = work_mode
# 	#$"WorkModeSlider/WorkModeLabel".text = "Requested Work Mode: " + WorkModeName[work_mode]

func handle_work_mode(work_mode_value: int):
	if work_mode_value not in WorkMode.values():
		print("Error, not a work mode value")
		return
	
	$WorkModeHud/WorkModeSlider.value = work_mode_value

	if excavator["engine_state"] != EngineState.RUNNING:
		print("Engine not started")
		return 

	if request_work_mode(work_mode_value):
		#change_work_mode_text(work_mode_value)
		excavator["work_mode"] = work_mode_value
