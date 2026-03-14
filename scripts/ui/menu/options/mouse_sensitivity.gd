extends HSlider
## Чувствительность мыши
func _ready() -> void:
	min_value = 1.0
	max_value = 20.0
	step = 0.5
	value = Global.sensitivity * 1000.0

func _on_value_changed(val: float) -> void:
	Global.sensitivity = val / 1000.0
	Global.save_settings()
