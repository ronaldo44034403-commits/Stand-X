extends Node

## STANDX - World Manager (TDM + S&D + Прогрессия)

@onready var main_menu: PanelContainer      = $Menu/MainMenu
@onready var options_menu: PanelContainer   = $Menu/Options
@onready var pause_menu: PanelContainer     = $Menu/PauseMenu
@onready var menu_music: AudioStreamPlayer  = $Menu/MenuMusic
@onready var blur: ColorRect                = $Menu/Blur
@onready var dolly_camera: Camera3D         = $Menu/DollyCamera
@onready var options_vbox: VBoxContainer    = $Menu/Options/MarginContainer/VBoxContainer

const Player    = preload("res://player.tscn")
const Bot       = preload("res://bot.tscn")
const MobileHUD = preload("res://scripts/ui/mobile_hud.tscn")
const MapGen    = preload("res://scripts/map_generator.gd")

# --- Прогрессия (локальная) ---
var xp: int = 0
var level: int = 1
var gold: int = 0
var stat_kills: int = 0
var stat_deaths: int = 0
var stat_matches: int = 0
var stat_wins: int = 0

const XP_PER_KILL  = 50
const XP_PER_WIN   = 200
const XP_PER_MATCH = 30
const GOLD_PER_KILL = 5
const GOLD_PER_WIN  = 50

const RANKS = ["Новобранец","Рядовой","Ефрейтор","Сержант",
	"Лейтенант","Капитан","Майор","Полковник","Генерал","Ветеран","Элита","Легенда"]
const RANK_ICONS = ["⭐","⭐","🔰","🔰","🥉","🥉","🥈","🥈","🥇","🏅","💎","👑"]

func _get_rank() -> String:
	return RANK_ICONS[clamp(level/2, 0, RANKS.size()-1)] + " " + RANKS[clamp(level/2, 0, RANKS.size()-1)]

func _xp_needed() -> int:
	return 500 * level

func _add_result(kills: int, deaths: int, won: bool) -> Dictionary:
	var gxp = kills * XP_PER_KILL + XP_PER_MATCH + (XP_PER_WIN if won else 0)
	var ggold = kills * GOLD_PER_KILL + (GOLD_PER_WIN if won else 0)
	xp += gxp
	gold += ggold
	stat_kills += kills
	stat_deaths += deaths
	stat_matches += 1
	if won:
		stat_wins += 1
	var lvl_up = false
	while xp >= _xp_needed():
		xp -= _xp_needed()
		level += 1
		lvl_up = true
	_save_progress()
	return {"xp": gxp, "gold": ggold, "leveled_up": lvl_up, "new_level": level}

func _save_progress() -> void:
	var c = ConfigFile.new()
	c.set_value("p","xp",xp); c.set_value("p","level",level); c.set_value("p","gold",gold)
	c.set_value("p","kills",stat_kills); c.set_value("p","deaths",stat_deaths)
	c.set_value("p","matches",stat_matches); c.set_value("p","wins",stat_wins)
	c.save("user://progress.cfg")

func _load_progress() -> void:
	var c = ConfigFile.new()
	if c.load("user://progress.cfg") != OK: return
	xp = c.get_value("p","xp",0); level = c.get_value("p","level",1)
	gold = c.get_value("p","gold",0); stat_kills = c.get_value("p","kills",0)
	stat_deaths = c.get_value("p","deaths",0); stat_matches = c.get_value("p","matches",0)
	stat_wins = c.get_value("p","wins",0)

func _get_medals() -> Array:
	var m = []
	if stat_kills >= 10:   m.append("🩸 Первая кровь")
	if stat_kills >= 50:   m.append("🎯 Охотник")
	if stat_kills >= 100:  m.append("💀 Машина смерти")
	if stat_kills >= 500:  m.append("🔥 Неостановимый")
	if stat_wins >= 1:     m.append("🏆 Первая победа")
	if stat_wins >= 10:    m.append("🥇 Чемпион")
	if stat_wins >= 50:    m.append("👑 Легенда")
	if stat_matches >= 50: m.append("🎖 Ветеран")
	var kd = float(stat_kills) / max(float(stat_deaths), 1)
	if kd >= 2.0:          m.append("⚡ Доминация")
	return m

# --- Матч ---
const BOT_NAMES_CT = ["Alpha","Bravo","Charlie","Delta","Echo","Foxtrot"]
const BOT_NAMES_T  = ["Shadow","Ghost","Reaper","Viper","Storm","Blade"]
const MAP_NAMES    = ["Agency (Офис)","Crossfire (Улицы)","Mine (Шахта)"]
const MODE_NAMES   = ["Командный бой","Закладка бомбы"]
const WEAPON_IDS   = [0,1,2,3,4,5]  # knife,pistol,ak,m4,awp,deagle

