extends Node2D

const ARENA_MARGIN = 48.0
const WORLD_SIZE = Vector2(1848, 1048)

var arena_rect = Rect2()


func _ready():
	_apply_survival_tint()
	arena_rect = Rect2(
		ARENA_MARGIN, ARENA_MARGIN,
		WORLD_SIZE.x - ARENA_MARGIN * 2,
		WORLD_SIZE.y - ARENA_MARGIN * 2
	)


func get_arena_rect():
	return arena_rect


func _apply_survival_tint():
	var ground = get_node_or_null("Ground") as CanvasItem
	var decoration = get_node_or_null("Decoration") as CanvasItem
	if ground != null:
		ground.modulate = Color(0.66, 0.82, 0.86, 1.0)
	if decoration != null:
		decoration.modulate = Color(0.72, 0.78, 0.82, 1.0)
