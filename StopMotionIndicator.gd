extends Indicator

# Predefine the regions
const REGION_STOP_MOTION_ON = Rect2(1610, 650, 450, 450)
const REGION_STOP_MOTION_OFF = Rect2(1610, 10, 450, 450)

func _init():
	on_region = REGION_STOP_MOTION_ON
	off_region = REGION_STOP_MOTION_OFF
