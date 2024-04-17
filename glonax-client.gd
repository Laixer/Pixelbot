extends Node

signal connected
signal data
signal disconnected
signal error
signal message

var _status: int = 0
var _stream: StreamPeerTCP = StreamPeerTCP.new()
var _is_echo_setup: bool = false
var _is_session_setup: bool = false
var _instance: InstanceMessage

var _data: Dictionary = {
	0x0: MessageType.ERROR,
	0x1: MessageType.ECHO,
	0x10: MessageType.SESSION,
	0x11: MessageType.SHUTDOWN,
	0x12: MessageType.REQUEST,
	0x15: MessageType.INSTANCE,
	0x20: MessageType.STATUS,
	0x17: MessageType.MOTION,
	0x31: MessageType.SIGNAL,
	0x40: MessageType.ACTOR,
	0x41: MessageType.VMS,
	0x42: MessageType.GNSS,
	0x43: MessageType.ENGINE,
	0x44: MessageType.TARGET,
	0x45: MessageType.CONTROL
}

enum MessageType {
	ERROR,
	ECHO,
	SESSION,
	SHUTDOWN,
	REQUEST,
	INSTANCE,
	STATUS,
	MOTION,
	SIGNAL,
	ACTOR,
	VMS,
	GNSS,
	ENGINE,
	TARGET,
	CONTROL,
}

func _message_type_from_bytes(value: int) -> MessageType:
	return _data[value]

#############################

enum { STOP_ALL, RESUME_ALL, RESET_ALL, STRAIGHT_DRIVE, CHANGE }

class MotionChangeSetMessage:
	var actuator
	var value

class MotionMessage:
	var command = STOP_ALL
	var value
	var value_list: Array

	# TODO: Move
	func encode_uint16_big_endian(value):
		return [(value >> 8) & 0xFF, value & 0xFF]
	
	func to_bytes() -> PackedByteArray:
		var buffer = PackedByteArray()

		match command:
			STOP_ALL:
				buffer.append(0x0)
			RESUME_ALL:
				buffer.append(0x1)
			RESET_ALL:
				buffer.append(0x2)
			STRAIGHT_DRIVE:
				buffer.append(0x5)
				buffer.append_array(encode_uint16_big_endian(value))
			CHANGE:
				buffer.append(0x10)
				buffer.append(value_list.size())
				for change_set in value_list:
					buffer.append_array(encode_uint16_big_endian(change_set.actuator))
					buffer.append_array(encode_uint16_big_endian(change_set.value))
		return buffer

#############################

class InstanceMessage:
	var instance_id
	var machine_type
	var version_major
	var version_minor
	var version_patch
	var name
	
	# TODO: Move somewhere
	func decode_uint16_big_endian(byte_array):
		if len(byte_array) != 2:
			return -1 
		return (byte_array[0] << 8) | byte_array[1] 
	
	func from_bytes(data: PackedByteArray):
		instance_id = data.slice(0, 16)
		machine_type = data[16]
		version_major = data.decode_u8(17)
		version_minor = data.decode_u8(18)
		version_patch = data.decode_u8(19)

		var name_len = decode_uint16_big_endian(data.slice(20, 22))
		name = data.slice(22, 22+name_len).get_string_from_utf8()

	func get_string_representation():
		return "Instance ID: " + instance_id.hex_encode() + "; Machine Type: " + str(machine_type) + "; Version: " + str(version_major) + "." + str(version_minor) + "." + str(version_patch) + "; Name: " + name

#############################

class EngineMessage:
	var driver_demand
	var actual_engine
	var rpm
	
	# TODO: Move somewhere
	func decode_uint16_big_endian(byte_array):
		if len(byte_array) != 2:
			return -1 
		return (byte_array[0] << 8) | byte_array[1] 
	
	func from_bytes(data: PackedByteArray):
		driver_demand = data[0]
		actual_engine = data[1]
		rpm = decode_uint16_big_endian(data.slice(2, 4))

	func get_string_representation():
		return "Driver demand: " + str(driver_demand) + "%; Actual engine: " + str(actual_engine) + "%; RPM: " + str(rpm)

#############################

func _init():
	_stream.set_big_endian(true)

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
					## SEND ECHO
					#print("Sending echo")
					var buffer = PackedByteArray()
					buffer.append_array([0x1, 0x2, 0x3, 0x4])
					send(MessageType.ECHO, buffer)
				
			_stream.STATUS_ERROR:
				print("Error with socket stream.")
				emit_signal("error")
