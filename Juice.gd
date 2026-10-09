extends Node

const FLOAT_TEXT_FONT = preload("res://assets/fonts/Orbitron-Bold.ttf")

var shake_strength = 0.0
var shake_time_left = 0.0
var shake_time_total = 0.0
var camera = null
var camera_base_offset = Vector2.ZERO
var slowmo_token = 0


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()


func _process(delta):
	if shake_time_left <= 0.0:
		if camera != null:
			camera.offset = camera_base_offset
		shake_strength = 0.0
		shake_time_total = 0.0
		return
	shake_time_left = max(0.0, shake_time_left - delta)
	var camera_node = _get_camera()
	if camera_node == null:
		return
	var fade = shake_time_left / max(shake_time_total, 0.001)
	var amount = shake_strength * fade * fade
	camera_node.offset = camera_base_offset + Vector2(randf_range(-amount, amount), randf_range(-amount, amount))
	if shake_time_left <= 0.0:
		camera_node.offset = camera_base_offset


func shake(strength = 8.0, duration = 0.16):
	var camera_node = _get_camera()
	if camera_node == null:
		return
	if shake_time_left <= 0.0:
		camera_base_offset = camera_node.offset
		shake_strength = strength
		shake_time_left = duration
		shake_time_total = duration
	else:
		shake_strength = max(shake_strength, strength)
		shake_time_left = max(shake_time_left, duration)
		shake_time_total = max(shake_time_total, duration)


func damage_number(world_position, amount, critical = false):
	var color = Color(1.0, 0.28, 0.16) if not critical else Color(1.0, 0.9, 0.25)
	var text = "-%d" % amount
	_spawn_float_text(world_position + Vector2(randf_range(-12.0, 12.0), -30.0), text, color, 18 if critical else 15)


func pickup_text(world_position, message, color):
	_spawn_float_text(world_position + Vector2(0, -42), message, color, 14)


func hit_spark(world_position, direction, color = Color(1.0, 0.82, 0.18)):
	var root = _make_effect_root(world_position)
	var burst = Polygon2D.new()
	burst.polygon = _circle_points(18, 8.0)
	burst.color = Color(color.r, color.g, color.b, 0.42)
	root.add_child(burst)
	var burst_tween = root.create_tween()
	burst_tween.tween_property(burst, "scale", Vector2.ONE * 2.5, 0.14)
	burst_tween.parallel().tween_property(burst, "modulate:a", 0.0, 0.14)
	var base_angle = direction.angle()
	if direction == Vector2.ZERO:
		base_angle = randf() * TAU
	for i in range(7):
		var shard = Polygon2D.new()
		var angle = base_angle + randf_range(-1.9, 1.9)
		shard.color = Color(color.r, color.g, color.b, 0.92)
		shard.polygon = PackedVector2Array([Vector2(7, 0), Vector2(-6, -2), Vector2(-8, 0), Vector2(-6, 2)])
		shard.rotation = angle
		root.add_child(shard)
		var tween = root.create_tween()
		tween.tween_property(shard, "position", Vector2.RIGHT.rotated(angle) * randf_range(20.0, 46.0), 0.18)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.18)
	_cleanup(root, 0.22)


func death_burst(world_position, color = Color(1.0, 0.1, 0.06)):
	var root = _make_effect_root(world_position)
	var ring = Polygon2D.new()
	ring.polygon = _circle_points(30, 13.0)
	ring.color = Color(color.r, color.g, color.b, 0.36)
	root.add_child(ring)
	var ring_tween = root.create_tween()
	ring_tween.tween_property(ring, "scale", Vector2.ONE * 3.1, 0.24)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
	for i in range(14):
		var particle = Polygon2D.new()
		var angle = TAU * float(i) / 14.0 + randf_range(-0.16, 0.16)
		particle.color = Color(color.r, color.g * randf_range(0.5, 1.0), color.b * randf_range(0.5, 1.0), 0.88)
		particle.polygon = PackedVector2Array([Vector2(4, 0), Vector2(-4, -3), Vector2(-6, 2)])
		particle.rotation = angle
		root.add_child(particle)
		var tween = root.create_tween()
		tween.tween_property(particle, "position", Vector2.RIGHT.rotated(angle) * randf_range(24.0, 62.0), randf_range(0.22, 0.34))
		tween.parallel().tween_property(particle, "scale", Vector2.ONE * randf_range(0.35, 0.7), 0.3)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
	_cleanup(root, 0.38)


func pickup_burst(world_position, color):
	var root = _make_effect_root(world_position)
	var ring = Polygon2D.new()
	ring.polygon = _circle_points(28, 12.0)
	ring.color = Color(color.r, color.g, color.b, 0.45)
	root.add_child(ring)
	var ring_tween = root.create_tween()
	ring_tween.tween_property(ring, "scale", Vector2.ONE * 2.7, 0.24)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.24)
	for i in range(10):
		var shard = Polygon2D.new()
		var angle = TAU * float(i) / 10.0
		shard.color = Color(color.r, color.g, color.b, 0.9)
		shard.polygon = PackedVector2Array([Vector2(6, 0), Vector2(-5, -2), Vector2(-5, 2)])
		shard.rotation = angle
		root.add_child(shard)
		var tween = root.create_tween()
		tween.tween_property(shard, "position", Vector2.RIGHT.rotated(angle) * randf_range(28.0, 52.0), 0.22)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.22)
	_cleanup(root, 0.28)


func final_kill_slowmo():
	slowmo_token += 1
	var current_token = slowmo_token
	Engine.time_scale = 0.35
	await get_tree().create_timer(0.18, true, false, true).timeout
	if current_token == slowmo_token:
		Engine.time_scale = 1.0


func reset_time_scale():
	slowmo_token += 1
	Engine.time_scale = 1.0


func _spawn_float_text(world_position, text, color, font_size):
	var label = Label.new()
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.global_position = world_position + Vector2(-70, 0)
	label.custom_minimum_size = Vector2(140, 28)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FLOAT_TEXT_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.z_index = 250
	_get_effect_parent().add_child(label)
	var drift = Vector2(randf_range(-8.0, 8.0), -36.0)
	var tween = label.create_tween()
	tween.tween_property(label, "position", label.position + drift, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "scale", Vector2.ONE * 1.15, 0.1)
	tween.chain().tween_property(label, "modulate:a", 0.0, 0.24)
	tween.tween_callback(Callable(label, "queue_free"))


func _make_effect_root(world_position):
	var root = Node2D.new()
	root.process_mode = Node.PROCESS_MODE_ALWAYS
	root.global_position = world_position
	root.z_index = 200
	_get_effect_parent().add_child(root)
	return root


func _circle_points(count, radius):
	var points = PackedVector2Array()
	for i in range(count):
		var angle = TAU * float(i) / float(count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)
	return points


func _cleanup(node, delay):
	var tween = node.create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(Callable(node, "queue_free"))


func _get_camera():
	var viewport_camera = get_viewport().get_camera_2d()
	if viewport_camera != null and viewport_camera != camera:
		camera = viewport_camera
		camera_base_offset = camera.offset
	return camera


func _get_effect_parent():
	var scene = get_tree().current_scene
	return scene if scene != null else get_tree().root
