extends Node

## STANDX - Система уровней, медалей, статистики

var xp: int = 0
var level: int = 1
var gold: int = 0
var total_kills: int = 0
var total_deaths: int = 0
var total_matches: int = 0
var total_wins: int = 0

const XP_PER_LEVEL = 500
const XP_PER_KILL = 50
const XP_PER_WIN = 200
const XP_PER_MATCH = 30
const GOLD_PER_WIN = 50
const GOLD_PER_KILL = 5

const RANKS = [
	"Новобранец", "Рядовой", "Ефрейтор", "Сержант",
	"Лейтенант", "Капитан", "Майор", "Полковник",
	"Генерал", "Ветеран", "Элита", "Легенда"
]
const RANK_ICONS = ["⭐","⭐","🔰","🔰","🥉","🥉","🥈","🥈","🥇","🏅","💎","👑"]

func get_rank() -> String:
	var idx = clamp(level / 2, 0, RANKS.size() - 1)
	return RANK_ICONS[idx] + " " + RANKS[idx]

func get_rank_color() -> Color:
	var idx = clamp(level / 2, 0, 5)
	var colors = [Color(0.7,0.7,0.7), Color(0.5,1,0.5), Color(0.3,0.6,1),
		Color(0.8,0.4,1), Color(1,0.8,0.1), Color(0,0.9,1)]
	return colors[idx]

func xp_to_next() -> int:
	return XP_PER_LEVEL * level

func add_match_result(kills: int, deaths: int, won: bool) -> Dictionary:
	var gained_xp = kills * XP_PER_KILL + XP_PER_MATCH
	var gained_gold = kills * GOLD_PER_KILL
	if won:
		gained_xp += XP_PER_WIN
		gained_gold += GOLD_PER_WIN
	xp += gained_xp
	gold += gained_gold
	total_kills += kills
	total_deaths += deaths
	total_matches += 1
	if won:
		total_wins += 1
	var leveled_up = false
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		leveled_up = true
	save()
	return {"xp": gained_xp, "gold": gained_gold, "leveled_up": leveled_up, "new_level": level}

func get_medals() -> Array:
	var medals = []
	if total_kills >= 10:  medals.append({"name":"Первая кровь","icon":"🩸"})
	if total_kills >= 50:  medals.append({"name":"Охотник","icon":"🎯"})
	if total_kills >= 100: medals.append({"name":"Снайпер","icon":"🔭"})
	if total_kills >= 500: medals.append({"name":"Машина смерти","icon":"💀"})
	if total_wins >= 1:    medals.append({"name":"Первая победа","icon":"🏆"})
	if total_wins >= 10:   medals.append({"name":"Чемпион","icon":"🥇"})
	if total_wins >= 50:   medals.append({"name":"Легенда","icon":"👑"})
	if total_matches >= 100: medals.append({"name":"Ветеран","icon":"🎖"})
	if get_kd() >= 2.0:    medals.append({"name":"Доминация","icon":"⚡"})
	return medals

func get_kd() -> float:
	if total_deaths == 0:
		return float(total_kills)
	return float(total_kills) / float(total_deaths)

func save() -> void:
	var cfg = ConfigFile.new()
	cfg.set_value("p","xp",xp)
	cfg.set_value("p","level",level)
	cfg.set_value("p","gold",gold)
	cfg.set_value("p","kills",total_kills)
	cfg.set_value("p","deaths",total_deaths)
	cfg.set_value("p","matches",total_matches)
	cfg.set_value("p","wins",total_wins)
	cfg.save("user://progression.cfg")

func load_data() -> void:
	var cfg = ConfigFile.new()
	if cfg.load("user://progression.cfg") != OK: return
	xp = cfg.get_value("p","xp",0)
	level = cfg.get_value("p","level",1)
	gold = cfg.get_value("p","gold",0)
	total_kills = cfg.get_value("p","kills",0)
	total_deaths = cfg.get_value("p","deaths",0)
	total_matches = cfg.get_value("p","matches",0)
	total_wins = cfg.get_value("p","wins",0)

func _ready() -> void:
	load_data()
