extends CharacterBody2D

signal weapon_power_changed(is_active, power_level, time_left)

const MOVE_SPEED = 200.0
const MOVE_ACCELERATION = 1500.0
const MOVE_FRICTION = 1800.0
const FIRE_COOLDOWN = 0.25
const WORLD_BOUNDS = Rect2(24, 24, 1800, 1000)
const MAX_BULLET_DAMAGE = 4
const POWER_FIRE_COOLDOWNS = [0.25, 0.18, 0.13, 0.10]
const AMMO_POWER_DURATION = 8.0
const BULLET_SPREAD_DEGREES = 2.0
const POWER_LEVEL_NAMES = ["NORMAL", "RAPID", "DOUBLE", "BURST"]
const POWER_SHOT_COUNTS = [1, 1, 2, 3]
const POWER_SPREAD_DEGREES = [2.0, 1.5, 7.0, 11.0]
const GUN_RECOIL_KICK = 7.0
const GUN_RECOIL_RECOVER_SPEED = 42.0

@onready var sprite = $AnimatedSprite2D
@onready var gun_pivot = $GunPivot
@onready var muzzle = $GunPivot/Muzzle
@onready var fire_timer = $FireTimer
@onready var hurt_timer = $HurtTimer
@onready var collision = $CollisionShape2D
@onready var fire_sound = $FireSound
@onready var collect_sound = $CollectSound

var bullet_scene = preload("res://scenes/Bullet.tscn")

var can_shoot = true
var is_hurt = false
var is_dead = false
var has_armor = false
var bullet_damage = 1
var bullet_power_level = 1
var ammo_power_active = false
var ammo_power_time_left = 0.0
var aim_direction = Vector2.RIGHT
var gun_recoil_offset = 0.0
var bonus_bullet_damage = 0
var bonus_shot_count = 0
var current_move_speed = MOVE_SPEED
var pierce_count = 0
var bonus_fire_rate = 0
var is_lucky = false
var has_auto_fire = false
var has_blinding_light = false


func _ready():
	add_to_group("player")
	fire_timer.wait_time = FIRE_COOLDOWN
	fire_timer.one_shot = true
	fire_timer.timeout.connect(_on_fire_timer_timeout)
	hurt_timer.wait_time = 1.8
	hurt_timer.one_shot = true
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)
	GameManager.game_over.connect(_on_game_over)


func _physics_process(delta):
	if is_dead:
		return
	_update_recoil(delta)
	_update_ammo_power(delta)
	_handle_aim()
	_handle_movement(delta)
	_handle_shooting()
	_apply_blinding_light()
	move_and_slide()
	_clamp_to_world()


func _handle_movement(delta):
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * current_move_speed, MOVE_ACCELERATION * delta)
		if not is_hurt:
			sprite.play("walk")
	else:
		velocity = velocity.move_toward(Vector2.ZERO, MOVE_FRICTION * delta)
		if not is_hurt:
			sprite.play("idle")


func _handle_aim():
	var mouse_pos = get_global_mouse_position()
	aim_direction = (mouse_pos - global_position).normalized()
	gun_pivot.rotation = aim_direction.angle()
	gun_pivot.position = -aim_direction * gun_recoil_offset
	sprite.flip_h = false
	sprite.rotation = _get_cardinal_rotation(aim_direction)


func _get_cardinal_rotation(direction):
	if abs(direction.x) > abs(direction.y):
		return 0.0 if direction.x >= 0.0 else PI
	return PI / 2.0 if direction.y >= 0.0 else -PI / 2.0


func _update_recoil(delta):
	gun_recoil_offset = max(0.0, gun_recoil_offset - GUN_RECOIL_RECOVER_SPEED * delta)


func _update_ammo_power(delta):
	if not ammo_power_active:
		return
	ammo_power_time_left = max(0.0, ammo_power_time_left - delta)
	emit_signal("weapon_power_changed", true, bullet_power_level, ammo_power_time_left)
	if ammo_power_time_left <= 0.0:
		_deactivate_ammo_power()


