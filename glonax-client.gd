extends Node

class_name Glonax

signal connected
signal data
signal disconnected
signal error
signal message

var _user_agent: String = "godot"
var _status: int = 0
var _stream: StreamPeerTCP = StreamPeerTCP.new()
var _is_handshake_setup: bool = false
var _is_session_setup: bool = false
var _echo: EchoMessage
var _instance: InstanceMessage
var _latency: float = 0
var _ping_start_time_msec: int = 0
var _receive_thread: Thread
var _should_run_receive_t: bool = false

const PING_TIMEOUT: float = 1000

enum MessageType {
	ERROR = 0x0,
	ECHO = 0x1,
	SESSION = 0x10,
	SHUTDOWN = 0x11,
	REQUEST = 0x12,
	INSTANCE = 0x15,
	STATUS = 0x16,
	MOTION = 0x20,
	ACTOR = 0x40,
	VMS = 0x41,
	GNSS = 0x42,
	ENGINE = 0x43,
	TARGET = 0x44,
	CONTROL = 0x45,
}

#############################

class Message:
	static func _encode_be_s16(value):
		return [(value >> 8) & 0xFF, value & 0xFF]
		
	static func _encode_be_s32(value):
		var buffer = PackedByteArray()
		buffer.resize(4)

		buffer.set(0, (value >> 24) & 0xFF)
		buffer.set(1, (value >> 16) & 0xFF) 
		buffer.set(2, (value >> 8) & 0xFF)
		buffer.set(3, value & 0xFF)

		return buffer

	static func _encode_be_s64(value):
		var buffer = PackedByteArray()
		buffer.resize(8)

		buffer.set(0, (value >> 56) & 0xFF)
		buffer.set(1, (value >> 48) & 0xFF)
		buffer.set(2, (value >> 40) & 0xFF)
		buffer.set(3, (value >> 32) & 0xFF)
		buffer.set(4, (value >> 24) & 0xFF)
		buffer.set(5, (value >> 16) & 0xFF)
		buffer.set(6, (value >> 8) & 0xFF)
		buffer.set(7, value & 0xFF)

		return buffer

	static func _decode_be_s16(byte_array):
		if len(byte_array) != 2:
			return -1 
		return (byte_array[0] << 8) | byte_array[1] 

	static func _decode_be_s32(byte_array):
		if len(byte_array) != 4:
			return -1 

		var result = 0
		result |= byte_array[0] << 24
		result |= byte_array[1] << 16
		result |= byte_array[2] << 8
		result |= byte_array[3]
		return result 
		
	static func _decode_be_s64(byte_array):
		if len(byte_array) != 8:
			return -1 

		var result = 0
		result |= byte_array[0] << 56
		result |= byte_array[1] << 48
		result |= byte_array[2] << 40
		result |= byte_array[3] << 32
		result |= byte_array[4] << 24
		result |= byte_array[5] << 16
		result |= byte_array[6] << 8
		result |= byte_array[7]
		return result

#############################

enum {
	STOP_ALL = 0x0,
	RESUME_ALL = 0x1,
	RESET_ALL = 0x2,
	STRAIGHT_DRIVE = 0x5,
	CHANGE = 0x10
}

class MotionChangeSetMessage:
	var actuator
	var value

class MotionMessage:
	extends Message

	var command = STOP_ALL
	var value
	var value_list: Array

	static func stop_all() -> MotionMessage:
		var motion = MotionMessage.new()
		motion.command = STOP_ALL

		return motion

	static func resume_all() -> MotionMessage:
		var motion = MotionMessage.new()
		motion.command = RESUME_ALL

		return motion

	func to_bytes() -> PackedByteArray:
		var buffer = PackedByteArray()
		buffer.append(command)

		match command:
			STRAIGHT_DRIVE:
				buffer.append_array(_encode_be_s16(value))
			CHANGE:
				buffer.append(value_list.size())
				for change_set in value_list:
					buffer.append_array(_encode_be_s16(change_set.actuator))
					buffer.append_array(_encode_be_s16(change_set.value))
		return buffer

#############################

