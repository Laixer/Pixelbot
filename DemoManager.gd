extends Node

var demo_mode = false

func toggle_demo_mode():
    demo_mode = !demo_mode
    print("Demo Mode:", demo_mode)  # Debug output to see the state change
    if demo_mode: 
        $Mode.text = "Mode: Demo"
    else:
        $Mode.text = "Mode: Normal"
        