class_name Hurtbox
extends Area2D
## Область тела бойца, по которой можно попасть.
##
## Сама ничего не ищет: попадания проверяет Hitbox атакующего (пересечение
## областей + разница глубины). Слой задаёт Actor по своей команде.
## Ожидает дочерний CollisionShape2D «Shape» с RectangleShape2D.

## Боец-владелец (родитель).
var actor: Actor

@onready var _shape_node: CollisionShape2D = $Shape


func _ready() -> void:
	actor = get_parent() as Actor
	monitoring = false
	monitorable = true
	collision_mask = 0


## Прямоугольник тела в глобальных координатах (для отладочной отрисовки).
func get_global_rect() -> Rect2:
	return Hitbox.shape_global_rect(_shape_node)