class EchoMessage:
	extends Message
	
	var value
	
	func _init():
		value = randi()

	func to_bytes() -> PackedByteArray:
		return _encode_be_s32(value)

	static func from_bytes(data: PackedByteArray) -> EchoMessage:
		var echo = EchoMessage.new()
		echo.value = _decode_be_s32(data)

		return echo

#############################

class SessionMessage:
	extends Message
	
	var flags: int = 0
	var name: String

	func to_bytes() -> PackedByteArray:
		var buffer = PackedByteArray()
		buffer.append(flags)
		buffer.append_array(name.to_utf8_buffer())

		return buffer

	static func from_bytes(data: PackedByteArray) -> SessionMessage:
		var session = SessionMessage.new()
		session.flags = data.decode_u8(0)
		session.name = data.slice(1, data.size()).get_string_from_utf8()

		return session

#############################

class RequestMessage:
	extends Message
	
	var message_type: MessageType

	func to_bytes() -> PackedByteArray:
		var buffer = PackedByteArray()
		buffer.append(message_type)

		return buffer

	static func from_bytes(data: PackedByteArray) -> RequestMessage:
		var request = RequestMessage.new()
		request.message_type = data.decode_u8(0)

		return request

#############################

enum StatusType {
	HEALTHY = 0xF8,
	DEGRADED = 0xF9,
	FAULTY = 0xFA,
	EMERGENCY = 0xFB
}

class StatusMessage:
	extends Message
	
	var status_type: StatusType

	func to_bytes() -> PackedByteArray:
		var buffer = PackedByteArray()
		buffer.append(status_type)

		return buffer

	static func from_bytes(data: PackedByteArray) -> StatusMessage:
		var status = StatusMessage.new()
		status.status_type = data.decode_u8(0)

		return status

#############################

class InstanceMessage:
	extends Message

	var instance_id
	var machine_type
	var version_major
	var version_minor
	var version_patch
	var name

	func to_bytes() -> PackedByteArray:
		var buffer = PackedByteArray()
		buffer.append_array(instance_id)
		buffer.append(machine_type)
		buffer.append(version_major)
		buffer.append(version_minor)
		buffer.append(version_patch)
		buffer.append_array(name.to_utf8_buffer())

		return buffer

	static func from_bytes(data: PackedByteArray) -> InstanceMessage:
		var instance = InstanceMessage.new()
		instance.instance_id = data.slice(0, 16)
		instance.machine_type = data.decode_u8(16)
		instance.version_major = data.decode_u8(17)
		instance.version_minor = data.decode_u8(18)
		instance.version_patch = data.decode_u8(19)

		var name_len = _decode_be_s16(data.slice(20, 22))
		instance.name = data.slice(22, 22 + name_len).get_string_from_utf8()

		return instance

	func get_string_representation():
		return "Instance ID: " + instance_id.hex_encode() + "; Machine Type: " + str(machine_type) + "; Version: " + str(version_major) + "." + str(version_minor) + "." + str(version_patch) + "; Name: " + name

#############################

class VMSMessage:
	extends Message

	var memory_used
	var memory_total
	var swap_used
	var swap_total
	var cpu_load_0
	var cpu_load_1
	var cpu_load_2
	var uptime
	var timestamp

	static func from_bytes(data: PackedByteArray) -> VMSMessage:
		var vms = VMSMessage.new()
		vms.memory_used = _decode_be_s64(data.slice(0, 8))
		vms.memory_total = _decode_be_s64(data.slice(8, 16))
		vms.swap_used = _decode_be_s64(data.slice(16, 24))
		vms.swap_total = _decode_be_s64(data.slice(24, 32))
		#vms.cpu_load_0 = TODO: Decode BE double
		#vms.cpu_load_1 = TODO: Decode BE double
		#vms.cpu_load_2 = TODO: Decode BE double
		vms.uptime = _decode_be_s64(data.slice(56, 64))
		vms.timestamp = _decode_be_s64(data.slice(64, 72))

		return vms

#############################

enum EngineState {
	NO_REQUEST = 0x0,
	STARTING = 0x1,
	STOPPING = 0x2,
	REQUEST = 0x10
}

