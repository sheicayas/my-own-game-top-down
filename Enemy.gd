extends CharacterBody2D

signal died(enemy)
signal death_finished(enemy)

const POINTS_VALUE = 25
const STOP_RANGE = 60.0
const SHOOT_RANGE = 400.0
const AVOIDANCE_CHECK_DISTANCE = 42.0
const STUCK_CHECK_TIME = 0.35
const STUCK_MIN_MOVE = 4.0
const SIDE_PATH_TIME = 0.9
const PICKUP_DROP_CHANCE = 0.25
const AVOIDANCE_ANGLES = [28.0, -28.0, 55.0, -55.0, 85.0, -85.0, 120.0, -120.0]
const TYPE_OFFICER = 0
const TYPE_RUNNER = 1
const TYPE_BRUTE = 2

@onready var sprite = $AnimatedSprite2D
@onready var hurt_timer = $HurtTimer
@onready var attack_timer = $AttackTimer
@onready var shoot_timer = $ShootTimer
@onready var collision = $CollisionShape2D
@onready var health_bar = $HealthBar
@onready var player_detector = $PlayerDetector
@onready var fire_sound = $FireSound
@onready var die_sound = $DieSound

var bullet_scene = preload("res://scenes/OfficerBullet.tscn")
var health_pickup_scene = preload("res://scenes/HealthPickup.tscn")
var armor_pickup_scene = preload("res://scenes/ArmorPickup.tscn")
var ammo_pickup_scene = preload("res://scenes/AmmoPickup.tscn")

var enemy_type = TYPE_OFFICER
var move_speed = 80.0
var max_health = 5
var health = max_health
var shoot_cooldown = 1.0
var attack_cooldown = 1.0
var stop_range = STOP_RANGE
var shoot_range = SHOOT_RANGE
var can_shoot_projectiles = true
var bullet_count = 1
var bullet_spread_degrees = 0.0
var points_value = POINTS_VALUE
var base_modulate = Color(1, 1, 1)

var player = null
var is_dead = false
var is_hurt = false
var is_attacking = false
var is_shooting = false
var shoot_token = 0
var last_position = Vector2.ZERO
var stuck_time = 0.0
var side_path_time = 0.0
var side_path_sign = 1.0
var blinded = false


func _ready():
	add_to_group("enemy")
	last_position = global_position
	_apply_enemy_style()
	hurt_timer.wait_time = 0.3
	hurt_timer.one_shot = true
	hurt_timer.timeout.connect(_on_hurt_timer_timeout)
	attack_timer.wait_time = attack_cooldown
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	shoot_timer.wait_time = shoot_cooldown
	shoot_timer.one_shot = true
	sprite.animation_finished.connect(_on_animation_finished)
	sprite.play("walk")
	_update_health_bar()


func _physics_process(delta):
	if player == null:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	if is_dead or player == null:
		return
	rotation = (player.global_position - global_position).angle()
	sprite.modulate = Color(1, 0.3, 0.3) if is_hurt else base_modulate
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_stuck_state(delta)
		return
	var dist = global_position.distance_to(player.global_position)
	_update_stuck_state(delta)
	var separation = Vector2.ZERO
	var min_dist = 80.0
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == self:
			continue
		var gap = global_position.distance_to(enemy.global_position)
		if gap < min_dist and gap > 0.0:
			separation += (global_position - enemy.global_position).normalized() * (min_dist - gap)
	if dist > stop_range:
		var direct_chase_dir = Vector2.RIGHT.rotated(rotation)
		var chase_dir = _get_ai_chase_direction(direct_chase_dir, delta)
		var effective_speed = move_speed * (0.4 if blinded else 1.0)
		velocity = (chase_dir * effective_speed) + separation
		if not is_hurt and not is_shooting:
			sprite.play("walk")
	else:
		if can_shoot_projectiles and not is_shooting:
			var strafe_dir = Vector2.RIGHT.rotated(rotation + PI / 2.0) * side_path_sign
			var effective_speed = move_speed * (0.4 if blinded else 1.0)
			velocity = strafe_dir * effective_speed * 0.35 + separation
		else:
			velocity = separation
	move_and_slide()
	if can_shoot_projectiles and not is_shooting and shoot_timer.time_left <= 0.0 and dist <= shoot_range:
		_shoot()


