extends Control

## STANDX - Virtual Joystick (исправленный)

signal joystick_input(direction: Vector2)

@export var joystick_radius: float = 100.0
@export var knob_radius: float = 40.0
@export var is_look_joystick: bool = false

var touch_index: int = -1
var base_position: Vector2
var knob_position: Vector2
var _output: Vector2 = Vector2.ZERO

@onready var base: ColorRect = $Base
@onready var knob: ColorRect = $Knob

func _ready() -> void:
	base_position = size / 2.0
	knob_position = base_position
	_update_visual()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var local = event.position - global_position
			# Проверяем зону этого джойстика
			if local.x >= -20 and local.x <= size.x + 20 and local.y >= -20 and local.y <= size.y + 20:
				if touch_index == -1:
					touch_index = event.index
					# Для правого джойстика — центр там где нажали
					if is_look_joystick:
						base_position = local
					knob_position = base_position
					_output = Vector2.ZERO
					_update_visual()
		else:
			if event.index == touch_index:
				touch_index = -1
				knob_position = base_position
				_output = Vector2.ZERO
				_update_visual()
				joystick_input.emit(Vector2.ZERO)

	elif event is InputEventScreenDrag:
		if event.index == touch_index:
			var local = event.position - global_position
			var diff = local - base_position
			if diff.length() > joystick_radius:
				diff = diff.normalized() * joystick_radius
			knob_position = base_position + diff
			_output = diff / joystick_radius
			_update_visual()
			joystick_input.emit(_output)

func _update_visual() -> void:
	if base and knob:
		base.position = base_position - Vector2(joystick_radius, joystick_radius)
		knob.position = knob_position - Vector2(knob_radius, knob_radius)

func get_output() -> Vector2:
	return _output