class EngineMessage:
	extends Message

	var driver_demand
	var actual_engine
	var rpm
	var state: EngineState

	func to_bytes() -> PackedByteArray:
		var buffer = PackedByteArray()
		buffer.append(0)
		buffer.append(0)
		buffer.append_array(_encode_be_s16(rpm))
		buffer.append(state)
		# print(buffer)
		return buffer

	static func from_bytes(data: PackedByteArray) -> EngineMessage:
		var engine = EngineMessage.new()
		engine.driver_demand = data.decode_u8(0)
		engine.actual_engine = data.decode_u8(1)
		engine.rpm = _decode_be_s16(data.slice(2, 4))
		engine.state = data.decode_u8(4)

		return engine

	# TODO: Override to_string
	func get_string_representation():
		return "Driver demand: " + str(driver_demand) + "%; Actual engine: " + str(actual_engine) + "%; RPM: " + str(rpm)

#############################

class GNSSMessage:
	extends Message

	var location_lat
	var location_long
	var altitude
	var speed
	var heading
	var satellites

	static func from_bytes(data: PackedByteArray) -> GNSSMessage:
		var gnss = GNSSMessage.new()
		#gnss.location_lat = TODO: Decode BE float
		#gnss.location_long = TODO: Decode BE float
		#gnss.altitude = TODO: Decode BE float
		#gnss.speed = TODO: Decode BE float
		#gnss.heading = TODO: Decode BE float
		gnss.satellites = data.decode_u8(100)

		return gnss

#############################

enum ControlType {
	ENGINE_REQUEST = 0x1,
	ENGINE_SHUTDOWN = 0x2,
	HYDRAULIC_QUICK_DISCONNECT = 0x5,
	HYDRAULIC_LOCK = 0x6,
	MACHINE_SHUTDOWN = 0x1B,
	MACHINE_ILLUMINATION = 0x1C,
	MACHINE_LIGHTS = 0x1D,
	MACHINE_HORN = 0x1E,
}

class ControlMessage:
	extends Message

	var control_type: ControlType
	var value

	func to_bytes() -> PackedByteArray:
		var buffer = PackedByteArray()
		buffer.append(control_type)
		if control_type == ControlType.ENGINE_REQUEST:
			buffer.append_array(_encode_be_s16(value))

		return buffer

	static func from_bytes(data: PackedByteArray) -> ControlMessage:
		var control = ControlMessage.new()
		control.control_type = data.decode_u8(0)
		if control.control_type == ControlType.ENGINE_REQUEST:
			control.value = _decode_be_s16(data.slice(1, 3))

		return control

#############################

func _init(user_agent: String = "godot"):
	_stream.set_big_endian(true)
	_stream.set_no_delay(true)
	_user_agent = user_agent
	_should_run_receive_t = true 
	_receive_thread = Thread.new()
	_receive_thread.start(_receive_thread_func)

var recv_counter = 0
var send_counter = 0
# TODO: replace this thread by c++ GDextension
func _receive_thread_func():
	while _should_run_receive_t:
		_stream.poll()

		var new_status: int = _stream.get_status()
		if new_status != _status:
			_status = new_status
			match _status:
				_stream.STATUS_NONE:
					print("Error, status none, disconnect.")
					call_deferred("emit_signal", "disconnected")
					break
				_stream.STATUS_CONNECTING:
					# pass
					print("Connecting...")
					OS.delay_msec(10)
					continue
				_stream.STATUS_CONNECTED:
					_handshake()
				_stream.STATUS_ERROR:
					print("Error with socket stream.")
					call_deferred("emit_signal", "error")
					break

		# When we are in the initial state do not recv data, instead wait
		if _stream.get_status() == StreamPeerTCP.STATUS_NONE:
			OS.delay_msec(10)
			continue

		var data_array = _stream.get_data(10)
		if data_array[0] != OK:
			call_deferred("emit_signal", "error")
			continue
		var recv_data = data_array[1]
		process_received_data(recv_data)

