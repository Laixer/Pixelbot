extends Node2D

const Client = preload("res://glonax-client.gd")
var _client: Client = Client.new("godot/4.2")

func _ready():
	_client.connected.connect(_handle_client_connected)
	_client.error.connect(_handle_client_error)

	add_child(_client)

func _handle_client_connected() -> void:
	$ConnectionStatus.text = "Connected to " + Global.host + ":" + str(Global.port)
	get_tree().change_scene_to_file("res://world.tscn")

func _handle_client_error() -> void:
	$ConnectionStatus.text = "Failed to connect to " + Global.host + ":" + str(Global.port)
	$HostnameInput.editable = true

func parse_hostname(hostname: String):
	var parts = hostname.strip_edges(true, false).split(":")
	if parts.size() == 1:
		return { "host": hostname, "port": 30051} 
	elif parts.size() == 2:
		var host = parts[0]
		var port = parts[1].to_int()
		return { "host": host, "port": port} 
	else:
		return null

func _on_connect_pressed():
	var hostname = $HostnameInput.text
	$HostnameInput.editable = false

	var result = parse_hostname(hostname)
	if result:
		$ConnectionStatus.text = "Connecting to... " + result.host + ":" + str(result.port)
		Global.host = result.host
		Global.port = result.port
		_client.connect_to_host(result.host, result.port)
	else:
		$ConnectionStatus.text = "Invalid hostname and port"
		$HostnameInput.editable = true