func configure_for_wave(kind, wave):
	enemy_type = kind
	var tier = GameManager.get_difficulty_tier()
	var hp_mult = 1.0 + float(tier) * 0.20
	var spd_mult = 1.0 + float(tier) * 0.10
	var pts_mult = 1.0 + float(tier) * 0.05
	match enemy_type:
		TYPE_RUNNER:
			move_speed = min(120.0 + float(wave - 1) * 5.5, 175.0) * spd_mult
			max_health = max(1, int((min(2 + int(sqrt(float(wave)) * 1.4), 8)) * hp_mult))
			shoot_cooldown = max(0.75, 1.25 - float(wave - 1) * 0.03)
			attack_cooldown = 1.2
			stop_range = 42.0
			shoot_range = 210.0
			can_shoot_projectiles = true
			bullet_count = 1
			bullet_spread_degrees = 0.0
			points_value = int(15 * pts_mult)
		TYPE_BRUTE:
			move_speed = min(48.0 + float(wave - 1) * 3.5, 90.0) * spd_mult
			max_health = max(1, int((min(8 + int(sqrt(float(wave)) * 4.5), 30)) * hp_mult))
			shoot_cooldown = max(1.0, 1.65 - float(wave - 1) * 0.04)
			attack_cooldown = 1.8
			stop_range = 120.0
			shoot_range = 380.0
			can_shoot_projectiles = true
			bullet_count = 3
			bullet_spread_degrees = 16.0
			points_value = int(45 * pts_mult)
		_:
			move_speed = min(68.0 + float(wave - 1) * 6.0, 145.0) * spd_mult
			max_health = max(1, int((min(3 + int(sqrt(float(wave)) * 2.2), 14)) * hp_mult))
			shoot_cooldown = max(0.65, 1.45 - float(wave - 1) * 0.06)
			attack_cooldown = 1.5
			stop_range = STOP_RANGE
			shoot_range = SHOOT_RANGE
			can_shoot_projectiles = true
			bullet_count = 1
			bullet_spread_degrees = 0.0
			points_value = int(POINTS_VALUE * pts_mult)
	health = max_health


func _apply_enemy_style():
	match enemy_type:
		TYPE_RUNNER:
			sprite.speed_scale = 1.35
			base_modulate = Color(0.45, 0.95, 1.0)
			sprite.modulate = base_modulate
			if get_node_or_null("ThreatLight") != null:
				$ThreatLight.color = Color(0.1, 0.8, 1.0)
				$ThreatLight.energy = 1.0
		TYPE_BRUTE:
			sprite.speed_scale = 0.78
			base_modulate = Color(0.55, 1.0, 0.38)
			sprite.modulate = base_modulate
			if get_node_or_null("ThreatLight") != null:
				$ThreatLight.color = Color(0.2, 1.0, 0.18)
				$ThreatLight.energy = 1.25
		_:
			sprite.speed_scale = 1.0
			base_modulate = Color(1.0, 0.68, 0.45)
			sprite.modulate = base_modulate
			if get_node_or_null("ThreatLight") != null:
				$ThreatLight.color = Color(1.0, 0.22, 0.05)
				$ThreatLight.energy = 0.95


func _update_stuck_state(delta):
	var moved = global_position.distance_to(last_position)
	if moved < STUCK_MIN_MOVE and velocity.length() > 1.0:
		stuck_time += delta
	else:
		stuck_time = 0.0
	last_position = global_position
	if stuck_time >= STUCK_CHECK_TIME and side_path_time <= 0.0:
		side_path_time = SIDE_PATH_TIME
		side_path_sign = 1.0 if randf() > 0.5 else -1.0
		stuck_time = 0.0