@export var bot_count: int = 4
@export var match_duration: int = 180

var paused: bool = false
var hud: Node = null
var match_running: bool = false
var match_timer: float = 0.0
var gen_map: Node3D = null
var selected_map: int = 0
var selected_mode: int = 0
var score_ct: int = 0
var score_t: int = 0
var bomb_planted: bool = false
var bomb_timer: float = 0.0
const BOMB_TIME: float = 40.0
const ROUND_TIME: float = 90.0

var _profile_lbl: Label = null
var _xp_bar: ProgressBar = null

func _ready() -> void:
	_load_progress()
	main_menu.show()
	dolly_camera.show()
	blur.show()
	options_menu.hide()
	pause_menu.hide()
	menu_music.play()
	Global.bot_count = bot_count
	_build_main_extras()
	_build_options_extras()

func _build_main_extras() -> void:
	var vbox = main_menu.get_node_or_null("MarginContainer/VBoxContainer")
	if not vbox: return

	# Профиль сверху
	_profile_lbl = Label.new()
	_profile_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_profile_lbl.add_theme_font_size_override("font_size", 19)
	vbox.add_child(_profile_lbl)
	vbox.move_child(_profile_lbl, 0)
	_refresh_profile()

	# XP прогресс
	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(_xp_bar)
	vbox.move_child(_xp_bar, 1)

	var sep = HSeparator.new()
	vbox.add_child(sep)
	vbox.move_child(sep, 2)

	var ins = 3  # insert index

	# Режим
	var ml = Label.new(); ml.text = "Режим:"
	vbox.add_child(ml)
	vbox.move_child(ml, ins)
	ins += 1
	var mb = Button.new()
	mb.text = MODE_NAMES[selected_mode]
	mb.pressed.connect(func() -> void:
		selected_mode = (selected_mode + 1) % MODE_NAMES.size()
		mb.text = MODE_NAMES[selected_mode]
		Global.game_mode = selected_mode)
	vbox.add_child(mb)
	vbox.move_child(mb, ins)
	ins += 1

	# Карта
	var mapl = Label.new(); mapl.text = "Карта:"
	vbox.add_child(mapl)
	vbox.move_child(mapl, ins)
	ins += 1
	var mapb = Button.new()
	mapb.text = MAP_NAMES[selected_map]
	mapb.pressed.connect(func() -> void:
		selected_map = (selected_map + 1) % MAP_NAMES.size()
		mapb.text = MAP_NAMES[selected_map])
	vbox.add_child(mapb)
	vbox.move_child(mapb, ins)
	ins += 1

	# Оружие
	var wl = Label.new(); wl.text = "Оружие:"
	vbox.add_child(wl)
	vbox.move_child(wl, ins)
	ins += 1
	var wb = Button.new()
	wb.text = _wpn_name(Global.selected_weapon)
	wb.pressed.connect(func() -> void:
		var idx = WEAPON_IDS.find(Global.selected_weapon)
		idx = (idx + 1) % WEAPON_IDS.size()
		Global.selected_weapon = WEAPON_IDS[idx]
		wb.text = _wpn_name(Global.selected_weapon))
	vbox.add_child(wb)
	vbox.move_child(wb, ins)
	ins += 1

	# Медали
	var statb = Button.new(); statb.text = "Медали и статистика"
	statb.pressed.connect(_show_stats)
	vbox.add_child(statb)
	vbox.move_child(statb, ins)

func _wpn_name(id: int) -> String:
	var names = ["Нож","Пистолет","AK-47","M4A1","AWP","Desert Eagle"]
	return names[clamp(id, 0, names.size()-1)]

func _refresh_profile() -> void:
	if _profile_lbl:
		_profile_lbl.text = "Ур.%d  %s  Gold: %d" % [level, _get_rank(), gold]
	if _xp_bar:
		_xp_bar.max_value = _xp_needed()
		_xp_bar.value = xp

func _show_stats() -> void:
	var kd: float = float(stat_kills) / max(float(stat_deaths), 1.0)
	var txt: String = "Уровень: %d | %s\nXP: %d / %d   Gold: %d\n\nУбийства: %d | Смерти: %d | K/D: %.2f\nМатчей: %d | Побед: %d\n\nМедали:\n" % [
		level, _get_rank(), xp, _xp_needed(), gold,
		stat_kills, stat_deaths, kd, stat_matches, stat_wins]
	var medals = _get_medals()
	if medals.is_empty():
		txt += "Пока нет. Продолжай играть!"
	else:
		for m in medals:
			txt += m + "\n"
	var dlg = AcceptDialog.new()
	dlg.title = "Профиль"
	dlg.dialog_text = txt
	add_child(dlg)
	dlg.popup_centered(Vector2(380, 460))

