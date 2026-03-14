extends OptionButton

func _ready() -> void:
	clear()
	add_item("Лёгкий")
	add_item("Нормальный")
	add_item("Сложный")
	selected = Global.difficulty
	item_selected.connect(_on_selected)

func _on_selected(idx: int) -> void:
	Global.difficulty = idx
