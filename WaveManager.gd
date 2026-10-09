extends Node

signal wave_cleared(wave_num)

@export var spawn_margin = 56.0

var enemy_scene = preload("res://scenes/Enemy.tscn")

var active_enemies = []
var player = null
var wave_in_progress = false
var between_wave_delay = 2.5
var enemies_to_spawn = 0
var enemies_spawned = 0


func _ready():
	GameManager.reset()
	randomize()


func start_game(p):
	player = p
	_start_next_wave()


func start_next_wave_after_upgrade():
	if GameManager.is_game_over:
		return
	_start_next_wave()


func _start_next_wave():
	GameManager.next_wave()
	wave_in_progress = true
	enemies_to_spawn = GameManager.get_enemy_count_for_wave()
	enemies_spawned = 0
	GameManager.set_enemies(0, enemies_to_spawn)
	await get_tree().create_timer(between_wave_delay, false).timeout
	if GameManager.is_game_over:
		return
	_spawn_wave_enemies()


func _spawn_wave_enemies():
	var count = enemies_to_spawn
	if enemy_scene == null:
		push_error("Enemy scene is missing.")
		return
	GameManager.set_enemies(active_enemies.size(), enemies_to_spawn)
	var wave = GameManager.current_wave
	var spawn_delay = 0.25 if wave % 5 == 0 else 0.4
	for i in range(count):
		if GameManager.is_game_over:
			return
		await get_tree().create_timer(spawn_delay, false).timeout
		_spawn_enemy(_random_spawn_position())
		enemies_spawned += 1
		GameManager.set_enemies(active_enemies.size(), enemies_to_spawn)
	_check_wave_clear()


func _spawn_enemy(spawn_position):
	var wave = GameManager.current_wave
	var enemy = enemy_scene.instantiate()
	enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
	if enemy.has_method("configure_for_wave"):
		enemy.call("configure_for_wave", _choose_enemy_type(wave), wave)
	enemy.set("player", player)
	get_parent().add_child(enemy)
	enemy.global_position = spawn_position
	register_enemy(enemy)


func _choose_enemy_type(wave):
	var roll = randf()
	match wave:
		1, 2:
			return 0
		3:
			return 1 if roll < 0.25 else 0
		4:
			return 1 if roll < 0.35 else 0
		5:
			return 1 if roll < 0.45 else 0
		6:
			if roll < 0.15:
				return 2
			elif roll < 0.50:
				return 1
			else:
				return 0
		_:
			var brute_chance = min(0.10 + float(wave - 6) * 0.02, 0.25)
			var runner_chance = min(0.35 + float(wave - 6) * 0.02, 0.50)
			if roll < brute_chance:
				return 2
			elif roll < brute_chance + runner_chance:
				return 1
			else:
				return 0


func register_enemy(enemy):
	active_enemies.append(enemy)
	enemy.connect("died", Callable(self, "_on_enemy_died"))
	if player != null:
		enemy.set("player", player)
	GameManager.set_enemies(active_enemies.size(), enemies_to_spawn)


func _on_enemy_died(enemy):
	active_enemies.erase(enemy)
	GameManager.set_enemies(active_enemies.size(), enemies_to_spawn)
	var is_final_enemy = enemies_spawned >= enemies_to_spawn and active_enemies.size() == 0
	if is_final_enemy:
		Juice.final_kill_slowmo()
		if is_instance_valid(enemy) and enemy.has_signal("death_finished"):
			await enemy.death_finished
	_check_wave_clear()


func _check_wave_clear():
	if enemies_spawned < enemies_to_spawn:
		return
	if active_enemies.size() == 0 and wave_in_progress:
		wave_in_progress = false
		emit_signal("wave_cleared", GameManager.current_wave)


func _random_spawn_position():
	var level = get_parent().get_node_or_null("Level")
	var arena = Rect2(spawn_margin, spawn_margin, 1848.0 - spawn_margin * 2.0, 1048.0 - spawn_margin * 2.0)
	if level != null and level.has_method("get_arena_rect"):
		arena = level.get_arena_rect()
	var min_x = arena.position.x
	var max_x = arena.end.x
	var min_y = arena.position.y
	var max_y = arena.end.y
	match randi() % 4:
		0:
			return Vector2(randf_range(min_x, max_x), min_y)
		1:
			return Vector2(randf_range(min_x, max_x), max_y)
		2:
			return Vector2(min_x, randf_range(min_y, max_y))
		_:
			return Vector2(max_x, randf_range(min_y, max_y))
