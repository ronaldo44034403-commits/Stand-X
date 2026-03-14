extends HSlider
func _ready() -> void:
	min_value = 2.0
	max_value = 30.0
	step = 0.5
	value = Global.controller_sensitivity * 1000.0

func _on_value_changed(val: float) -> void:
	Global.controller_sensitivity = val / 1000.0
	Global.save_settings()