#
	#while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
		#message_received.emit(get_message())
#
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
			_stream.get_data(3)
			var payload: Array = _stream.get_partial_data(payload_length)
			if payload[0] != OK:
				print("Error getting data from stream: ", payload[0])
				emit_signal("error")
			else:
				var msg_ty = _message_type_from_bytes(message_type)
				#emit_signal("data", message_type, payload[1])

				if msg_ty == MessageType.INSTANCE:
					print("got instance")
					var instance = InstanceMessage.new()
					instance.from_bytes(payload[1])
					print(instance.get_string_representation())
					_instance = instance
					_is_session_setup = true

				elif msg_ty == MessageType.ECHO:
					print("Got an echo responds")
					_is_echo_setup = true
					## SEND SESSION
					var buffer_s = PackedByteArray()
					buffer_s.append(0x3)
					buffer_s.append_array("kaas/1.1".to_utf8_buffer())
					send(MessageType.SESSION, buffer_s)
				#elif msg_ty == MessageType.ENGINE:
					#var engine = EngineMessage.new()
					#engine.from_bytes(payload[1])
					#print(engine.get_string_representation())
				elif _is_session_setup:
					emit_signal("message", msg_ty, payload[1])

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
	var msg_id = 0x0
	if message_type == MessageType.ERROR:
		msg_id = 0x1
	if message_type == MessageType.ECHO:
		msg_id = 0x1
	elif message_type == MessageType.SESSION:
		msg_id = 0x10
	elif message_type == MessageType.SHUTDOWN:
		msg_id = 0x11
	elif message_type == MessageType.REQUEST:
		msg_id = 0x12
	elif message_type == MessageType.INSTANCE:
		msg_id = 0x15
	elif message_type == MessageType.STATUS:
		msg_id = 0x16
	elif message_type == MessageType.MOTION:
		msg_id = 0x20
	elif message_type == MessageType.SIGNAL:
		msg_id = 0x31
	elif message_type == MessageType.ACTOR:
		msg_id = 0x40
	elif message_type == MessageType.VMS:
		msg_id = 0x41
	elif message_type == MessageType.GNSS:
		msg_id = 0x42
	elif message_type == MessageType.ENGINE:
		msg_id = 0x43
	elif message_type == MessageType.TARGET:
		msg_id = 0x44
	elif message_type == MessageType.CONTROL:
		msg_id = 0x45

	var buffer = PackedByteArray()
	buffer.append(msg_id)

	send(MessageType.REQUEST, buffer)

func send(message_type: MessageType, payload: PackedByteArray) -> bool:
	if _status != _stream.STATUS_CONNECTED:
		print("Error: Stream is not currently connected.")
		return false

	var msg_id = 0x0
	if message_type == MessageType.ERROR:
		msg_id = 0x1
	if message_type == MessageType.ECHO:
		msg_id = 0x1
	elif message_type == MessageType.SESSION:
		msg_id = 0x10
	elif message_type == MessageType.SHUTDOWN:
		msg_id = 0x11
	elif message_type == MessageType.REQUEST:
		msg_id = 0x12
	elif message_type == MessageType.INSTANCE:
		msg_id = 0x15
	elif message_type == MessageType.STATUS:
		msg_id = 0x16
	elif message_type == MessageType.MOTION:
		msg_id = 0x20
	elif message_type == MessageType.SIGNAL:
		msg_id = 0x31
	elif message_type == MessageType.ACTOR:
		msg_id = 0x40
	elif message_type == MessageType.VMS:
		msg_id = 0x41
	elif message_type == MessageType.GNSS:
		msg_id = 0x42
	elif message_type == MessageType.ENGINE:
		msg_id = 0x43
	elif message_type == MessageType.TARGET:
		msg_id = 0x44
	elif message_type == MessageType.CONTROL:
		msg_id = 0x45

	_stream.put_data([0x4C, 0x58, 0x52])
	_stream.put_8(0x3)
	_stream.put_8(msg_id)
	_stream.put_16(payload.size())
	_stream.put_data([0x0, 0x0, 0x0])

	var error: int = _stream.put_data(payload)
	if error != OK:
		print("Error writing to stream: ", error)
		return false
	return true
