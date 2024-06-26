extends Node2D

const JOYSTICK_MAX_HANDLE_DISTANCE = 25
const JOYSTICK_DEADZONE = 0.1
const ENGINE_START_RPM = 500
const MOTION_MAX = 32000
const MOTION_MIN = -32000
const MOTION_MAX_DEFAULT = 16000
const MOTION_MIN_DEFAULT = -16000
const LIMIT_GOOD_LATENCY = 50
const LIMIT_AVERAGE_LATENCY = 100
const LIMIT_BAD_LATENCY = 150

const LATENCY_STRING = "Latency: "
const PROFILE_STRING = "Profile: "
const ID_STRING = "ID: "
const IP_STRING = "IP: "
const SN_STRING = "SN: "
const VERSION_STRING = "Version: "
const MODE_STRING = "Mode: "
const STATUS_STRING = "Status: "
const OPERATOR_TIME_STRING = "Operator time: "
const EXCAVATOR_TIME_STRING = "Time: "
const EXCAVATOR_UPTIME_STRING = "Uptime: "

@onready var joystick_right = $JoypadPanel/JoystickRight
@onready var joystick_left = $JoypadPanel/JoystickLeft
@onready var start_button = $JoypadPanel/StartMotor
@onready var start_indicator = $JoypadPanel/StartMotorIndicator
@onready var shutdown_button = $JoypadPanel/Shutdown
@onready var shutdown_indicator = $JoypadPanel/ShutdownIndicator
@onready var stop_button = $JoypadPanel/StopMotion
@onready var stop_indicator = $JoypadPanel/StopMotionIndicator

@onready var workmode_slider = $EnginePanel/WorkModeHud/WorkModeSlider
@onready var rpm_indicator = $EnginePanel/EngineRPM

#TODO: Need calibration and init
var joypad_map = {
	"right": 0,
	"left": 1,
	"x": 0,
	"y": 1,
	"slider": 3,
	"demo": 8,
	"stop_motion": 9,
	"start": 10,
	"stop": 11,
}

enum Actuator {
	BOOM = 0,
	SLEW = 1,
	LIMPRIGHT = 2,
	LIMPLEFT = 3,
	ARM = 4,
	ATTACHMENT = 5,
}

var motion_value = {
	"max": MOTION_MAX_DEFAULT,
	"min": MOTION_MIN_DEFAULT,
} 

var delta_sum_ping = 0
var delta_sum_engine = 0

const Client = preload ("res://glonax-client.gd")
var _client

var _excavator_uptime = 0
var _excavator_time = 0

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
var engine_started_rpm_update = false
var latency_bad = false

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
	
	init_client()

	#TODO: Connect once, not once per scene

	$StatusPanelLeft/Mode.text = "Mode: Normal"

	var timer : Timer = Timer.new()
	add_child(timer)
	timer.one_shot = false
	timer.autostart = true
	timer.wait_time = 0.5
	timer.timeout.connect(time_update)
	timer.start()

func time_update():
	var utc = true
	var now = Time.get_datetime_dict_from_system(utc)
	var time_string = "%02d:%02d:%02d" % [now.hour, now.minute, now.second]
	$StatusPanelRight/OperatorTime.text = OPERATOR_TIME_STRING + time_string
	
	var excavator_time = Time.get_datetime_dict_from_unix_time(_excavator_time)
	var excavator_time_string = "%02d:%02d:%02d" % [excavator_time.hour, excavator_time.minute, excavator_time.second]
	$StatusPanelRight/Excavator/Time.text = EXCAVATOR_TIME_STRING + excavator_time_string

	var days_up: int = _excavator_uptime / 86400
	var hours_up: int = (_excavator_uptime % 86400) / 3600
	var min_up: int = (_excavator_uptime % 3600) / 60
	var sec_up: int = _excavator_uptime % 60
	var time_up = "%d:%02d:%02d:%02d" % [days_up, hours_up, min_up, sec_up]
	$StatusPanelRight/Excavator/Uptime.text = EXCAVATOR_UPTIME_STRING + time_up 

func init_client():
	_client = Client.new("godot/4.2")
	_client.connected.connect(_handle_client_connected)
	_client.disconnected.connect(_handle_client_disconnected)
	_client.error.connect(_handle_client_error)
	_client.message.connect(_handle_client_message)
	_client.connect_to_host(Global.host, Global.port)
	add_child(_client)

func deinit_client():
	#_client._finalize()
	remove_child(_client)

func _handle_client_connected() -> void:
	print("Client is connected.")
	var version_string = str(_client._instance.version_major) + "." + str(_client._instance.version_minor) + "." + str(_client._instance.version_patch)
	$StatusPanelLeft/Profile/Version.text = VERSION_STRING + version_string
	
	var hex_string = _client._instance.instance_id.hex_encode()
	var client_id_substr = hex_string.substr(hex_string.length() - 8, 8)
	$StatusPanelLeft/Profile/ID.text = ID_STRING + "..." + client_id_substr
	$StatusPanelLeft/Profile/IP.text = IP_STRING + Global.host
	$StatusPanelLeft/Status.text = STATUS_STRING + "✅ Connected"
	$StatusPanelLeft/Profile/SN.text = SN_STRING + _client._instance.serial_number