func _handle_shooting():
	var shoot_input = Input.is_action_just_pressed("shoot") if not has_auto_fire else Input.is_action_pressed("shoot")
	if shoot_input and can_shoot:
		_fire()


func _fire():
	can_shoot = false
	_refresh_fire_timer_wait_time()
	fire_timer.start()
	_fire_weapon_level_shots()
	gun_recoil_offset = GUN_RECOIL_KICK
	sprite.play("shoot")
	_spawn_muzzle_flash()
	fire_sound.play()


func _spawn_muzzle_flash():
	var flash = Node2D.new()
	flash.process_mode = Node.PROCESS_MODE_PAUSABLE
	flash.global_position = muzzle.global_position
	flash.rotation = gun_pivot.rotation
	get_tree().current_scene.add_child(flash)
	var cone = Polygon2D.new()
	cone.color = Color(1.0, 0.88, 0.28, 0.85)
	cone.polygon = PackedVector2Array([Vector2.ZERO, Vector2(30, -9), Vector2(48, 0), Vector2(30, 9)])
	flash.add_child(cone)
	var glow = Polygon2D.new()
	var glow_points = PackedVector2Array()
	for i in range(14):
		var angle = TAU * float(i) / 14.0
		glow_points.append(Vector2.RIGHT.rotated(angle) * 8.0)
	glow.polygon = glow_points
	glow.color = Color(1.0, 0.95, 0.5, 0.45)
	flash.add_child(glow)
	var tween = flash.create_tween()
	tween.tween_property(flash, "scale", Vector2.ONE * 1.45, 0.06)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.06)
	tween.tween_callback(Callable(flash, "queue_free"))


func _fire_weapon_level_shots():
	var level_index = clamp(bullet_power_level - 1, 0, POWER_SHOT_COUNTS.size() - 1)
	var shot_count = min(POWER_SHOT_COUNTS[level_index] + bonus_shot_count, 4)
	var spread_degrees = max(POWER_SPREAD_DEGREES[level_index], 4.0 + float(shot_count - 1) * 4.0)
	for i in range(shot_count):
		var spread = 0.0
		if shot_count > 1:
			var spread_step = spread_degrees / float(shot_count - 1)
			spread = -spread_degrees * 0.5 + spread_step * float(i)
		spread += randf_range(-BULLET_SPREAD_DEGREES, BULLET_SPREAD_DEGREES)
		_spawn_player_bullet(aim_direction.rotated(deg_to_rad(spread)).normalized())


func _spawn_player_bullet(shot_direction):
	var bullet = bullet_scene.instantiate()
	bullet.process_mode = Node.PROCESS_MODE_PAUSABLE
	bullet.global_position = muzzle.global_position
	bullet.direction = shot_direction
	bullet.damage = bullet_damage
	bullet.power_level = bullet_power_level
	bullet.pierce_count = pierce_count
	get_tree().current_scene.add_child(bullet)


func _apply_blinding_light():
	if not has_blinding_light:
		return
	var flashlight_range = 220.0
	var cone_half_angle = deg_to_rad(35.0)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		var to_enemy = enemy.global_position - global_position
		var dist = to_enemy.length()
		if dist > flashlight_range:
			enemy.set("blinded", false)
			continue
		var angle = aim_direction.angle_to(to_enemy.normalized())
		if abs(angle) <= cone_half_angle:
			enemy.set("blinded", true)
		else:
			enemy.set("blinded", false)


func _clamp_to_world():
	global_position.x = clamp(global_position.x, WORLD_BOUNDS.position.x, WORLD_BOUNDS.end.x)
	global_position.y = clamp(global_position.y, WORLD_BOUNDS.position.y, WORLD_BOUNDS.end.y)


