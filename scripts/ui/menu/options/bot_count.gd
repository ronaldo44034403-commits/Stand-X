extends SpinBox

func _ready() -> void:
	value = Global.bot_count
	value_changed.connect(_on_value_changed)

func _on_value_changed(val: float) -> void:
	Global.bot_count = int(val)
