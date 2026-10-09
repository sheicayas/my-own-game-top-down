extends CanvasLayer

signal start_requested()
signal pause_requested()
signal resume_requested()
signal exit_requested()
signal upgrade_selected(upgrade_id)

const PAUSE_CONTINUE = 0
const PAUSE_EXIT = 1
const PAUSE_SELECTED_FONT = preload("res://assets/fonts/Orbitron-Black.ttf")
const PAUSE_NORMAL_FONT = preload("res://assets/fonts/Orbitron-SemiBold.ttf")
const PAUSE_SELECTED_COLOR = Color(1.0, 0.86, 0.28, 1.0)
const PAUSE_NORMAL_COLOR = Color(0.82, 0.96, 1.0, 1.0)
const WAVE_MESSAGES = [
	"DON'T LET THEM CLOSE",
	"STAY ALIVE",
	"KILL THEM ALL",
	"HOLD YOUR GROUND",
	"LIGHT THEM UP"
]
const UPGRADE_POOL = [
	{"id": "heal",          "title": "HEALTH +2",      "desc": "Restore 2 HP",        "base_weight": 10, "max_picks": 0},
	{"id": "armor",         "title": "ARMOR",          "desc": "Block 1 hit",         "base_weight": 8,  "max_picks": 1},
	{"id": "fire_rate",     "title": "FIRE RATE",      "desc": "+1 bullet per shot",  "base_weight": 8,  "max_picks": 3},
	{"id": "bullet_damage", "title": "DAMAGE",         "desc": "Scales with wave",    "base_weight": 4,  "max_picks": 4},
	{"id": "lucky",         "title": "LUCKY",          "desc": "More enemy drops",    "base_weight": 6,  "max_picks": 1},
	{"id": "auto_fire",     "title": "AUTO FIRE",      "desc": "Hold to shoot",       "base_weight": 7,  "max_picks": 1},
	{"id": "blinding_light","title": "BLINDING LIGHT", "desc": "Slows enemies","base_weight": 6, "max_picks": 1},
]

var start_menu
var lives_label
var player_health_bar
var wave_label
var enemies_label
var score_label
var high_score_label
var hud_bar
var game_over_panel
var pause_menu
var upgrade_shop
var upgrade_buttons = []
var wave_clear_label
var continue_label
var exit_label
var start_warning_label
var wave_announce_label
var wave_message_label
var wave_announce_timer
var wave_sound
var menu_focus_sound
var menu_select_sound
var final_score_label
var selected_pause_option = PAUSE_CONTINUE
var player_ref = null


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cache_nodes()
	set_process_input(true)
	GameManager.lives_changed.connect(_on_lives_changed)
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.high_score_changed.connect(_on_high_score_changed)
	GameManager.wave_changed.connect(_on_wave_changed)
	GameManager.enemies_changed.connect(_on_enemies_changed)
	GameManager.game_over.connect(_on_game_over)
	_refresh_lives()
	_refresh_score()
	_refresh_high_score()
	_on_enemies_changed(0, 0)


func _cache_nodes():
	start_menu = get_node_or_null("StartMenu")
	lives_label = _get_first_node(["HUDBar/HealthGroup/LivesLabel", "HUDBar/HealthGroup/HPLabel"])
	player_health_bar = get_node_or_null("HUDBar/HealthGroup/PlayerHealthBar")
	wave_label = get_node_or_null("HUDBar/StatsGroup/WaveLabel")
	enemies_label = get_node_or_null("HUDBar/StatsGroup/EnemiesLabel")
	score_label = get_node_or_null("HUDBar/StatsGroup/ScoreLabel")
	high_score_label = get_node_or_null("HUDBar/StatsGroup/HighScoreLabel")
	hud_bar = get_node_or_null("HUDBar")
	game_over_panel = get_node_or_null("GameOverPanel")
	pause_menu = get_node_or_null("PauseMenu")
	wave_clear_label = get_node_or_null("WaveClearLabel")
	upgrade_shop = get_node_or_null("UpgradeShop")
	_cache_upgrade_buttons()
	continue_label = get_node_or_null("PauseMenu/ContinueLabel")
	exit_label = get_node_or_null("PauseMenu/ExitLabel")
	start_warning_label = get_node_or_null("StartWarningLabel")
	wave_announce_label = get_node_or_null("WaveAnnounceLabel")
	wave_message_label = get_node_or_null("WaveMessageLabel")
	wave_announce_timer = get_node_or_null("WaveAnnounceTimer")
	wave_sound = get_node_or_null("WaveSound")
	menu_focus_sound = get_node_or_null("MenuFocusSound")
	menu_select_sound = get_node_or_null("MenuSelectSound")
	final_score_label = get_node_or_null("GameOverPanel/FinalScoreLabel")
	_set_sound_loop_enabled(wave_sound, false)


