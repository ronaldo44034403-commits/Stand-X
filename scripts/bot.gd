extends CharacterBody3D

## STANDX - Bot AI (Standoff 2 стиль)

@export var health: int = 100
@export var max_health: int = 100
@export var move_speed: float = 3.5
@export var shoot_range: float = 20.0
@export var sight_range: float = 26.0
@export var bot_name: String = "Bot"

@export var spawns: PackedVector3Array = ([
	Vector3(-18, 0.2, 0), Vector3(18, 0.2, 0),
	Vector3(-2.8, 0.2, -6), Vector3(-17, 0, 17),
	Vector3(17, 0, 17), Vector3(17, 0, -17), Vector3(-17, 0, -17)
])

const JUMP_VELOCITY: float = 4.5
const PATROL_WAIT: float = 2.5

enum BotState { PATROL, SEARCH, CHASE, SHOOT, DEAD }

var state: BotState = BotState.PATROL
var target_player: Node3D = null
var patrol_target: Vector3
var patrol_timer: float = 0.0
var shoot_timer: float = 0.0
var respawn_timer: float = 0.0
var is_dead: bool = false
var shoot_cooldown: float = 1.6
var damage_per_shot: int = 18
var last_known_pos: Vector3 = Vector3.ZERO
var search_timer: float = 0.0

# Визуальные части
var body_mesh: MeshInstance3D
var head_mesh: MeshInstance3D
var gun_pivot: Node3D
var flash_particles: GPUParticles3D
var name_lbl: Label3D
var hp_bar_3d: MeshInstance3D

@onready var raycast: RayCast3D = $RayCast3D

func _ready() -> void:
	health = max_health
	shoot_cooldown = Global.get_bot_shoot_cooldown()
	damage_per_shot = min(Global.get_bot_damage(), 22)
	position = spawns[randi() % spawns.size()]
	_pick_patrol_target()
	_build_model()