func _get_ai_chase_direction(direct_dir, delta):
	if direct_dir == Vector2.ZERO:
		return Vector2.ZERO
	if side_path_time > 0.0:
		side_path_time -= delta
		var side_dir = direct_dir.rotated(deg_to_rad(75.0 * side_path_sign)).normalized()
		if not _is_direction_blocked(side_dir):
			return side_dir
	if not _is_direction_blocked(direct_dir):
		return direct_dir
	var best_dir = direct_dir
	var best_score = -2.0
	for angle in AVOIDANCE_ANGLES:
		var candidate = direct_dir.rotated(deg_to_rad(angle)).normalized()
		if _is_direction_blocked(candidate):
			continue
		var score = candidate.dot(direct_dir)
		if score > best_score:
			best_score = score
			best_dir = candidate
	return best_dir


func _is_direction_blocked(direction):
	return test_move(global_transform, direction.normalized() * AVOIDANCE_CHECK_DISTANCE)


func _shoot():
	if is_dead or not can_shoot_projectiles or bullet_count <= 0:
		return
	is_shooting = true
	shoot_token += 1
	var current_shot = shoot_token
	sprite.play("shoot")
	await get_tree().create_timer(0.2, false).timeout
	if is_dead or current_shot != shoot_token:
		return
	var base_direction = Vector2.RIGHT.rotated(rotation)
	var spread_start = -bullet_spread_degrees * float(max(bullet_count - 1, 0)) * 0.5
	for i in range(max(bullet_count, 1)):
		var bullet = bullet_scene.instantiate()
		bullet.process_mode = Node.PROCESS_MODE_PAUSABLE
		bullet.global_position = global_position + base_direction * 18.0
		var angle_offset = spread_start + bullet_spread_degrees * float(i)
		bullet.direction = base_direction.rotated(deg_to_rad(angle_offset))
		get_parent().add_child(bullet)
	fire_sound.play()


func take_damage(amount):
	if is_dead:
		return
	health -= amount
	_update_health_bar()
	Juice.damage_number(global_position, amount, amount >= 3)
	if health <= 0:
		_die()
	else:
		is_hurt = true
		hurt_timer.start()


func _die():
	is_dead = true
	velocity = Vector2.ZERO
	is_hurt = false
	is_attacking = false
	is_shooting = false
	shoot_token += 1
	hurt_timer.stop()
	attack_timer.stop()
	shoot_timer.stop()
	remove_from_group("enemy")
	collision.set_deferred("disabled", true)
	player_detector.set_deferred("monitoring", false)
	player_detector.set_deferred("monitorable", false)
	health_bar.visible = false
	Juice.death_burst(global_position, base_modulate)
	Juice.shake(7.0, 0.14)
	die_sound.play()
	sprite.play("die")
	_drop_pickup()
	GameManager.add_score(points_value)
	emit_signal("died", self)


func _drop_pickup():
	var drop_chance = PICKUP_DROP_CHANCE
	var player_node = get_tree().get_first_node_in_group("player")
	if player_node != null and player_node.get("is_lucky") == true:
		drop_chance = 0.50
	if randf() > drop_chance:
		return
	var roll = randf()
	var pickup
	if roll < 0.40:
		pickup = health_pickup_scene.instantiate()
	elif roll < 0.60:
		pickup = armor_pickup_scene.instantiate()
	else:
		pickup = ammo_pickup_scene.instantiate()
	pickup.process_mode = Node.PROCESS_MODE_PAUSABLE
	pickup.global_position = global_position
	get_tree().current_scene.call_deferred("add_child", pickup)


func _update_health_bar():
	health_bar.max_value = max_health
	health_bar.value = health
	health_bar.visible = health < max_health and not is_dead


func _on_hurt_timer_timeout():
	is_hurt = false


func _on_attack_timer_timeout():
	is_attacking = false


func _on_animation_finished():
	match sprite.animation:
		"die":
			death_finished.emit(self)
			queue_free()
		"shoot":
			is_shooting = false
			shoot_timer.start()
			if not is_dead:
				sprite.play("walk")


func _on_body_entered(body):
	if is_dead:
		return
	if body.is_in_group("player") and not is_attacking:
		is_attacking = true
		body.take_damage()
		attack_timer.start()