func _cache_upgrade_buttons():
	upgrade_buttons.clear()
	for path in [
		"UpgradeShop/ShopPanel/UpgradeRow/UpgradeButton1",
		"UpgradeShop/ShopPanel/UpgradeRow/UpgradeButton2",
		"UpgradeShop/ShopPanel/UpgradeRow/UpgradeButton3"
	]:
		var button = get_node_or_null(path)
		if button == null:
			continue
		upgrade_buttons.append(button)
		if not button.mouse_entered.is_connected(_on_upgrade_button_focused):
			button.mouse_entered.connect(_on_upgrade_button_focused)
		if not button.focus_entered.is_connected(_on_upgrade_button_focused):
			button.focus_entered.connect(_on_upgrade_button_focused)
		if not button.pressed.is_connected(_on_upgrade_button_pressed.bind(button)):
			button.pressed.connect(_on_upgrade_button_pressed.bind(button))


func _get_first_node(paths):
	for path in paths:
		var node = get_node_or_null(path)
		if node != null:
			return node
	return null


func show_start_menu():
	if start_menu != null:
		start_menu.visible = true
	if hud_bar != null:
		hud_bar.visible = false
	if pause_menu != null:
		pause_menu.visible = false
	if upgrade_shop != null:
		upgrade_shop.visible = false
	if game_over_panel != null:
		game_over_panel.visible = false
	if start_warning_label != null:
		start_warning_label.visible = false
	if wave_announce_label != null:
		wave_announce_label.visible = false
	if wave_message_label != null:
		wave_message_label.visible = false
	if wave_clear_label != null:
		wave_clear_label.visible = false


func show_game_hud():
	if start_menu != null:
		start_menu.visible = false
	if hud_bar != null:
		hud_bar.visible = true
	if pause_menu != null:
		pause_menu.visible = false
	if upgrade_shop != null:
		upgrade_shop.visible = false
	if wave_clear_label != null:
		wave_clear_label.visible = false


func show_start_warning(message = "BE READY!"):
	if start_warning_label == null:
		return
	start_warning_label.text = message
	start_warning_label.visible = true
	start_warning_label.modulate = Color(1, 1, 1, 1)
	var tween = start_warning_label.create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(start_warning_label, "modulate:a", 0.0, 0.3)
	tween.tween_callback(Callable(start_warning_label, "hide"))


func show_pause_menu():
	if pause_menu != null:
		pause_menu.visible = true
	_select_pause_option(PAUSE_CONTINUE)


func hide_pause_menu():
	if pause_menu != null:
		pause_menu.visible = false


func show_upgrade_shop():
	if upgrade_shop == null:
		return
	var options = _get_random_upgrade_options()
	for i in range(upgrade_buttons.size()):
		var button = upgrade_buttons[i]
		if i >= options.size():
			button.visible = false
			continue
		var option = options[i]
		button.visible = true
		button.text = "%s\n%s" % [str(option["title"]), str(option["desc"])]
		button.set_meta("upgrade_id", str(option["id"]))
	upgrade_shop.visible = true
	upgrade_shop.modulate = Color(1, 1, 1, 0)
	var tween = upgrade_shop.create_tween()
	tween.tween_property(upgrade_shop, "modulate:a", 1.0, 0.18)


func hide_upgrade_shop():
	if upgrade_shop != null:
		upgrade_shop.visible = false


func is_upgrade_shop_visible():
	return upgrade_shop != null and upgrade_shop.visible