func _build_model() -> void:
	# Уникальный цвет по имени
	var palette = [
		Color(0.85, 0.15, 0.15),
		Color(0.15, 0.4, 0.9),
		Color(0.15, 0.75, 0.25),
		Color(0.9, 0.5, 0.05),
		Color(0.6, 0.15, 0.85),
		Color(0.1, 0.7, 0.7),
	]
	var ci = (bot_name.hash() % palette.size() + palette.size()) % palette.size()
	var tc = palette[ci]

	var m_body = _mat(tc)
	var m_dark = _mat(Color(0.12, 0.1, 0.09))
	var m_skin = _mat(Color(0.92, 0.76, 0.60))
	var m_boot = _mat(Color(0.08, 0.07, 0.06))

	# === ТОРС ===
	body_mesh = _add_box(Vector3(0, 0.78, 0), Vector3(0.42, 0.50, 0.24), m_body)

	# Жилет/броня поверх торса
	var vest = _add_box(Vector3(0, 0.78, 0.01), Vector3(0.44, 0.48, 0.08), _mat(Color(tc.r*0.6, tc.g*0.6, tc.b*0.6)))

	# === ГОЛОВА (сфера) ===
	head_mesh = MeshInstance3D.new()
	var sph = SphereMesh.new()
	sph.radius = 0.17
	sph.height = 0.34
	head_mesh.mesh = sph
	head_mesh.material_override = m_skin
	head_mesh.position = Vector3(0, 1.22, 0)
	add_child(head_mesh)

	# Шлем
	var helm = _add_box(Vector3(0, 1.37, 0), Vector3(0.37, 0.15, 0.37), m_dark)
	# Козырек шлема
	var visor = _add_box(Vector3(0, 1.28, -0.19), Vector3(0.30, 0.06, 0.06), m_dark)

	# Маска/балаклава
	var mask = _add_box(Vector3(0, 1.1, -0.14), Vector3(0.26, 0.14, 0.06), m_dark)

	# === НОГИ ===
	for s in [-1, 1]:
		_add_box(Vector3(s * 0.11, 0.26, 0), Vector3(0.17, 0.48, 0.17), m_dark)
		# Ботинки
		_add_box(Vector3(s * 0.11, 0.03, -0.04), Vector3(0.19, 0.08, 0.22), m_boot)

	# === РУКИ ===
	for s in [-1, 1]:
		_add_box(Vector3(s * 0.30, 0.74, 0), Vector3(0.13, 0.44, 0.13), m_body)
		# Перчатки
		_add_box(Vector3(s * 0.30, 0.50, 0), Vector3(0.14, 0.10, 0.14), m_dark)

	# === ПИСТОЛЕТ ===
	var sk = Global.get_weapon_skin_params()
	var m_gun = StandardMaterial3D.new()
	m_gun.albedo_color = sk.body
	m_gun.metallic = sk.metal
	m_gun.roughness = sk.rough
	var m_gun2 = StandardMaterial3D.new()
	m_gun2.albedo_color = sk.barrel
	m_gun2.metallic = sk.metal
	m_gun2.roughness = sk.rough

	gun_pivot = Node3D.new()
	gun_pivot.position = Vector3(0.30, 0.66, 0.12)
	add_child(gun_pivot)

	# Рукоять
	var grip = MeshInstance3D.new()
	var gbox = BoxMesh.new()
	gbox.size = Vector3(0.07, 0.14, 0.07)
	grip.mesh = gbox
	grip.material_override = m_gun
	gun_pivot.add_child(grip)

	# Затвор/слайд
	var slide = MeshInstance3D.new()
	var sbox = BoxMesh.new()
	sbox.size = Vector3(0.065, 0.075, 0.18)
	slide.mesh = sbox
	slide.material_override = m_gun2
	slide.position = Vector3(0, 0.07, -0.04)
	gun_pivot.add_child(slide)

	# Ствол
	var barrel = MeshInstance3D.new()
	var bcyl = CylinderMesh.new()
	bcyl.top_radius = 0.022
	bcyl.bottom_radius = 0.022
	bcyl.height = 0.20
	barrel.mesh = bcyl
	barrel.material_override = m_gun2
	barrel.rotation_degrees = Vector3(90, 0, 0)
	barrel.position = Vector3(0, 0.05, -0.14)
	gun_pivot.add_child(barrel)

	# === ВСПЫШКА ВЫСТРЕЛА ===
	flash_particles = GPUParticles3D.new()
	flash_particles.emitting = false
	flash_particles.one_shot = true
	flash_particles.amount = 10
	flash_particles.lifetime = 0.06
	flash_particles.explosiveness = 1.0
	var pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.02
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 5.0
	pmat.color = Color(1.0, 0.8, 0.2)
	flash_particles.process_material = pmat
	var fsph = SphereMesh.new()
	fsph.radius = 0.025
	flash_particles.draw_pass_1 = fsph
	flash_particles.position = Vector3(0.30, 0.70, 0.26)
	add_child(flash_particles)

	# === ИМЯ НАД ГОЛОВОЙ ===
	name_lbl = Label3D.new()
	name_lbl.text = bot_name
	name_lbl.font_size = 28
	name_lbl.modulate = Color(1, 0.95, 0.1)
	name_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_lbl.no_depth_test = true
	name_lbl.position = Vector3(0, 1.65, 0)
	add_child(name_lbl)

	# === HP БАР НАД ГОЛОВОЙ ===
	hp_bar_3d = MeshInstance3D.new()
	var bar_box = BoxMesh.new()
	bar_box.size = Vector3(0.5, 0.05, 0.01)
	hp_bar_3d.mesh = bar_box
	hp_bar_3d.material_override = _mat(Color(0.1, 0.9, 0.1))
	hp_bar_3d.position = Vector3(0, 1.80, 0)
	add_child(hp_bar_3d)

