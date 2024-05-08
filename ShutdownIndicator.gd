extends Indicator

# Predefine the regions
const REGION_SHUTDOWN_ON = Rect2(810, 650, 450, 450)
const REGION_SHUTDOWN_OFF = Rect2(810, 10, 450, 450)

func _init():
	on_region = REGION_SHUTDOWN_ON
	off_region = REGION_SHUTDOWN_OFF
