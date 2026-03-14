extends CharacterBody3D

## STANDX - Player с системой оружия

@onready var camera: Camera3D = $Camera3D
@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var muzzle_flash: GPUParticles3D = $Camera3D/pistol/GPUParticles3D
@onready var raycast: RayCast3D = $Camera3D/RayCast3D
@onready var gunshot_sound: AudioStreamPlayer3D = %GunshotSound

@export var max_health: int = 100
var health: int = max_health
var team: int = 0  # 0=CT, 1=T

@export var spawns_ct: PackedVector3Array = ([
	Vector3(-18,0.2,0), Vector3(-15,0.2,5), Vector3(-15,0.2,-5)
])
@export var spawns_t: PackedVector3Array = ([
	Vector3(18,0.2,0), Vector3(15,0.2,5), Vector3(15,0.2,-5)
])

var is_dead: bool = false
var respawn_timer: float = 0.0
var mobile_hud: Node = null

# Оружие
var current_weapon_type: int = Global.selected_weapon
var weapon_data: Dictionary = {}
var ammo_clip: int = 0
var ammo_reserve: int = 0
var is_reloading: bool = false
var shoot_timer: float = 0.0
var shoot_hold_timer: float = 0.0

const SPEED: float = 5.5
const JUMP_VELOCITY: float = 4.5
var _look_vel: Vector2 = Vector2.ZERO

func _ready() -> void:
	health = max_health
	camera.current = true
	team = Global.player_team
	current_weapon_type = Global.selected_weapon
	_init_weapon(current_weapon_type)
	_apply_weapon_skin()
	add_to_group("players")
	add_to_group("team_" + str(team))
	if not DisplayServer.is_touchscreen_available():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Спавн по команде
	var spawn_arr = spawns_ct if team == 0 else spawns_t
	position = spawn_arr[randi() % spawn_arr.size()]
	await get_tree().process_frame
	var world = get_tree().root.get_node_or_null("World")
	if world and world.has_node("MobileHUD"):
		mobile_hud = world.get_node("MobileHUD")
		if mobile_hud.has_signal("jump_pressed"):
			mobile_hud.jump_pressed.connect(_on_jump)
		if mobile_hud.has_signal("shoot_pressed"):
			mobile_hud.shoot_pressed.connect(_on_shoot_btn)
		if mobile_hud.has_signal("reload_pressed"):
			mobile_hud.reload_pressed.connect(start_reload)

func _init_weapon(type: int) -> void:
	weapon_data = WeaponData.get_data(type)
	ammo_clip = weapon_data.ammo_clip
	ammo_reserve = weapon_data.ammo_reserve
	shoot_timer = 0.0
	is_reloading = false
	_update_ammo_hud()

func _apply_weapon_skin() -> void:
	var pistol = get_node_or_null("Camera3D/pistol")
	if not pistol: return
	var sk = Global.get_weapon_skin_params()
	for child in pistol.get_children():
		if child is MeshInstance3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = sk.body
			mat.metallic = sk.metal
			mat.roughness = sk.rough
			child.material_override = mat

func _update_ammo_hud() -> void:
	if mobile_hud and mobile_hud.has_method("update_ammo"):
		if weapon_data.get("infinite_ammo", false):
			mobile_hud.update_ammo(-1, -1)
		else:
			mobile_hud.update_ammo(ammo_clip, ammo_reserve)
	if mobile_hud and mobile_hud.has_method("update_weapon_name"):
		mobile_hud.update_weapon_name(weapon_data.get("name",""))

func _process(delta: float) -> void:
	if is_dead:
		respawn_timer -= delta
		if respawn_timer <= 0.0: _do_respawn()
		return

	shoot_timer = max(shoot_timer - delta, 0.0)

	# Камера от правого джойстика
	if mobile_hud and mobile_hud.has_method("get_look_input"):
		var raw = mobile_hud.get_look_input()
		_look_vel = _look_vel.lerp(raw, 0.9)
		if _look_vel.length() > 0.01:
			var spd: float = Global.touch_look_sensitivity * 3.5
			rotate_y(-_look_vel.x * spd * delta)
			camera.rotate_x(-_look_vel.y * spd * delta)
			camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)

	# Авто-огонь для автоматов
	if weapon_data.get("auto", false):
		if mobile_hud and mobile_hud.has_method("is_shoot_held"):
			if mobile_hud.is_shoot_held() and not is_dead:
				if shoot_timer <= 0.0 and not is_reloading:
					_try_shoot()

