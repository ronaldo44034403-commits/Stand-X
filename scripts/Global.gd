extends Node

var sensitivity: float = 0.003
var touch_look_sensitivity: float = 0.55
var controller_sensitivity: float = 0.010

# HUD настройки
var hud_joystick_size: float = 200.0
var hud_fire_size: float = 150.0
var weapon_skin: int = 0

# Матч
var bot_count: int = 5
var match_time: int = 180
var score_limit: int = 10
var selected_weapon: int = 1  # WeaponType.PISTOL
var game_mode: int = 0  # 0=TDM, 1=S&D

# Текущий матч
var match_kills: int = 0
var match_deaths: int = 0
var player_team: int = 0  # 0=CT, 1=T

enum Difficulty { EASY, NORMAL, HARD }
var difficulty: int = 1

func get_bot_damage() -> int:
	match difficulty:
		0: return 10
		1: return 18
		2: return 30
	return 18

func get_bot_shoot_cooldown() -> float:
	match difficulty:
		0: return 2.8
		1: return 1.6
		2: return 0.9
	return 1.6

const SKIN_NAMES = ["Стандарт","Золото","Хром","Красный","Лёд","Тигр","Дракон"]

func get_weapon_skin_params() -> Dictionary:
	var skins = [
		{body=Color(0.18,0.18,0.20),barrel=Color(0.15,0.15,0.17),metal=0.85,rough=0.25},
		{body=Color(0.83,0.68,0.10),barrel=Color(0.90,0.75,0.20),metal=0.95,rough=0.15},
		{body=Color(0.72,0.72,0.75),barrel=Color(0.80,0.80,0.82),metal=1.00,rough=0.05},
		{body=Color(0.70,0.10,0.10),barrel=Color(0.55,0.08,0.08),metal=0.70,rough=0.30},
		{body=Color(0.60,0.85,0.95),barrel=Color(0.70,0.90,1.00),metal=0.50,rough=0.10},
		{body=Color(0.60,0.40,0.10),barrel=Color(0.45,0.30,0.08),metal=0.60,rough=0.40},
		{body=Color(0.15,0.55,0.25),barrel=Color(0.10,0.45,0.20),metal=0.75,rough=0.20},
	]
	return skins[clamp(weapon_skin, 0, skins.size()-1)]

func save_settings() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("s","sens",sensitivity)
	cfg.set_value("s","touch",touch_look_sensitivity)
	cfg.set_value("s","diff",difficulty)
	cfg.set_value("s","bots",bot_count)
	cfg.set_value("s","skin",weapon_skin)
	cfg.save("user://settings.cfg")

func load_settings() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK: return
	sensitivity = cfg.get_value("s","sens",sensitivity)
	touch_look_sensitivity = cfg.get_value("s","touch",touch_look_sensitivity)
	difficulty = cfg.get_value("s","diff",difficulty)
	bot_count = cfg.get_value("s","bots",bot_count)
	weapon_skin = cfg.get_value("s","skin",weapon_skin)

func _ready() -> void:
	load_settings()
