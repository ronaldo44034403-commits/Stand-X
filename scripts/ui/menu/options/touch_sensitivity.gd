extends HSlider
## Чувствительность касания (свайп-камера)
func _ready() -> void:
	min_value = 5.0
	max_value = 80.0
	step = 1.0
	value = Global.touch_look_sensitivity * 100.0

func _on_value_changed(val: float) -> void:
	Global.touch_look_sensitivity = val / 100.0
	Global.save_settings()