func _mat(c: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _add_box(pos: Vector3, sz: Vector3, mat: Material) -> MeshInstance3D:
	var mi = MeshInstance3D.new()
	var bx = BoxMesh.new()
	bx.size = sz
	mi.mesh = bx
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi

func _physics_process(delta: float) -> void:
	if is_dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_respawn()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	shoot_timer = max(shoot_timer - delta, 0.0)
	_update_target()

	match state:
		BotState.PATROL:
			_do_patrol(delta)
		BotState.SEARCH:
			_do_search(delta)
		BotState.CHASE:
			_do_chase(delta)
		BotState.SHOOT:
			_do_shoot(delta)

	# Покачивание при ходьбе
	if velocity.length() > 0.5 and body_mesh:
		body_mesh.position.y = 0.78 + sin(Time.get_ticks_msec() * 0.009) * 0.03

	move_and_slide()

func _update_target() -> void:
	var closest_dist = sight_range
	var closest: Node3D = null

	for p in get_tree().get_nodes_in_group("players"):
		if p == self or p.get("is_dead") == true:
			continue
		var dist = global_position.distance_to(p.global_position)
		if dist >= closest_dist:
			continue
		# Проверка стен
		raycast.global_position = global_position + Vector3(0, 0.9, 0)
		raycast.target_position = raycast.to_local(p.global_position + Vector3(0, 0.9, 0))
		raycast.force_raycast_update()
		if not raycast.is_colliding() or raycast.get_collider() == p:
			closest_dist = dist
			closest = p

	if closest != null:
		target_player = closest
		last_known_pos = target_player.global_position
		if global_position.distance_to(target_player.global_position) <= shoot_range:
			state = BotState.SHOOT
		else:
			state = BotState.CHASE
	else:
		if target_player != null:
			if state == BotState.SHOOT or state == BotState.CHASE:
				state = BotState.SEARCH
				search_timer = 4.0
		target_player = null

func _do_patrol(delta: float) -> void:
	patrol_timer -= delta
	var dir = patrol_target - global_position
	dir.y = 0
	if dir.length() < 1.0 or patrol_timer <= 0.0:
		_pick_patrol_target()
		return
	_move_toward(dir.normalized())

func _do_search(delta: float) -> void:
	search_timer -= delta
	var dir = last_known_pos - global_position
	dir.y = 0
	if dir.length() < 1.5 or search_timer <= 0.0:
		state = BotState.PATROL
		_pick_patrol_target()
		return
	_move_toward(dir.normalized())

func _do_chase(_delta: float) -> void:
	if target_player == null:
		state = BotState.SEARCH
		return
	var dir = target_player.global_position - global_position
	dir.y = 0
	_move_toward(dir.normalized())

func _do_shoot(_delta: float) -> void:
	if target_player == null:
		state = BotState.SEARCH
		return
	var look_dir = target_player.global_position - global_position
	look_dir.y = 0
	if look_dir.length() > 0.1:
		transform.basis = transform.basis.slerp(Basis.looking_at(look_dir.normalized()), 0.18)
	velocity.x = move_toward(velocity.x, 0, move_speed)
	velocity.z = move_toward(velocity.z, 0, move_speed)
	if shoot_timer <= 0.0:
		shoot_timer = shoot_cooldown
		_try_shoot()

func _move_toward(dir: Vector3) -> void:
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed
	if is_on_wall() and is_on_floor():
		velocity.y = JUMP_VELOCITY
	if dir.length() > 0.1:
		transform.basis = transform.basis.slerp(Basis.looking_at(dir), 0.15)

func _pick_patrol_target() -> void:
	patrol_target = spawns[randi() % spawns.size()]
	patrol_timer = PATROL_WAIT + randf() * 3.0

func _try_shoot() -> void:
	if target_player == null:
		return
	# Финальная проверка стен
	raycast.global_position = global_position + Vector3(0, 0.9, 0)
	raycast.target_position = raycast.to_local(target_player.global_position + Vector3(0, 0.9, 0))
	raycast.force_raycast_update()
	if raycast.is_colliding() and raycast.get_collider() != target_player:
		state = BotState.CHASE
		return
	if global_position.distance_to(target_player.global_position) > shoot_range:
		return

	# Анимация пистолета
	if gun_pivot:
		if gun_pivot:
			var tw = create_tween()
			tw.tween_property(gun_pivot, "position:z", 0.22, 0.05)
			tw.tween_property(gun_pivot, "position:z", 0.12, 0.09)

	if flash_particles:
		flash_particles.restart()
		flash_particles.emitting = true

	# Промах
	var miss_rates = [0.55, 0.35, 0.15]
	var miss_idx = clamp(Global.difficulty, 0, 2)
	if randf() < miss_rates[miss_idx]:
		return

	if target_player.has_method("recieve_damage"):
		target_player.recieve_damage(damage_per_shot)

func recieve_damage(damage: int = 25) -> void:
	if is_dead:
		return
	health -= damage

	# Обновляем HP бар над головой
	if hp_bar_3d:
		var pct = float(max(health, 0)) / float(max_health)
		hp_bar_3d.scale.x = max(pct, 0.0)
		var hmat = _mat(Color(1.0 - pct, pct * 0.9, 0.1))
		hp_bar_3d.material_override = hmat

	# Мигание при попадании - меняем материал напрямую
	if body_mesh and body_mesh.material_override:
		var mat := body_mesh.material_override as StandardMaterial3D
		if mat:
			var orig_color: Color = mat.albedo_color
			mat.albedo_color = Color(1, 0, 0)
			get_tree().create_timer(0.12).timeout.connect(func() -> void:
				if is_instance_valid(self) and body_mesh and body_mesh.material_override:
					mat.albedo_color = orig_color, CONNECT_ONE_SHOT)

	if health <= 0:
		_die()

func _die() -> void:
	is_dead = true
	state = BotState.DEAD
	respawn_timer = 5.0
	health = max_health
	visible = false
	var world = get_tree().root.get_node_or_null("World")
	if world and world.has_method("on_bot_killed"):
		world.on_bot_killed(bot_name)

func _respawn() -> void:
	is_dead = false
	state = BotState.PATROL
	health = max_health
	shoot_cooldown = Global.get_bot_shoot_cooldown()
	damage_per_shot = min(Global.get_bot_damage(), 22)
	position = spawns[randi() % spawns.size()]
	_pick_patrol_target()
	visible = true
	if hp_bar_3d:
		hp_bar_3d.scale.x = 1.0
		hp_bar_3d.material_override = _mat(Color(0.1, 0.9, 0.1))
