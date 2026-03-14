extends Node

## STANDX - Генератор карт (3 карты в стиле Standoff 2)

static func build_map(root: Node, map_id: int) -> void:
	match map_id:
		0: _build_agency(root)
		1: _build_crossfire(root)
		2: _build_mine(root)
		_: _build_agency(root)

static func _box(root: Node, pos: Vector3, size: Vector3, color: Color) -> void:
	var body = StaticBody3D.new()
	body.position = pos
	var mi = MeshInstance3D.new()
	var bx = BoxMesh.new()
	bx.size = size
	mi.mesh = bx
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	body.add_child(mi)
	var col = CollisionShape3D.new()
	var sh = BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)
	root.add_child(body)

## ═══════════════════════════════════════
## КАРТА 0: AGENCY (офис/агентство)
## ═══════════════════════════════════════
static func _build_agency(root: Node) -> void:
	var floor_c  = Color(0.55, 0.52, 0.48)
	var wall_c   = Color(0.72, 0.70, 0.65)
	var desk_c   = Color(0.55, 0.40, 0.25)
	var pillar_c = Color(0.80, 0.78, 0.74)
	var dark_c   = Color(0.25, 0.23, 0.20)

	# Пол
	_box(root, Vector3(0, -0.5, 0), Vector3(50, 1, 50), floor_c)
	# Потолок
	_box(root, Vector3(0, 5.5, 0), Vector3(50, 0.3, 50), wall_c)

	# Внешние стены
	_box(root, Vector3(0, 2.5, -25), Vector3(50, 6, 1), wall_c)
	_box(root, Vector3(0, 2.5, 25),  Vector3(50, 6, 1), wall_c)
	_box(root, Vector3(-25, 2.5, 0), Vector3(1, 6, 50), wall_c)
	_box(root, Vector3(25, 2.5, 0),  Vector3(1, 6, 50), wall_c)

	# Центральные стены с проходами
	# Горизонтальная стена с проходом в центре
	_box(root, Vector3(-10, 1.5, 0), Vector3(18, 3, 0.4), wall_c)
	_box(root, Vector3(10, 1.5, 0),  Vector3(18, 3, 0.4), wall_c)
	# Вертикальная стена
	_box(root, Vector3(0, 1.5, -10), Vector3(0.4, 3, 18), wall_c)
	_box(root, Vector3(0, 1.5, 10),  Vector3(0.4, 3, 18), wall_c)

	# Офисные столы (укрытия)
	var desks = [
		Vector3(-8, 0.6, -8), Vector3(8, 0.6, -8),
		Vector3(-8, 0.6, 8),  Vector3(8, 0.6, 8),
		Vector3(-15, 0.6, -15), Vector3(15, 0.6, -15),
		Vector3(-15, 0.6, 15),  Vector3(15, 0.6, 15),
		Vector3(0, 0.6, 0),
	]
	for p in desks:
		_box(root, p, Vector3(2.4, 0.9, 1.0), desk_c)

	# Колонны
	for x in [-10, 0, 10]:
		for z in [-10, 10]:
			_box(root, Vector3(x, 2.5, z), Vector3(0.7, 5.5, 0.7), pillar_c)

	# Шкафы
	_box(root, Vector3(-22, 1.2, -10), Vector3(1.5, 2.5, 4), dark_c)
	_box(root, Vector3(22, 1.2, 10),   Vector3(1.5, 2.5, 4), dark_c)
	_box(root, Vector3(-22, 1.2, 10),  Vector3(1.5, 2.5, 4), dark_c)
	_box(root, Vector3(22, 1.2, -10),  Vector3(1.5, 2.5, 4), dark_c)

	# Лестничные платформы
	_box(root, Vector3(-18, 1.0, -18), Vector3(6, 0.3, 6), pillar_c)
	_box(root, Vector3(18, 1.0, 18),   Vector3(6, 0.3, 6), pillar_c)

