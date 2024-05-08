extends Indicator

# Predefine the regions
const REGION_START_MOTOR_ON = Rect2(10, 650, 450, 450)
const REGION_START_MOTOR_OFF = Rect2(10, 10, 450, 450)

func _init():
	on_region = REGION_START_MOTOR_ON
	off_region = REGION_START_MOTOR_OFF
