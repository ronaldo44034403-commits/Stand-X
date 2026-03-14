extends Button
# Заглушка - онлайн убран, кнопка Play теперь в world.gd
func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var world = get_tree().root.get_node_or_null("World")
	if world and world.has_method("_on_play_button_pressed"):
		world._on_play_button_pressed()
