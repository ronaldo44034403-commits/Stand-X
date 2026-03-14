extends CanvasLayer

## STANDX - Mobile HUD

signal jump_pressed
signal shoot_pressed
signal reload_pressed

@onready var move_joystick = $MoveJoystick
@onready var look_joystick = $LookJoystick
@onready var fire_button: Button = $FireButton
@onready var jump_button: Button = $JumpButton
@onready var reload_button: Button = $ReloadButton
@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var ammo_label: Label = $AmmoLabel
@onready var kill_feed: VBoxContainer = $KillFeedContainer
@onready var death_screen: PanelContainer = $DeathScreen

var score_label: Label = null
var timer_label: Label = null
var weapon_label: Label = null
var mode_label: Label = null
var hit_label: Label = null
var reload_bar: ProgressBar = null

var _move_vec: Vector2 = Vector2.ZERO
var _look_vec: Vector2 = Vector2.ZERO
var _shoot_held: bool = false
var _jump_held: bool = false

func _ready() -> void:
	var touch = DisplayServer.is_touchscreen_available()
	move_joystick.visible = touch
	look_joystick.visible = touch
	fire_button.visible = touch
	jump_button.visible = touch
	reload_button.visible = touch

	move_joystick.joystick_input.connect(func(d: Vector2) -> void: _move_vec = d)
	look_joystick.joystick_input.connect(func(d: Vector2) -> void: _look_vec = d)

	fire_button.button_down.connect(func() -> void:
		_shoot_held = true
		shoot_pressed.emit())
	fire_button.button_up.connect(func() -> void:
		_shoot_held = false)

	jump_button.button_down.connect(func() -> void:
		_jump_held = true
		jump_pressed.emit())
	jump_button.button_up.connect(func() -> void:
		_jump_held = false)

	reload_button.pressed.connect(func() -> void:
		reload_pressed.emit())

	death_screen.visible = false

	# Таймер
	timer_label = _lbl("3:00", 32, Color(1,1,1))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.offset_top = 8
	timer_label.offset_left = -110
	timer_label.offset_right = 110
	timer_label.offset_bottom = 50
	add_child(timer_label)

	# Счёт
	score_label = _lbl("0 kills", 24, Color(1,0.9,0.1))
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	score_label.offset_top = 8
	score_label.offset_left = -220
	score_label.offset_right = -10
	score_label.offset_bottom = 44
	add_child(score_label)

	# Название оружия
	weapon_label = _lbl("Пистолет", 20, Color(0.8,0.8,0.8))
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	weapon_label.offset_top = -245
	weapon_label.offset_left = -220
	weapon_label.offset_right = -10
	weapon_label.offset_bottom = -215
	add_child(weapon_label)

	# Режим
	mode_label = _lbl("", 19, Color(0.8,0.9,1))
	mode_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mode_label.offset_top = 8
	mode_label.offset_left = 10
	mode_label.offset_right = 320
	mode_label.offset_bottom = 40
	add_child(mode_label)

	# Hit marker
	hit_label = _lbl("✖", 40, Color(1,0.15,0.15,0))
	hit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hit_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hit_label)

	# Reload bar
	reload_bar = ProgressBar.new()
	reload_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	reload_bar.offset_left = -110
	reload_bar.offset_right = 110
	reload_bar.offset_top = -82
	reload_bar.offset_bottom = -60
	reload_bar.min_value = 0
	reload_bar.max_value = 100
	reload_bar.value = 0
	reload_bar.visible = false
	add_child(reload_bar)

func _lbl(txt: String, size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	return l

func get_move_input() -> Vector2: return _move_vec
func get_look_input() -> Vector2: return _look_vec
func is_shoot_held() -> bool: return _shoot_held
func is_jump_held() -> bool: return _jump_held

func update_hp(cur: int, mx: int) -> void:
	hp_bar.max_value = mx
	hp_bar.value = cur
	hp_label.text = "%d HP" % cur
	var p: float = float(cur) / float(mx)
	if p > 0.6:
		hp_bar.modulate = Color(0.2, 1.0, 0.2)
	elif p > 0.3:
		hp_bar.modulate = Color(1.0, 0.75, 0.0)
	else:
		hp_bar.modulate = Color(1.0, 0.15, 0.15)

func update_ammo(clip: int, reserve: int) -> void:
	if clip < 0:
		ammo_label.text = "∞"
		ammo_label.modulate = Color(0.8, 0.8, 0.8)
		return
	ammo_label.text = "%d / %d" % [clip, reserve]
	if clip <= 3:
		ammo_label.modulate = Color(1, 0.2, 0.2)
	elif clip <= 8:
		ammo_label.modulate = Color(1, 0.7, 0.1)
	else:
		ammo_label.modulate = Color(1, 1, 1)

func update_weapon_name(wname: String) -> void:
	if weapon_label:
		weapon_label.text = wname

func set_mode_text(txt: String) -> void:
	if mode_label:
		mode_label.text = txt

func update_score(kills: int, _mx: int) -> void:
	if score_label:
		score_label.text = "%d kills" % kills

func update_score_tdm(ct: int, t: int) -> void:
	if score_label:
		score_label.text = "CT %d  :  %d T" % [ct, t]

func update_timer(seconds: int) -> void:
	if not timer_label:
		return
	var m: int = seconds / 60
	var s: int = seconds % 60
	timer_label.text = "%d:%02d" % [m, s]
	if seconds <= 30:
		timer_label.modulate = Color(1, 0.2, 0.2)
	else:
		timer_label.modulate = Color(1, 1, 1)

func show_bomb_status(txt: String, color: Color) -> void:
	if mode_label:
		mode_label.text = txt
		mode_label.modulate = color

func hit_marker() -> void:
	if not hit_label:
		return
	hit_label.modulate = Color(1, 0.15, 0.15, 1.0)
	var tw = create_tween()
	tw.tween_property(hit_label, "modulate:a", 0.0, 0.22)

func show_reload(duration: float) -> void:
	if not reload_bar:
		return
	reload_bar.visible = true
	reload_bar.value = 0
	var tw = create_tween()
	tw.tween_property(reload_bar, "value", 100.0, duration)
	tw.tween_callback(func() -> void: reload_bar.visible = false)

func show_death(t: float = 3.0) -> void:
	death_screen.visible = true
	var tw = create_tween()
	tw.tween_interval(t)
	tw.tween_callback(func() -> void: death_screen.visible = false)

func add_kill_feed_message(msg: String) -> void:
	var lbl = Label.new()
	lbl.text = msg
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.modulate = Color(1, 0.35, 0.1, 0.0)
	kill_feed.add_child(lbl)
	var t = create_tween()
	t.tween_property(lbl, "modulate:a", 1.0, 0.2)
	t.tween_interval(3.5)
	t.tween_property(lbl, "modulate:a", 0.0, 0.4)
	t.tween_callback(lbl.queue_free)
	while kill_feed.get_child_count() > 5:
		kill_feed.get_child(0).queue_free()
