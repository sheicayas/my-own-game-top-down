extends Node2D

@onready var player = $Player
@onready var wave_manager = $WaveManager
@onready var hud = $HUD
@onready var background_music = $BackgroundMusic
@onready var game_over_sound = $GameOverSound

var has_started = false
var is_paused_from_menu = false


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_set_gameplay_process_mode()
	wave_manager.wave_cleared.connect(_on_wave_cleared)
	GameManager.game_over.connect(_on_game_over)
	background_music.finished.connect(_on_background_music_finished)
	hud.start_requested.connect(_on_start_requested)
	hud.pause_requested.connect(_on_pause_requested)
	hud.resume_requested.connect(_on_resume_requested)
	hud.exit_requested.connect(_on_exit_requested)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	_set_music_loop_enabled()
	get_tree().paused = true


func _on_wave_cleared(_wave_num):
	if GameManager.is_game_over:
		return
	get_tree().paused = true
	if hud.has_method("show_wave_clear_message"):
		hud.call("show_wave_clear_message", _wave_num)
	await get_tree().create_timer(1.45, true).timeout
	if GameManager.is_game_over:
		return
	if hud.has_method("show_upgrade_shop"):
		hud.call("show_upgrade_shop")


func _on_upgrade_selected(upgrade_id):
	get_tree().paused = false
	if player.has_method("apply_wave_upgrade"):
		player.call("apply_wave_upgrade", upgrade_id)
	if wave_manager.has_method("start_next_wave_after_upgrade"):
		wave_manager.call("start_next_wave_after_upgrade")


func _input(event):
	if event.is_action_pressed("restart"):
		if GameManager.is_game_over:
			get_tree().paused = false
			get_tree().reload_current_scene()
	if hud.has_method("is_upgrade_shop_visible") and hud.call("is_upgrade_shop_visible"):
		return
	if _is_pause_input(event) and has_started and not GameManager.is_game_over:
		if is_paused_from_menu:
			_resume_game()
		else:
			_pause_game()


func _is_pause_input(event):
	if event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey:
		var key_event = event as InputEventKey
		return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE
	return false


func _on_start_requested():
	if has_started:
		return
	has_started = true
	is_paused_from_menu = false
	get_tree().paused = false
	hud.show_game_hud()
	hud.player_ref = player
	background_music.play()
	if hud.has_method("show_start_warning"):
		hud.call("show_start_warning", "BE READY")
	await get_tree().create_timer(1.7, false).timeout
	if GameManager.is_game_over:
		return
	wave_manager.start_game(player)


func _on_pause_requested():
	if has_started and not GameManager.is_game_over:
		_pause_game()


func _on_resume_requested():
	_resume_game()


func _on_exit_requested():
	get_tree().quit()


func _pause_game():
	is_paused_from_menu = true
	hud.show_pause_menu()
	background_music.stream_paused = true
	get_tree().paused = true


func _resume_game():
	is_paused_from_menu = false
	hud.hide_pause_menu()
	get_tree().paused = false
	background_music.stream_paused = false


func _set_gameplay_process_mode():
	$Level.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	wave_manager.process_mode = Node.PROCESS_MODE_PAUSABLE


func _on_game_over():
	is_paused_from_menu = false
	get_tree().paused = false
	background_music.stop()
	game_over_sound.play()


func _set_music_loop_enabled():
	if background_music.stream is AudioStreamMP3:
		var mp3_stream = background_music.stream as AudioStreamMP3
		mp3_stream.loop = true
	elif background_music.stream is AudioStreamOggVorbis:
		var ogg_stream = background_music.stream as AudioStreamOggVorbis
		ogg_stream.loop = true
	elif background_music.stream is AudioStreamWAV:
		var wav_stream = background_music.stream as AudioStreamWAV
		wav_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD


func _on_background_music_finished():
	if not GameManager.is_game_over:
		background_music.play()