func show_wave_clear_message(wave_num):
	if wave_clear_label == null:
		return
	wave_clear_label.text = "WAVE %d COMPLETE" % wave_num
	wave_clear_label.visible = true
	wave_clear_label.modulate = Color(1, 1, 1, 1)
	wave_clear_label.scale = Vector2.ONE * 0.9
	var tween = wave_clear_label.create_tween()
	tween.tween_property(wave_clear_label, "scale", Vector2.ONE, 0.12)
	tween.tween_interval(1.0)
	tween.tween_property(wave_clear_label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(Callable(wave_clear_label, "hide"))


func _input(event):
	if upgrade_shop != null and upgrade_shop.visible:
		return
	if pause_menu == null or not pause_menu.visible:
		return
	if event is InputEventMouseMotion:
		_update_pause_hover_selection()
		return
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			var hovered_option = _get_pause_option_at_mouse()
			if hovered_option != -1:
				_select_pause_option(hovered_option)
				_activate_pause_option()
		return
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return
		match key_event.keycode:
			KEY_UP, KEY_W:
				_select_pause_option(PAUSE_CONTINUE)
				get_viewport().set_input_as_handled()
			KEY_DOWN, KEY_S:
				_select_pause_option(PAUSE_EXIT)
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_activate_pause_option()
				get_viewport().set_input_as_handled()


func _update_pause_hover_selection():
	var hovered_option = _get_pause_option_at_mouse()
	if hovered_option != -1:
		_select_pause_option(hovered_option)


func _get_pause_option_at_mouse():
	var mouse_position = get_viewport().get_mouse_position()
	if continue_label != null and continue_label.get_global_rect().has_point(mouse_position):
		return PAUSE_CONTINUE
	if exit_label != null and exit_label.get_global_rect().has_point(mouse_position):
		return PAUSE_EXIT
	return -1


func _select_pause_option(option):
	var changed = selected_pause_option != option
	selected_pause_option = option
	_apply_pause_label_style(continue_label, option == PAUSE_CONTINUE)
	_apply_pause_label_style(exit_label, option == PAUSE_EXIT)
	if changed and pause_menu != null and pause_menu.visible:
		_play_sound(menu_focus_sound)


func _apply_pause_label_style(label, is_selected):
	if label == null:
		return
	label.add_theme_font_override("font", PAUSE_SELECTED_FONT if is_selected else PAUSE_NORMAL_FONT)
	label.add_theme_color_override("font_color", PAUSE_SELECTED_COLOR if is_selected else PAUSE_NORMAL_COLOR)
	label.add_theme_font_size_override("font_size", 34 if is_selected else 30)
	if label == continue_label:
		label.text = " CONTINUE " if is_selected else "CONTINUE"
	else:
		label.text = " EXIT " if is_selected else "EXIT"


func _activate_pause_option():
	_play_sound(menu_select_sound)
	if selected_pause_option == PAUSE_CONTINUE:
		resume_requested.emit()
	else:
		exit_requested.emit()


func _get_random_upgrade_options():
	var candidates = []
	var hp_ratio = float(GameManager.lives) / float(GameManager.MAX_LIVES)

	for entry in UPGRADE_POOL:
		var id = entry["id"]
		var picks = GameManager.get_upgrade_pick_count(id)
		var max_p = entry["max_picks"]

		if max_p > 0 and picks >= max_p:
			continue

		if id == "armor" and player_ref != null and player_ref.get("has_armor") == true:
			continue

		var weight = float(entry["base_weight"])

		for _i in range(picks):
			weight *= 0.5

		if id == "heal":
			if hp_ratio <= 0.3:
				weight *= 3.5
			elif hp_ratio <= 0.5:
				weight *= 2.0
			elif hp_ratio >= 0.9:
				weight *= 0.4

		if id == "armor" and hp_ratio < 0.8:
			weight *= 1.6

		if id == "fire_rate" and player_ref != null:
			var shots = player_ref.get("bonus_shot_count")
			if shots >= 3:
				continue
			weight *= max(1.0 - float(shots) * 0.25, 0.25)

		if id == "bullet_damage" and player_ref != null:
			var dmg = player_ref.get("bonus_bullet_damage")
			weight *= max(1.0 - float(dmg) * 0.1, 0.2)

		candidates.append({"entry": entry, "weight": weight})

	if candidates.is_empty():
		for entry in UPGRADE_POOL:
			candidates.append({"entry": entry, "weight": 1.0})

	var chosen = []
	var remaining = candidates.duplicate()

	for _pick in range(min(3, remaining.size())):
		var total_weight = 0.0
		for c in remaining:
			total_weight += c["weight"]
		var roll = randf() * total_weight
		var running = 0.0
		var chosen_index = 0
		for i in range(remaining.size()):
			running += remaining[i]["weight"]
			if roll <= running:
				chosen_index = i
				break
		chosen.append(remaining[chosen_index]["entry"])
		remaining.remove_at(chosen_index)

	return chosen


func _on_upgrade_button_pressed(button):
	_play_sound(menu_select_sound)
	hide_upgrade_shop()
	var upgrade_id = str(button.get_meta("upgrade_id", ""))
	GameManager.record_upgrade_pick(upgrade_id)
	upgrade_selected.emit(upgrade_id)


func _on_upgrade_button_focused():
	_play_sound(menu_focus_sound)


func _refresh_lives():
	if lives_label != null:
		lives_label.text = "HP"
	if player_health_bar != null:
		player_health_bar.max_value = GameManager.MAX_LIVES
		player_health_bar.value = GameManager.lives


func _refresh_score():
	if score_label != null:
		score_label.text = "SCORE %d" % GameManager.score


func _refresh_high_score():
	if high_score_label != null:
		high_score_label.text = " HIGH SCORE %d " % GameManager.high_score


func show_wave_announce(wave_num):
	if wave_announce_label != null:
		wave_announce_label.text = "WAVE %d" % wave_num
		wave_announce_label.visible = true
	if wave_message_label != null:
		var message_index = (wave_num - 1) % WAVE_MESSAGES.size()
		wave_message_label.text = WAVE_MESSAGES[message_index]
		wave_message_label.visible = true
		wave_message_label.modulate = Color(1, 1, 1, 1)
	if wave_announce_timer != null:
		wave_announce_timer.start(2.5)
	if wave_announce_label != null and wave_announce_label.visible:
		_play_sound(wave_sound)


func _on_lives_changed(_new_lives):
	_refresh_lives()


func _on_score_changed(_new_score):
	_refresh_score()


func _on_high_score_changed(_new_high_score):
	_refresh_high_score()


func _on_wave_changed(new_wave):
	if wave_label != null:
		wave_label.text = "WAVE %d" % new_wave
	show_wave_announce(new_wave)


func _on_enemies_changed(alive, total):
	if enemies_label != null:
		enemies_label.text = "ENEMIES %d / %d" % [alive, total]


func _on_game_over():
	hide_pause_menu()
	hide_upgrade_shop()
	if final_score_label != null:
		final_score_label.text = "Final Score: %d\nHigh Score: %d" % [GameManager.score, GameManager.high_score]
	if game_over_panel != null:
		game_over_panel.visible = true


func _on_wave_announce_timer_timeout():
	if wave_announce_label != null:
		wave_announce_label.visible = false
	if wave_message_label != null:
		wave_message_label.visible = false
	if wave_sound != null:
		wave_sound.stop()


func _on_start_button_pressed():
	_play_sound(menu_select_sound)
	start_requested.emit()


func _on_pause_button_pressed():
	pause_requested.emit()


func _on_continue_button_pressed():
	_play_sound(menu_select_sound)
	resume_requested.emit()


func _play_sound(sound):
	if sound == null:
		return
	sound.stop()
	sound.play()


func _set_sound_loop_enabled(sound, loop_enabled):
	if sound == null or sound.stream == null:
		return
	if sound.stream is AudioStreamMP3:
		var mp3_stream = sound.stream as AudioStreamMP3
		mp3_stream.loop = loop_enabled
	elif sound.stream is AudioStreamOggVorbis:
		var ogg_stream = sound.stream as AudioStreamOggVorbis
		ogg_stream.loop = loop_enabled
	elif sound.stream is AudioStreamWAV:
		var wav_stream = sound.stream as AudioStreamWAV
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop_enabled else AudioStreamWAV.LOOP_DISABLED
