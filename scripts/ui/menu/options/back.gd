extends Button

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	var world = get_tree().root.get_node_or_null("World")
	if world and world.has_method("_on_back_pressed"):
		world._on_back_pressed()
