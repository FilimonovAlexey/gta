class_name StreetCamera
extends Camera2D
## Камера улицы: следит за целью только по x, y фиксирован.
## Сглаживание и границы задаются стандартными свойствами Camera2D
## (position_smoothing_*, limit_*).

## За кем следить.
@export var target: Node2D


## Видимая часть мира (в глобальных координатах) для вьюпорта viewport.
static func get_visible_world_rect(viewport: Viewport) -> Rect2:
	return viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()


func _ready() -> void:
	_follow()
	reset_smoothing()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if target != null:
		global_position.x = target.global_position.x
