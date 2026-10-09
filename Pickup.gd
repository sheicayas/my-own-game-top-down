extends Area2D

@export_enum("health", "armor", "bullet") var pickup_type = "health"


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("collect_pickup"):
		var pickup_message = str(body.collect_pickup(pickup_type))
		_spawn_collect_effect()
		_spawn_pickup_message(pickup_message)
		queue_free()


func _spawn_collect_effect():
	var color = _get_pickup_color()
	Juice.pickup_burst(global_position, color)
	Juice.shake(4.0, 0.09)


func _spawn_pickup_message(custom_message = ""):
	Juice.pickup_text(global_position, custom_message if custom_message != "" else _get_pickup_message(), _get_pickup_color())


func _get_pickup_message():
	match pickup_type:
		"health":
			return "HEALTH +1"
		"armor":
			return "ARMOR"
		"ammo":
			return "POWER BULLET"
		_:
			return "PICKUP"


func _get_pickup_color():
	match pickup_type:
		"health":
			return Color(1.0, 0.15, 0.22)
		"armor":
			return Color(0.35, 0.75, 1.0)
		"ammo":
			return Color(1.0, 0.86, 0.2)
		_:
			return Color(1, 1, 1)
