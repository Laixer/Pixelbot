extends Sprite2D
class_name Indicator 

var on_region: Rect2
var off_region: Rect2

var on = false

func _ready():
	# Initialize with the first region
	set_region_rect(off_region)

func toggle():
	if on:
		set_region_rect(on_region)
		on = false
	else:
		set_region_rect(off_region)
		on = true

func set_indicator(set_value: bool):
	if set_value:
		set_region_rect(on_region)
	else:
		set_region_rect(off_region)
	on = set_value
