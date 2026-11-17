class_name ActorHealthBar
extends Node2D
## Временная тонкая полоска здоровья над бойцом (до появления HUD).
##
## Должна быть дочерним узлом Actor; слушает его сигнал health_changed.
## Положение задаётся position узла (над головой).

const BACK_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const FULL_COLOR := Color(0.3, 0.9, 0.3)
const EMPTY_COLOR := Color(0.95, 0.2, 0.15)

## Размер полоски, px.
@export var bar_size: Vector2 = Vector2(64.0, 5.0)

## Доля оставшегося здоровья, 0..1.
var _ratio: float = 1.0


func _ready() -> void:
	var actor := get_parent() as Actor
	if actor == null:
		push_error("ActorHealthBar: родитель не Actor")
		return
	actor.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, maximum: int) -> void:
	_ratio = clampf(float(current) / float(maxi(maximum, 1)), 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var origin := Vector2(-bar_size.x * 0.5, 0.0)
	draw_rect(Rect2(origin - Vector2.ONE, bar_size + Vector2.ONE * 2.0), BACK_COLOR)
	if _ratio > 0.0:
		draw_rect(Rect2(origin, Vector2(bar_size.x * _ratio, bar_size.y)), EMPTY_COLOR.lerp(FULL_COLOR, _ratio))