func take_damage():
	if is_dead or is_hurt:
		return
	if has_armor:
		has_armor = false
		_refresh_player_modulate()
		Juice.shake(5.5, 0.12)
		Juice.pickup_text(global_position, "ARMOR BLOCK", Color(0.45, 0.75, 1.0))
		return
	is_hurt = true
	hurt_timer.start()
	sprite.play("hurt")
	Juice.shake(11.0, 0.18)
	Juice.damage_number(global_position, 1, false)
	GameManager.lose_life()


func collect_pickup(pickup_type):
	collect_sound.play()
	match pickup_type:
		"health":
			GameManager.gain_life(1)
			return "HEALTH +1"
		"armor":
			has_armor = true
			_refresh_player_modulate()
			return "ARMOR"
		"ammo":
			_activate_ammo_power()
			return "WEAPON " + get_weapon_level_name()
	return "PICKUP"


func _activate_ammo_power():
	var was_power_active = ammo_power_active
	ammo_power_active = true
	ammo_power_time_left = AMMO_POWER_DURATION
	if bullet_power_level < 2 or not was_power_active:
		bullet_power_level = 2
	else:
		bullet_power_level = min(bullet_power_level + 1, MAX_BULLET_DAMAGE)
	bullet_damage = bullet_power_level
	bullet_damage += bonus_bullet_damage
	_refresh_fire_timer_wait_time()
	can_shoot = true
	_refresh_player_modulate()
	emit_signal("weapon_power_changed", true, bullet_power_level, ammo_power_time_left)


func get_weapon_level_name():
	var level_index = clamp(bullet_power_level - 1, 0, POWER_LEVEL_NAMES.size() - 1)
	return POWER_LEVEL_NAMES[level_index]


func _deactivate_ammo_power():
	ammo_power_active = false
	ammo_power_time_left = 0.0
	bullet_power_level = 1
	bullet_damage = 1 + bonus_bullet_damage
	_refresh_fire_timer_wait_time()
	_refresh_player_modulate()
	emit_signal("weapon_power_changed", false, bullet_power_level, ammo_power_time_left)


func apply_wave_upgrade(upgrade_id):
	match upgrade_id:
		"heal":
			GameManager.gain_life(2)
		"armor":
			has_armor = true
			_refresh_player_modulate()
		"fire_rate":
			bonus_shot_count = min(bonus_shot_count + 1, 3)
		"bullet_damage":
			var tier = GameManager.get_difficulty_tier()
			var gain = 1 + tier
			bonus_bullet_damage += gain
			bullet_damage = max(1, bullet_power_level) + bonus_bullet_damage
		"max_hp":
			GameManager.MAX_LIVES = min(GameManager.MAX_LIVES + 1, 15)
			GameManager.gain_life(1)
		"lucky":
			is_lucky = true
		"auto_fire":
			has_auto_fire = true
		"blinding_light":
			has_blinding_light = true


func _refresh_fire_timer_wait_time():
	var base_cooldown = FIRE_COOLDOWN
	if ammo_power_active:
		base_cooldown = POWER_FIRE_COOLDOWNS[clamp(bullet_power_level - 1, 0, POWER_FIRE_COOLDOWNS.size() - 1)]
	base_cooldown = max(base_cooldown * pow(0.85, bonus_fire_rate), 0.07)
	fire_timer.wait_time = base_cooldown


func _refresh_player_modulate():
	if ammo_power_active:
		match bullet_power_level:
			4:
				sprite.modulate = Color(0.35, 0.9, 1.0)
			3:
				sprite.modulate = Color(1.0, 0.35, 0.9)
			_:
				sprite.modulate = Color(1.0, 0.82, 0.28)
	elif has_armor:
		sprite.modulate = Color(0.45, 0.75, 1.0)
	else:
		sprite.modulate = Color(1, 1, 1)


func _on_fire_timer_timeout():
	can_shoot = true


func _on_hurt_timer_timeout():
	is_hurt = false


func _on_game_over():
	Juice.reset_time_scale()
	is_dead = true
	velocity = Vector2.ZERO
	can_shoot = false
	if ammo_power_active:
		_deactivate_ammo_power()
	sprite.play("die")
	collision.set_deferred("disabled", true)