func _unhandled_input(event: InputEvent) -> void:
	if is_dead: return
	if event is InputEventMouseMotion and not DisplayServer.is_touchscreen_available():
		rotate_y(-event.relative.x * Global.sensitivity)
		camera.rotate_x(-event.relative.y * Global.sensitivity)
		camera.rotation.x = clamp(camera.rotation.x, -1.4, 1.4)
	if Input.is_action_just_pressed("shoot") and shoot_timer <= 0.0:
		_try_shoot()

func _on_jump() -> void:
	if is_on_floor() and not is_dead:
		velocity.y = JUMP_VELOCITY

func _on_shoot_btn() -> void:
	if not is_dead and shoot_timer <= 0.0 and not is_reloading:
		_try_shoot()

func _try_shoot() -> void:
	if is_reloading: return
	# Нож — ближний бой
	if weapon_data.get("infinite_ammo", false):
		_do_shoot()
		return
	if ammo_clip <= 0:
		start_reload()
		return
	ammo_clip -= 1
	_update_ammo_hud()
	_do_shoot()
	if ammo_clip == 0:
		start_reload()

func _do_shoot() -> void:
	shoot_timer = weapon_data.get("fire_rate", 0.2)
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true
	gunshot_sound.play()

	# Разброс
	var spread = weapon_data.get("spread", 0.0)
	var shoot_dir = -camera.global_transform.basis.z
	shoot_dir += Vector3(randf_range(-spread,spread), randf_range(-spread,spread), randf_range(-spread,spread))
	shoot_dir = shoot_dir.normalized()

	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		camera.global_position,
		camera.global_position + shoot_dir * weapon_data.get("range", 30.0)
	)
	query.exclude = [self]
	var result = space.intersect_ray(query)
	if result and result.collider.has_method("recieve_damage"):
		result.collider.recieve_damage(weapon_data.get("damage", 34))
		# Мигание прицела при попадании
		if mobile_hud and mobile_hud.has_method("hit_marker"):
			mobile_hud.hit_marker()

func start_reload() -> void:
	if is_reloading: return
	if ammo_reserve <= 0: return
	if ammo_clip == weapon_data.get("ammo_clip", 30): return
	is_reloading = true
	if mobile_hud and mobile_hud.has_method("show_reload"):
		mobile_hud.show_reload(1.8)
	var tw = create_tween()
	tw.tween_interval(1.8)
	tw.tween_callback(func() -> void:
		var need = weapon_data.get("ammo_clip",30) - ammo_clip
		var take = min(need, ammo_reserve)
		ammo_clip += take
		ammo_reserve -= take
		is_reloading = false
		_update_ammo_hud())

func _physics_process(delta: float) -> void:
	if is_dead: return
	if not is_on_floor(): velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir: Vector2 = Input.get_vector("left","right","up","down")
	if mobile_hud and mobile_hud.has_method("get_move_input"):
		var mm = mobile_hud.get_move_input()
		if mm.length() > 0.05: input_dir = mm
	var dir: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y))
	if dir:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	if anim_player.current_animation != "shoot":
		if input_dir != Vector2.ZERO and is_on_floor():
			anim_player.play("move")
		else:
			anim_player.play("idle")
	move_and_slide()

func recieve_damage(damage: int = 34) -> void:
	if is_dead: return
	health -= damage
	_update_hud_hp()
	# Красная вспышка
	if mobile_hud:
		var flash = ColorRect.new()
		flash.color = Color(1,0,0,0.35)
		flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		(mobile_hud as CanvasLayer).add_child(flash)
		var tw = create_tween()
		tw.tween_property(flash,"modulate:a",0.0,0.3)
		tw.tween_callback(flash.queue_free)
	if health <= 0: _die()

func _update_hud_hp() -> void:
	if mobile_hud and mobile_hud.has_method("update_hp"):
		mobile_hud.update_hp(max(health,0), max_health)

func _die() -> void:
	is_dead = true
	health = 0
	Global.match_deaths += 1
	_update_hud_hp()
	respawn_timer = 5.0 if Global.game_mode == 1 else 3.0
	visible = false
	if mobile_hud and mobile_hud.has_method("show_death"):
		mobile_hud.show_death(respawn_timer)
	var world = get_tree().root.get_node_or_null("World")
	if world and world.has_method("on_player_killed"):
		world.on_player_killed("You")

func _do_respawn() -> void:
	is_dead = false
	health = max_health
	var spawn_arr = spawns_ct if team == 0 else spawns_t
	position = spawn_arr[randi() % spawn_arr.size()]
	_init_weapon(current_weapon_type)
	_update_hud_hp()
	visible = true

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "shoot": anim_player.play("idle")
