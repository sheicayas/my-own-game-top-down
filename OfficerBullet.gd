extends Area2D

var speed = 340.0
var direction = Vector2.RIGHT
var lifetime = 3.0
var pulse_time = 0.0

@onready var visual = $Visual


func _ready():
	body_entered.connect(_on_body_entered)
	rotation = direction.angle()


func _physics_process(delta):
	pulse_time += delta
	var pulse = 1.0 + sin(pulse_time * 22.0) * 0.12
	visual.scale = Vector2.ONE * 0.18 * pulse
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body):
	if body.is_in_group("player"):
		body.take_damage()
		Juice.hit_spark(global_position, direction, Color(1.0, 0.24, 0.05))
	queue_free()
