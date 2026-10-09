extends Area2D

var speed = 600.0
var damage = 1
var power_level = 1
var direction = Vector2.RIGHT
var pierce_count = 0
var lifetime = 2.0
var pulse_time = 0.0

const POWER_TEXTURES = [
	preload("res://assets/laser_bullet/13.png"),
	preload("res://assets/laser_bullet/25.png"),
	preload("res://assets/laser_bullet/26.png"),
	preload("res://assets/laser_bullet/28.png")
]

@onready var visual = $Visual


func _ready():
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()
	_apply_power_visual()


func _apply_power_visual():
	var level = max(power_level, 1)
	speed = 600.0 + float(level - 1) * 120.0
	visual.texture = POWER_TEXTURES[clamp(level - 1, 0, POWER_TEXTURES.size() - 1)]
	visual.scale = Vector2.ONE * (0.18 + float(level - 1) * 0.035)


func _physics_process(delta):
	pulse_time += delta
	var pulse = 1.0 + sin(pulse_time * 28.0) * 0.12
	visual.scale = Vector2.ONE * (0.18 + float(max(power_level, 1) - 1) * 0.035) * pulse
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body):
	if body.is_in_group("enemy"):
		body.take_damage(damage)
		Juice.hit_spark(global_position, direction, _get_hit_color())
		Juice.shake(2.5 + float(power_level) * 0.8, 0.08)
		if pierce_count > 0:
			pierce_count -= 1
			return
	queue_free()


func _get_hit_color():
	if power_level >= 4:
		return Color(0.15, 0.75, 1.0)
	if power_level >= 3:
		return Color(1.0, 0.15, 0.75)
	if power_level >= 2:
		return Color(0.35, 0.55, 1.0)
	return Color(1.0, 0.82, 0.18)
