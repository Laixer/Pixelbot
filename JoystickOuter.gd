extends Sprite2D

@onready var timer: Timer = $Timer as Timer

var default_color: Color = Color(1, 1, 1)  # White
var changed_color: Color = Color(1, 0, 0)  # Red

func _ready() -> void:
	timer.timeout.connect(_on_Timer_timeout)
	#connect("timeout", self, "_on_Timer_timeout")
	# Set the timer to not automatically restart
	timer.one_shot = true

func change_color(temporary_color: Color, duration: float) -> void:
	modulate = temporary_color
	if timer.is_stopped():
		timer.start(duration)
	else:
		timer.stop()
		timer.start(duration)

func _on_Timer_timeout() -> void:
	modulate = default_color

func toggle_color_duration(duration: float):
	change_color(changed_color, duration)
