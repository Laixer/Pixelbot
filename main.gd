extends Node2D



func _on_play_pressed():
	Global.hostname = $HostnameInput.text
	get_tree().change_scene_to_file("res://world.tscn")