func _build_options_extras() -> void:
	var back = options_vbox.get_node_or_null("Back")
	var ins: int = back.get_index() if back else options_vbox.get_child_count()

	var sep = HSeparator.new()
	options_vbox.add_child(sep)
	options_vbox.move_child(sep, ins)
	ins += 1

	# Чувствительность касания
	var tl = Label.new()
	tl.text = "Касание: %d" % int(Global.touch_look_sensitivity * 100)
	options_vbox.add_child(tl)
	options_vbox.move_child(tl, ins)
	ins += 1
	var ts = HSlider.new()
	ts.min_value = 5
	ts.max_value = 80
	ts.step = 1
	ts.value = Global.touch_look_sensitivity * 100
	ts.custom_minimum_size = Vector2(200, 0)
	ts.value_changed.connect(func(v: float) -> void:
		Global.touch_look_sensitivity = v / 100.0
		tl.text = "Касание: %d" % int(v)
		Global.save_settings())
	options_vbox.add_child(ts)
	options_vbox.move_child(ts, ins)
	ins += 1

	# Скин
	var sl = Label.new(); sl.text = "Скин оружия:"
	options_vbox.add_child(sl)
	options_vbox.move_child(sl, ins)
	ins += 1
	var sb = Button.new()
	sb.text = Global.SKIN_NAMES[Global.weapon_skin]
	sb.pressed.connect(func() -> void:
		Global.weapon_skin = (Global.weapon_skin + 1) % Global.SKIN_NAMES.size()
		sb.text = Global.SKIN_NAMES[Global.weapon_skin]
		Global.save_settings())
	options_vbox.add_child(sb)
	options_vbox.move_child(sb, ins)
	ins += 1

	# Сложность
	var dl = Label.new(); dl.text = "Сложность:"
	options_vbox.add_child(dl)
	options_vbox.move_child(dl, ins)
	ins += 1
	var dnames = ["Лёгкий","Нормальный","Сложный"]
	var db = Button.new()
	db.text = dnames[Global.difficulty]
	db.pressed.connect(func() -> void:
		Global.difficulty = (Global.difficulty + 1) % 3
		db.text = dnames[Global.difficulty]
		Global.save_settings())
	options_vbox.add_child(db)
	options_vbox.move_child(db, ins)

# --- Сигналы world.tscn ---

func _unhandled_input(_e: InputEvent) -> void:
	if Input.is_action_just_pressed("pause") and match_running:
		paused = !paused
		if paused:
			blur.show()
			pause_menu.show()
			_mouse_free()
		else:
			_on_resume_pressed()

func _process(delta: float) -> void:
	if not match_running or paused: return
	match_timer -= delta
	if match_timer <= 0.0:
		_end_match()
		return
	if hud and hud.has_method("update_timer"):
		hud.update_timer(int(match_timer))
	if selected_mode == 1 and bomb_planted:
		bomb_timer -= delta
		if hud and hud.has_method("show_bomb_status"):
			hud.show_bomb_status("БОМБА! %d сек" % int(bomb_timer), Color(1,0.3,0.1))
		if bomb_timer <= 0.0:
			_end_round(false)

func _on_host_button_pressed() -> void: _start_match()
func _on_join_button_pressed() -> void: _start_match()

func _on_resume_pressed() -> void:
	paused = false
	blur.hide()
	pause_menu.hide()
	_mouse_capture()

func _on_options_pressed() -> void:
	pause_menu.hide()
	options_menu.show()
	blur.show()
	_mouse_free()

func _on_options_button_toggled(on: bool) -> void:
	if on:
		options_menu.show()
		blur.show()
		main_menu.hide()
	else:
		options_menu.hide()
		blur.hide()
		main_menu.show()

func _on_back_pressed() -> void:
	options_menu.hide()
	if match_running:
		pause_menu.show()
	else:
		main_menu.show()
		blur.show()
	if match_running:
		_mouse_capture()

func _on_music_toggle_toggled(on: bool) -> void:
	if on: menu_music.play()
	else: menu_music.stop()

func _mouse_free() -> void:
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _mouse_capture() -> void:
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- Матч ---

