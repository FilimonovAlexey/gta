class_name Pickup
extends Node2D
## Бонус на земле (хот-дог, пачка денег). Лежит в World — участвует в y-сортировке.
## position — точка на земле. Подбирает героиня кнопкой attack, стоя рядом
## на той же глубине (см. Player, поля «Подбор» в ActorStats).
##
## collect(): HEAL — лечит подобравшего, SCORE — очки через Events.pickup_collected
## (их начисляет Game). Пока нет арта — цветной прямоугольник, слегка покачивается.

const GROUP: StringName = &"pickups"
## Покачивание над землёй: размах, px, и частота, рад/с.
const BOB_AMPLITUDE: float = 4.0
const BOB_SPEED: float = 5.0
## Подлёт при появлении (выпал из предмета): начальная высота, px, и время, с.
const POP_HEIGHT: float = 60.0
const POP_TIME: float = 0.3
const SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.3)
const OUTLINE_COLOR := Color(0.1, 0.05, 0.1, 0.9)

## Тип бонуса. Задаётся до добавления в дерево.
@export var data: PickupData

var _time: float = 0.0
var _collected: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		push_error("%s: не задан data (PickupData)" % name)
		data = PickupData.new()


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## Можно ли подобрать (ещё не подобран).
func is_available() -> bool:
	return not _collected


## Подобрать бонус бойцом collector.
func collect(collector: Actor) -> void:
	if _collected:
		return
	_collected = true
	if data.kind == PickupData.Kind.HEAL:
		collector.heal(data.amount)
		print("Подобран %s: +%d HP" % [data.display_name, data.amount])
	else:
		print("Подобран %s: +%d очков" % [data.display_name, data.amount])
	Events.pickup_collected.emit(data, collector)
	queue_free()


func _draw() -> void:
	var size: Vector2 = data.size
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, size.x * 0.6, SHADOW_COLOR)
	draw_set_transform(Vector2.ZERO)
	var lift: float = 4.0 + BOB_AMPLITUDE * (0.5 + 0.5 * sin(_time * BOB_SPEED))
	if _time < POP_TIME:
		var t: float = _time / POP_TIME
		lift += POP_HEIGHT * 4.0 * t * (1.0 - t)
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y - lift), size)
	draw_rect(rect.grow(2.0), OUTLINE_COLOR)
	draw_rect(rect, data.placeholder_color)
	# Блик, чтобы бонус отличался от предметов.
	draw_rect(Rect2(rect.position + Vector2(4.0, 3.0), Vector2(size.x * 0.35, 4.0)), Color(1.0, 1.0, 1.0, 0.6))
