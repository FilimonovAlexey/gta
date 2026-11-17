class_name StreetCamera
extends Camera2D
## Камера улицы: следит за целью только по x, y фиксирован.
## Сглаживание и границы задаются стандартными свойствами Camera2D
## (position_smoothing_*, limit_*).

## За кем следить.
@export var target: Node2D


func _ready() -> void:
	_follow()
	reset_smoothing()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if target != null:
		global_position.x = target.global_position.x