func _start_match() -> void:
	main_menu.hide()
	dolly_camera.hide()
	blur.hide()
	options_menu.hide()
	menu_music.stop()
	score_ct = 0
	score_t = 0
	bomb_planted = false
	bomb_timer = BOMB_TIME
	Global.match_kills = 0
	Global.match_deaths = 0
	Global.game_mode = selected_mode
	Global.player_team = 0
	match_timer = float(ROUND_TIME if selected_mode == 1 else match_duration)
	match_running = true

	gen_map = Node3D.new(); gen_map.name = "GeneratedMap"
	add_child(gen_map)
	MapGen.build_map(gen_map, selected_map)

	var player = Player.instantiate()
	player.name = "LocalPlayer"
	add_child(player)

	_spawn_bots()

	hud = MobileHUD.instantiate()
	hud.name = "MobileHUD"
	add_child(hud)
	hud.update_hp(100, 100)
	hud.update_ammo(15, 60)
	hud.set_mode_text(MODE_NAMES[selected_mode])
	hud.update_timer(int(match_timer))

func _spawn_bots() -> void:
	var half: int = Global.bot_count / 2
	for i in range(Global.bot_count):
		var bot = Bot.instantiate()
		bot.name = "Bot_" + str(i)
		var is_ct: bool = i < half
		var names = BOT_NAMES_CT if is_ct else BOT_NAMES_T
		bot.bot_name = names[i % names.size()]
		bot.set_meta("team", 0 if is_ct else 1)
		add_child(bot)
		bot.add_to_group("bots")
		bot.add_to_group("team_" + ("0" if is_ct else "1"))

func _end_round(ct_won: bool) -> void:
	if ct_won:
		score_ct += 1
		_feed("CT выиграли раунд!")
	else:
		score_t += 1
		_feed("T выиграли раунд!")
	bomb_planted = false
	bomb_timer = BOMB_TIME
	match_timer = float(ROUND_TIME)
	if hud and hud.has_method("update_score_tdm"):
		hud.update_score_tdm(score_ct, score_t)
	if hud and hud.has_method("set_mode_text"):
		hud.set_mode_text(MODE_NAMES[selected_mode])

func _end_match(_quit: bool = false) -> void:
	match_running = false
	var won: bool = score_ct >= score_t and Global.match_kills > 0

	var result = _add_result(Global.match_kills, Global.match_deaths, won)
	_show_result_screen(result)

	var p = get_node_or_null("LocalPlayer")
	if p: p.queue_free()
	for i in range(20):
		var b = get_node_or_null("Bot_" + str(i))
		if b: b.queue_free()
	if gen_map: gen_map.queue_free()
	gen_map = null
	if has_node("MobileHUD"):
		get_node("MobileHUD").queue_free()
		hud = null

	_go_to_main_menu()

func _show_result_screen(result: Dictionary) -> void:
	var txt: String = "Убийств: %d  Смертей: %d\n+%d XP   +%d Gold" % [
		Global.match_kills, Global.match_deaths,
		result.get("xp", 0), result.get("gold", 0)]
	if result.get("leveled_up", false):
		txt += "\n\nНОВЫЙ УРОВЕНЬ %d!\n%s" % [result.get("new_level", 1), _get_rank()]
	var dlg = AcceptDialog.new()
	dlg.title = "Матч завершён"
	dlg.dialog_text = txt
	add_child(dlg)
	dlg.popup_centered(Vector2(320, 200))

func _go_to_main_menu() -> void:
	main_menu.show()
	dolly_camera.show()
	blur.show()
	pause_menu.hide()
	options_menu.hide()
	menu_music.play()
	_mouse_free()
	_refresh_profile()

# --- Events ---

func on_player_killed(_n: String) -> void:
	score_t += 1
	_feed("Ты убит!")
	if hud and hud.has_method("update_score_tdm"):
		hud.update_score_tdm(score_ct, score_t)

func on_bot_killed(bname: String) -> void:
	Global.match_kills += 1
	score_ct += 1
	_feed("%s ликвидирован!" % bname)
	if hud:
		hud.update_score(Global.match_kills, Global.bot_count)
		hud.update_score_tdm(score_ct, score_t)
	if Global.match_kills >= Global.score_limit:
		_end_match()

func plant_bomb() -> void:
	bomb_planted = true
	bomb_timer = BOMB_TIME
	_feed("БОМБА ЗАЛОЖЕНА!")

func defuse_bomb() -> void:
	bomb_planted = false
	_feed("БОМБА ОБЕЗВРЕЖЕНА!")
	_end_round(true)

func _feed(msg: String) -> void:
	if hud and hud.has_method("add_kill_feed_message"):
		hud.add_kill_feed_message(msg)

func _on_quit_to_menu_pressed() -> void:
	_end_match(true)