## ═══════════════════════════════════════
## КАРТА 1: CROSSFIRE (городские улицы)
## ═══════════════════════════════════════
static func _build_crossfire(root: Node) -> void:
	var road_c    = Color(0.30, 0.30, 0.32)
	var building  = Color(0.65, 0.60, 0.55)
	var concrete  = Color(0.50, 0.48, 0.45)
	var dark_w    = Color(0.20, 0.18, 0.16)
	var yellow_c  = Color(0.85, 0.75, 0.10)  # дорожная разметка

	# Дорога (асфальт)
	_box(root, Vector3(0, -0.5, 0), Vector3(54, 1, 54), road_c)
	# Центральная полоса
	_box(root, Vector3(0, -0.49, 0), Vector3(2, 0.02, 54), yellow_c)

	# Здания по углам (непробиваемые блоки)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(root, Vector3(sx*18, 3.0, sz*18), Vector3(10, 7, 10), building)
			# Окна (темные вставки)
			_box(root, Vector3(sx*18, 2.5, sz*14), Vector3(8, 1.2, 0.3), dark_w)
			_box(root, Vector3(sx*14, 2.5, sz*18), Vector3(0.3, 1.2, 8), dark_w)

	# Центральная постройка
	_box(root, Vector3(0, 1.0, 0), Vector3(6, 2.0, 6), concrete)
	# Выходы из центра
	_box(root, Vector3(-3, 2.2, 0), Vector3(0.5, 2.0, 4), concrete)
	_box(root, Vector3(3, 2.2, 0),  Vector3(0.5, 2.0, 4), concrete)

	# Баррикады / машины (прямоугольники)
	var barricades = [
		[Vector3(-8, 0.6, 0),  Vector3(0.5, 1.2, 3.5)],
		[Vector3(8, 0.6, 0),   Vector3(0.5, 1.2, 3.5)],
		[Vector3(0, 0.6, -8),  Vector3(3.5, 1.2, 0.5)],
		[Vector3(0, 0.6, 8),   Vector3(3.5, 1.2, 0.5)],
		[Vector3(-13, 0.7, 5), Vector3(3.5, 1.5, 2.0)],
		[Vector3(13, 0.7, -5), Vector3(3.5, 1.5, 2.0)],
		[Vector3(-5, 0.7, 13), Vector3(2.0, 1.5, 3.5)],
		[Vector3(5, 0.7, -13), Vector3(2.0, 1.5, 3.5)],
	]
	for b in barricades:
		_box(root, b[0], b[1], concrete)

	# Бордюры
	_box(root, Vector3(-5, 0.1, 0), Vector3(0.3, 0.2, 54), concrete)
	_box(root, Vector3(5, 0.1, 0),  Vector3(0.3, 0.2, 54), concrete)

	# Внешние стены (невидимые)
	_box(root, Vector3(0, 2, -27),  Vector3(54, 6, 1), building)
	_box(root, Vector3(0, 2, 27),   Vector3(54, 6, 1), building)
	_box(root, Vector3(-27, 2, 0),  Vector3(1, 6, 54), building)
	_box(root, Vector3(27, 2, 0),   Vector3(1, 6, 54), building)

## ═══════════════════════════════════════
## КАРТА 2: MINE (заброшенная шахта)
## ═══════════════════════════════════════
static func _build_mine(root: Node) -> void:
	var ground_c  = Color(0.28, 0.24, 0.20)
	var rock_c    = Color(0.38, 0.33, 0.27)
	var wood_c    = Color(0.50, 0.38, 0.22)
	var metal_c   = Color(0.42, 0.42, 0.45)
	var ore_c     = Color(0.35, 0.55, 0.30)  # рудная порода

	# Земляной пол
	_box(root, Vector3(0, -0.5, 0), Vector3(50, 1, 50), ground_c)

	# Внешние скальные стены
	_box(root, Vector3(0, 3, -25),  Vector3(50, 8, 2), rock_c)
	_box(root, Vector3(0, 3, 25),   Vector3(50, 8, 2), rock_c)
	_box(root, Vector3(-25, 3, 0),  Vector3(2, 8, 50), rock_c)
	_box(root, Vector3(25, 3, 0),   Vector3(2, 8, 50), rock_c)

	# Центральный туннель (коридор)
	_box(root, Vector3(-10, 1.5, 0), Vector3(18, 3.5, 0.8), rock_c)
	_box(root, Vector3(10, 1.5, 0),  Vector3(18, 3.5, 0.8), rock_c)

	# Деревянные крепления туннеля
	for z in [-8, -4, 0, 4, 8]:
		_box(root, Vector3(-1.8, 2.8, z), Vector3(0.3, 0.3, 0.3), wood_c)
		_box(root, Vector3(1.8, 2.8, z),  Vector3(0.3, 0.3, 0.3), wood_c)
		_box(root, Vector3(0, 3.0, z),    Vector3(4.0, 0.3, 0.3), wood_c)

	# Скальные глыбы (укрытия)
	var rocks = [
		[Vector3(-15, 0.8, -15), Vector3(3, 1.6, 3)],
		[Vector3(15, 0.8, -15),  Vector3(3, 1.6, 3)],
		[Vector3(-15, 0.8, 15),  Vector3(3, 1.6, 3)],
		[Vector3(15, 0.8, 15),   Vector3(3, 1.6, 3)],
		[Vector3(-6, 0.7, -6),   Vector3(2, 1.4, 2)],
		[Vector3(6, 0.7, 6),     Vector3(2, 1.4, 2)],
		[Vector3(-6, 0.7, 6),    Vector3(2, 1.4, 2)],
		[Vector3(6, 0.7, -6),    Vector3(2, 1.4, 2)],
	]
	for r in rocks:
		_box(root, r[0], r[1], rock_c)

	# Рудные жилы
	for x in [-20, 0, 20]:
		_box(root, Vector3(x, 2, -24), Vector3(4, 3, 0.5), ore_c)

	# Металлические рельсы
	_box(root, Vector3(0, 0.05, 0),  Vector3(0.15, 0.1, 48), metal_c)
	_box(root, Vector3(1.2, 0.05, 0), Vector3(0.15, 0.1, 48), metal_c)

	# Вагонетки
	_box(root, Vector3(-8, 0.6, 0),  Vector3(2.0, 1.2, 3.5), metal_c)
	_box(root, Vector3(8, 0.6, 0),   Vector3(2.0, 1.2, 3.5), metal_c)

	# Бочки / ящики
	var crates = [
		Vector3(-18, 0.5, 0),  Vector3(18, 0.5, 0),
		Vector3(0, 0.5, -18),  Vector3(0, 0.5, 18),
		Vector3(-12, 0.5, 12), Vector3(12, 0.5, -12),
	]
	for p in crates:
		_box(root, p, Vector3(1.5, 1.5, 1.5), wood_c)