func _handle_client_disconnected() -> void:
	$StatusPanelLeft/Status.text = STATUS_STRING + "❌ Disconnected, reconnecting..."
	print("Client disconnected from server.")
	print("Reconnect.")
	deinit_client()
	init_client()
	# _client.reconnect(Global.host, Global.port)

func _handle_client_error() -> void:
	$StatusPanelLeft/Status.text = STATUS_STRING + "❌ Error"
	print("Client error.")
	
func _handle_client_message(message_type: Client.MessageType, data: PackedByteArray) -> void:
	#print("We got message: " + str(message_type) + " with data: " + str(data))
	# print(message_type)
	if message_type == Client.MessageType.ENGINE:
		var engine = Client.EngineMessage.from_bytes(data)
		update_rpm(engine.rpm)
	elif message_type == Client.MessageType.VMS:
		var vms = Client.VMSMessage.from_bytes(data)
		_excavator_uptime = vms.uptime
		_excavator_time = vms.timestamp

func update_rpm(rpm: int):
	rpm_indicator.text = "Engine RPM:\n" + str(rpm)
	if rpm == 0:
		excavator["engine_state"] = EngineState.SHUTDOWN
		engine_state_changed = true
	elif rpm >= ENGINE_START_RPM:
		excavator["engine_state"] = EngineState.RUNNING
		if engine_state_changed:
			excavator["motion_state"] = MotionState.LOCKED
			engine_state_changed = false
			# TODO: This should be replaced by something more scalable
			# Save flag which can be set on false when rpm is updated by any motion 
			engine_started_rpm_update = true
			
func handle_latency() -> bool:
	var latency_icon = "❌"
	var warning = ""
	latency_bad = false
	if _client._latency <= LIMIT_GOOD_LATENCY:
		latency_icon = "🟢"
	elif _client._latency <= LIMIT_AVERAGE_LATENCY:
		latency_icon = "🟠"
	elif _client._latency <= LIMIT_BAD_LATENCY:
		latency_icon = "🔴"
	else: 
		if request_stop_motion():
			stop_button.set_pressed(true)
			stop_indicator.set_indicator(true)
			excavator["motion_state"] = MotionState.LOCKED
			warning = " Connection quality BAD, motion locked"
			latency_bad = true
		else: 
			warning = " Connection quality BAD, motion lock FAILED"

	$StatusPanelLeft/Latency.text = LATENCY_STRING + latency_icon + " " + str(_client._latency) + " ms" + warning
	return _client.probe()

func _physics_process(delta):
	#TODO: Thread 
	#TODO: Timers
	delta_sum_ping += delta
	if delta_sum_ping >= 1:
		delta_sum_ping = 0
		handle_latency()

	if excavator["engine_state"] == EngineState.SHUTDOWN:
		shutdown_indicator.set_indicator(true)
		start_indicator.set_indicator(false)
	elif excavator["engine_state"] == EngineState.RUNNING:
		shutdown_indicator.set_indicator(false)
		start_indicator.set_indicator(true)

	if excavator["motion_state"] == MotionState.LOCKED:
		stop_indicator.set_indicator(true)
	elif excavator["motion_state"] == MotionState.UNLOCKED:
		stop_indicator.set_indicator(false)

func map_float_to_int_range(value: float, min_float: float, max_float: float, min_int: int, max_int: int) -> int:
	var normalized = (value - min_float) / (max_float - min_float)
	var scaled = min_int + normalized * (max_int - min_int)
	return int(round(scaled))
	
func _input(event):
	# print(event)
	if event is InputEventJoypadMotion:
		if not (event.device == joypad_map["left"]) and not (event.device == joypad_map["right"]):
			return
		if event.axis == joypad_map["x"] or event.axis == joypad_map["y"]:			
			handle_joystick(event)
		elif event.axis == joypad_map["slider"]:
			handle_slider(event)
	elif event is InputEventJoypadButton:
		handle_joypad_buttons(event)

func handle_joypad_buttons(event):
	if event.device != joypad_map["right"]:
		return

	if event.button_index == 8: # Middle Left
		toggle_demo_mode(event.pressed)
	elif event.button_index == 9: # Middle right
		handle_stop(event.pressed)
	elif event.button_index == 10: # Bottom left
		handle_start(event.pressed)
	elif event.button_index == 11: # Bottom right
		handle_shutdown(event.pressed)