func process_received_data(recv_data):
	recv_counter += 1
	var header = recv_data.slice(0, 3)
	if header != PackedByteArray([0x4C, 0x58, 0x52]):
		print("Error, unexpected header: ", header)
		call_deferred("emit_signal", "error")
	var version = recv_data[3]
	if version != 0x3:
		print("Error getting data from stream: invalid version")
		call_deferred("emit_signal", "error")
	var message_type = recv_data[4]
	var payload_length = Message._decode_be_s16(recv_data.slice(5, 7))
	assert(recv_data.slice(7, 10) == PackedByteArray([0x0, 0x0, 0x0]))
	var payload = _stream.get_partial_data(payload_length)
	if payload[0] != OK:
		print("Error getting data from stream: ", payload[0])
		call_deferred("emit_signal", "error")
	else:
		_recv(message_type, payload[1])

func _finalize():
	_should_run_receive_t = false
	_stream.disconnect_from_host()
	_receive_thread.wait_to_finish()

func _exit_tree():
	_finalize()

var delta_sum = 0
func _physics_process(delta: float) -> void:
	delta_sum += delta
	if delta_sum > 1:
		print ("recv counter: ", recv_counter)
		print ("send counter: ", send_counter)
		delta_sum = 0

	# if _stream.get_status() != _stream.STATUS_NONE:
	# 	_stream.poll()

	# var new_status: int = _stream.get_status()
	# if new_status != _status:
	# 	_status = new_status
	# 	match _status:
	# 		_stream.STATUS_NONE:
	# 			emit_signal("disconnected")
	# 		_stream.STATUS_CONNECTING:
	# 			pass
	# 		_stream.STATUS_CONNECTED:
	# 			_handshake()
	# 		_stream.STATUS_ERROR:
	# 			print("Error with socket stream.")
	# 			emit_signal("error")


func _recv(message_type: MessageType, payload: PackedByteArray):
	if message_type == MessageType.ECHO:
		# Ping
		if _ping_start_time_msec != 0:
			var echo = EchoMessage.from_bytes(payload)
			if echo.value != _echo.value:
				print("Error, echo send and receive msgs are not the same")
				_ping_start_time_msec = 0
				return
			_latency = Time.get_ticks_msec() - _ping_start_time_msec
			_ping_start_time_msec = 0

		if not _is_handshake_setup:
			_is_handshake_setup = true
			var session = SessionMessage.new()
			session.flags = 6
			session.name = _user_agent
			send(MessageType.SESSION, session.to_bytes())

	elif message_type == MessageType.INSTANCE:
		_instance = InstanceMessage.from_bytes(payload)
		print(_instance.get_string_representation())
		_is_session_setup = true
		call_deferred("emit_signal", "connected")

	elif _is_session_setup:
		call_deferred("emit_signal", "message", message_type, payload)

func _handshake():
	if not _is_handshake_setup:
		probe()

func is_setup_complete() -> bool:
	return _is_session_setup

func connect_to_host(host: String, port: int) -> void:
	if _status == _stream.STATUS_CONNECTED:
		print("Error: Client is already connected")
		return

	# Reset status so we can tell if it changes to error again.
	_status = _stream.STATUS_NONE
	print("Connecting to %s:%d" % [host, port])
	if _stream.connect_to_host(host, port) != OK:
		print("Error connecting to host.")
		emit_signal("error")

func send_request(message_type: MessageType):
	var request = RequestMessage.new()
	request.message_type = message_type
	send(MessageType.REQUEST, request.to_bytes())

func send(message_type: MessageType, payload: PackedByteArray) -> bool:
	if _status != _stream.STATUS_CONNECTED:
		print("Error: Stream is not currently connected.")
		return false
#
	_stream.put_data([0x4C, 0x58, 0x52])
	_stream.put_8(0x3)
	_stream.put_8(message_type)
	_stream.put_16(payload.size())
	_stream.put_data([0x0, 0x0, 0x0])

	var error: int = _stream.put_data(payload)
	if error != OK:
		print("Error writing to stream: ", error)
		return false
	send_counter += 1
	return true

func probe() -> bool:
	if _ping_start_time_msec != 0:
		print("Ping/echo already started")
		return false

	_ping_start_time_msec = Time.get_ticks_msec()

	_echo = EchoMessage.new()

	return send(MessageType.ECHO, _echo.to_bytes())
