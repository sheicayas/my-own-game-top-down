extends Node

signal lives_changed(new_lives)
signal score_changed(new_score)
signal high_score_changed(new_high_score)
signal wave_changed(new_wave)
signal enemies_changed(alive, total)
signal game_over()

const SAVE_PATH = "user://save_data.cfg"

var MAX_LIVES = 10
var lives = MAX_LIVES
var score = 0
var high_score = 0
var current_wave = 0
var is_game_over = false
var upgrade_pick_counts = {}


func reset():
	_load_high_score()
	MAX_LIVES = 10
	lives = MAX_LIVES
	score = 0
	current_wave = 0
	is_game_over = false
	upgrade_pick_counts = {}
	emit_signal("lives_changed", lives)
	emit_signal("score_changed", score)
	emit_signal("high_score_changed", high_score)
	emit_signal("enemies_changed", 0, 0)


func record_upgrade_pick(upgrade_id):
	upgrade_pick_counts[upgrade_id] = get_upgrade_pick_count(upgrade_id) + 1


func get_upgrade_pick_count(upgrade_id):
	return upgrade_pick_counts.get(upgrade_id, 0)


func lose_life():
	if is_game_over:
		return
	lives -= 1
	lives = max(lives, 0)
	emit_signal("lives_changed", lives)
	if lives <= 0:
		is_game_over = true
		_update_high_score()
		emit_signal("game_over")


func gain_life(amount = 1):
	if is_game_over:
		return
	lives = min(lives + amount, MAX_LIVES)
	emit_signal("lives_changed", lives)


func add_score(points):
	score += points
	emit_signal("score_changed", score)
	if score > high_score:
		high_score = score
		_save_high_score()
		emit_signal("high_score_changed", high_score)


func next_wave():
	current_wave += 1
	emit_signal("wave_changed", current_wave)


func set_enemies(alive, total):
	emit_signal("enemies_changed", alive, total)


func get_enemy_count_for_wave():
	if current_wave <= 0:
		return 0
	return 2 + current_wave 


func get_difficulty_tier():
	return int((current_wave - 1) / 5.0)


func _load_high_score():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		high_score = int(config.get_value("score", "high_score", 0))
	else:
		high_score = 0


func _update_high_score():
	if score <= high_score:
		return
	high_score = score
	_save_high_score()
	emit_signal("high_score_changed", high_score)


func _save_high_score():
	var config = ConfigFile.new()
	config.set_value("score", "high_score", high_score)
	config.save(SAVE_PATH)
