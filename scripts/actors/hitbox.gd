class_name Hitbox
extends Area2D
## Область удара бойца. Включается только в активное окно атаки.
##
## Попадание засчитывается, если области Hitbox и Hurtbox пересеклись И
## разница глубины бойцов |dy| <= depth_tolerance. Каждую цель одна атака
## бьёт не больше одного раза: список задетых очищается при activate().
##
## Проверку вызывает сам Actor (collect_hits) в своём _physics_process —
## так порядок обработки однозначен. Маску слоёв задаёт Actor по команде.
## Ожидает дочерний CollisionShape2D «Shape»; форма создаётся своя на каждый
## экземпляр, чтобы бойцы не делили один RectangleShape2D.

## Допуск по глубине (разница position.y бойцов), px.
@export var depth_tolerance: float = 24.0

## Боец-владелец (родитель).
var actor: Actor
## Атака, для которой включён хитбокс (null — выключен).
var attack: AttackData

## Кого текущая атака уже задела.
var _hit_actors: Array[Actor] = []
var _rect_shape := RectangleShape2D.new()

@onready var _shape_node: CollisionShape2D = $Shape


## Прямоугольник RectangleShape2D узла в глобальных координатах (без учёта поворота и масштаба).
static func shape_global_rect(shape_node: CollisionShape2D) -> Rect2:
	var rect_shape := shape_node.shape as RectangleShape2D
	if rect_shape == null:
		return Rect2()
	return Rect2(shape_node.global_position - rect_shape.size * 0.5, rect_shape.size)


func _ready() -> void:
	actor = get_parent() as Actor
	monitoring = true
	monitorable = false
	collision_layer = 0
	_shape_node.shape = _rect_shape
	_shape_node.disabled = true


## Включить хитбокс под атаку. facing — направление взгляда бойца (1 / -1).
func activate(new_attack: AttackData, facing: int) -> void:
	attack = new_attack
	_hit_actors.clear()
	var rect: Rect2 = attack.hitbox_rect
	var left: float = rect.position.x if facing > 0 else -rect.end.x
	_rect_shape.size = rect.size
	_shape_node.position = Vector2(left, rect.position.y) + rect.size * 0.5
	_shape_node.disabled = false


## Выключить хитбокс.
func deactivate() -> void:
	attack = null
	_shape_node.disabled = true


func is_active() -> bool:
	return attack != null


## Новые цели в зоне удара: пересечение областей, допуск по глубине,
## цель уязвима и ещё не задета этой атакой. Найденные запоминаются.
func collect_hits() -> Array[Actor]:
	var result: Array[Actor] = []
	if attack == null:
		return result
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null:
			continue
		var target: Actor = hurtbox.actor
		if target == null or target == actor or _hit_actors.has(target):
			continue
		if absf(target.global_position.y - actor.global_position.y) > depth_tolerance:
			continue
		if not target.can_be_hit():
			continue
		_hit_actors.append(target)
		result.append(target)
	return result


## Зона удара в глобальных координатах (для отладочной отрисовки).
func get_global_rect() -> Rect2:
	return shape_global_rect(_shape_node)