func handle_slider(event):
	if event.device == joypad_map["right"]:
		var work_mode = map_float_to_int_range(event.axis_value, 1.0, -1.0, 0, 9)
		handle_work_mode(work_mode)
	elif event.device == joypad_map["left"] and demo_mode:
		var rpm = map_float_to_int_range(event.axis_value, 1.0, -1.0, 0, 2000)
		update_rpm(rpm)

func handle_joystick(event):
	var joystick
	var actuator
	if event.device == joypad_map["right"] and event.axis == joypad_map["x"]:
		joystick = joystick_right
		actuator =  Actuator.ATTACHMENT
	elif event.device == joypad_map["left"] and event.axis == joypad_map["x"]:
		joystick = joystick_left
		actuator =  Actuator.SLEW
	elif event.device == joypad_map["right"] and event.axis == joypad_map["y"]:
		joystick = joystick_right
		actuator =  Actuator.BOOM
	elif event.device == joypad_map["left"] and event.axis == joypad_map["y"]:
		joystick = joystick_left
		actuator =  Actuator.ARM
		
	if !motion_allowed():
		joystick.get_node("JoystickOuter").toggle_color_duration(0.1)
		return

	if event.axis == joypad_map["x"]:
		joystick.get_node("JoystickInner").position.x = joystick.get_node("JoystickInner").start_position.x + event.axis_value * JOYSTICK_MAX_HANDLE_DISTANCE
	elif event.axis == joypad_map["y"]:
		joystick.get_node("JoystickInner").position.y = joystick.get_node("JoystickInner").start_position.y + event.axis_value * JOYSTICK_MAX_HANDLE_DISTANCE

	#ignore drift
	var x_abs = abs(Input.get_joy_axis(event.device, joypad_map["x"]))
	var y_abs = abs(Input.get_joy_axis(event.device, joypad_map["y"]))
	if x_abs <= JOYSTICK_DEADZONE and y_abs <= JOYSTICK_DEADZONE:
		return

	send_motion_message(event.axis_value, actuator)

	if engine_started_rpm_update:
		var slider_value = Input.get_joy_axis(joypad_map["right"], joypad_map["slider"])
		var work_mode = map_float_to_int_range(slider_value, 1.0, -1.0, 0, 9)
		handle_work_mode(work_mode) 
		engine_started_rpm_update = false
	
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
		shutdown_button.set_pressed(false)
		return

	if excavator["engine_state"] == EngineState.SHUTDOWN:
		print("Engine is already shutdown")
		return
	
	if !request_shutdown():
		print("Request shutdown communication error")
		return

	shutdown_button.set_pressed(true)

func handle_start(pressed: bool):
	if !pressed:
		start_button.set_pressed(false)
		return
	
	if excavator["engine_state"] == EngineState.RUNNING:
		print("Engine is already running")
		return

	if !request_start_motor():
		print("Request start motor communication error")
		return

	start_button.set_pressed(true)

func handle_stop(pressed: bool):
	if latency_bad:
		print("Connection quality BAD, motion locked")
		return

	if pressed:
		if request_stop_motion():
			stop_button.set_pressed(true)
			stop_indicator.set_indicator(true)
			excavator["motion_state"] = MotionState.LOCKED
	else:
		if request_resume_motion():
			stop_button.set_pressed(false)
			stop_indicator.set_indicator(false)
			excavator["motion_state"] = MotionState.UNLOCKED

func send_motion_message(axis_value: float, actuator: Actuator) -> bool:
	var motion = Client.MotionMessage.new()
	motion.command = Client.CHANGE
	
	var change_set = Client.MotionChangeSetMessage.new()
	change_set.actuator = actuator
	change_set.value = map_float_to_int_range(axis_value, -1.0, 1.0, MOTION_MAX, MOTION_MIN)
	
	motion.value_list = [change_set]
	
	return _client.send(Client.MessageType.MOTION, motion.to_bytes())

func motion_allowed() -> bool:
	if excavator["engine_state"] != EngineState.RUNNING:
		return false

	if excavator["motion_state"] == MotionState.LOCKED:
		return false

	return true

func request_start_motor() -> bool:
	if request_work_mode(WorkMode.IDLE_1):
		workmode_slider.value = WorkMode.IDLE_1
		return true
	return false
	
func request_shutdown() -> bool:
	var engine = Client.EngineMessage.new()
	engine.rpm = 0
	return _client.send(Client.MessageType.ENGINE, engine.to_bytes())

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

	var engine = Client.EngineMessage.new()
	engine.rpm = WorkModeRPM[work_mode]
	return _client.send(Client.MessageType.ENGINE, engine.to_bytes())


func handle_work_mode(work_mode_value: int):
	if work_mode_value not in WorkMode.values():
		print("Error, not a work mode value")
		return
	
	workmode_slider.value = work_mode_value

	if excavator["engine_state"] != EngineState.RUNNING:
		print("Engine not started")
		return 

	if request_work_mode(work_mode_value):
		excavator["work_mode"] = work_mode_value
		engine_started_rpm_update = false
