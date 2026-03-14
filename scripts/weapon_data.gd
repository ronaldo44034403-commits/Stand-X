extends Node

## STANDX - Данные оружий

enum WeaponType { KNIFE, PISTOL, AK47, M4A1, AWP, DEAGLE }

const WEAPONS = {
	WeaponType.KNIFE: {
		"name": "Нож",
		"damage": 55,
		"fire_rate": 0.6,
		"ammo_clip": 1,
		"ammo_reserve": 1,
		"infinite_ammo": true,
		"range": 2.2,
		"spread": 0.0,
		"auto": false,
		"icon": "🔪",
		"color": Color(0.7, 0.7, 0.75),
	},
	WeaponType.PISTOL: {
		"name": "Пистолет",
		"damage": 34,
		"fire_rate": 0.22,
		"ammo_clip": 15,
		"ammo_reserve": 60,
		"infinite_ammo": false,
		"range": 30.0,
		"spread": 0.015,
		"auto": false,
		"icon": "🔫",
		"color": Color(0.2, 0.2, 0.22),
	},
	WeaponType.AK47: {
		"name": "AK-47",
		"damage": 28,
		"fire_rate": 0.10,
		"ammo_clip": 30,
		"ammo_reserve": 90,
		"infinite_ammo": false,
		"range": 40.0,
		"spread": 0.03,
		"auto": true,
		"icon": "🔫",
		"color": Color(0.35, 0.25, 0.15),
	},
	WeaponType.M4A1: {
		"name": "M4A1",
		"damage": 24,
		"fire_rate": 0.09,
		"ammo_clip": 30,
		"ammo_reserve": 90,
		"infinite_ammo": false,
		"range": 40.0,
		"spread": 0.02,
		"auto": true,
		"icon": "🔫",
		"color": Color(0.18, 0.18, 0.20),
	},
	WeaponType.AWP: {
		"name": "AWP",
		"damage": 95,
		"fire_rate": 1.2,
		"ammo_clip": 5,
		"ammo_reserve": 20,
		"infinite_ammo": false,
		"range": 80.0,
		"spread": 0.001,
		"auto": false,
		"icon": "🎯",
		"color": Color(0.15, 0.25, 0.15),
	},
	WeaponType.DEAGLE: {
		"name": "Desert Eagle",
		"damage": 52,
		"fire_rate": 0.35,
		"ammo_clip": 7,
		"ammo_reserve": 35,
		"infinite_ammo": false,
		"range": 35.0,
		"spread": 0.01,
		"auto": false,
		"icon": "🔫",
		"color": Color(0.5, 0.5, 0.1),
	},
}

static func get_data(type: int) -> Dictionary:
	return WEAPONS.get(type, WEAPONS[WeaponType.PISTOL])
