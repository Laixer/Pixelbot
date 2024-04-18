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
var _is_echo_setup: bool = false
var _is_session_setup: bool = false
var _echo: EchoMessage
var _instance: InstanceMessage

enum MessageType {
	ERROR = 0x0,
	ECHO = 0x1,
	SESSION = 0x10,
	SHUTDOWN = 0x11,
	REQUEST = 0x12,
	INSTANCE = 0x15,
	STATUS = 0x20,
	MOTION = 0x17,
	SIGNAL = 0x31,
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
				buffer.append(command)
				buffer.append_array(_encode_be_s16(value))
			CHANGE:
				buffer.append(command)
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

class InstanceMessage:
	extends Message

	var instance_id
	var machine_type
	var version_major
	var version_minor
	var version_patch
	var name

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

class EngineMessage:
	extends Message

	var driver_demand
	var actual_engine
	var rpm

	static func from_bytes(data: PackedByteArray) -> EngineMessage:
		var engine = EngineMessage.new()
		engine.driver_demand = data.decode_u8(0)
		engine.actual_engine = data.decode_u8(1)
		engine.rpm = _decode_be_s16(data.slice(2, 4))

		return engine

	# TODO: Override to_string
	func get_string_representation():
		return "Driver demand: " + str(driver_demand) + "%; Actual engine: " + str(actual_engine) + "%; RPM: " + str(rpm)

#############################

func _init(user_agent: String = "godot"):
	_stream.set_big_endian(true)
	_stream.set_no_delay(true)
	_user_agent = user_agent

func _process(delta: float) -> void:
	if _stream.get_status() != _stream.STATUS_NONE:
		_stream.poll()

	var new_status: int = _stream.get_status()
	if new_status != _status:
		_status = new_status
		match _status:
			_stream.STATUS_NONE:
				emit_signal("disconnected")
			_stream.STATUS_CONNECTING:
				print("Connecting to host.")
			_stream.STATUS_CONNECTED:
				emit_signal("connected")

				if not _is_echo_setup:
					_echo = EchoMessage.new()
					send(MessageType.ECHO, _echo.to_bytes())

			_stream.STATUS_ERROR:
				print("Error with socket stream.")
				emit_signal("error")

	if _status == _stream.STATUS_CONNECTED:
		var available_bytes: int = _stream.get_available_bytes()
		if available_bytes > 10:
			var header = _stream.get_data(3)
			if header[0] != OK or header[1] != PackedByteArray([0x4C, 0x58, 0x52]):
				print("Error getting data from stream: ", header[0])
				emit_signal("error")
			var version = _stream.get_u8()
			if version != 0x3:
				print("Error getting data from stream: invalid version")
				emit_signal("error")
			var message_type = _stream.get_u8()
			var payload_length = _stream.get_u16()
			assert(_stream.get_data(3)[1] == PackedByteArray([0x0, 0x0, 0x0]))
			var payload: Array = _stream.get_partial_data(payload_length)
			if payload[0] != OK:
				print("Error getting data from stream: ", payload[0])
				emit_signal("error")
			else:

				if message_type == MessageType.ECHO:
					var echo = EchoMessage.from_bytes(payload[1])
					if echo.value == _echo.value:
						_is_echo_setup = true

					var session = SessionMessage.new()
					session.flags = 3
					session.name = _user_agent
					send(MessageType.SESSION, session.to_bytes())

				elif message_type == MessageType.INSTANCE:
					var instance = InstanceMessage.from_bytes(payload[1])
					print(instance.get_string_representation())
					_instance = instance
					_is_session_setup = true

				elif _is_session_setup:
					emit_signal("message", message_type, payload[1])

func is_setup_complete() -> bool:
	return _is_session_setup

func connect_to_host(host: String, port: int) -> void:
	print("Connecting to %s:%d" % [host, port])

	# Reset status so we can tell if it changes to error again.
	_status = _stream.STATUS_NONE
	if _stream.connect_to_host(host, port) != OK:
		print("Error connecting to host.")
		emit_signal("error")

func send_request(message_type: MessageType):
	var buffer = PackedByteArray()
	buffer.append(message_type)

	send(MessageType.REQUEST, buffer)

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
	return true
