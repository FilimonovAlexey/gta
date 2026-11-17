class_name Pickup
extends Node2D
## Бонус на земле (хот-дог, пачка денег). Лежит в World — участвует в y-сортировке.
## position — точка на земле. Подбирает героиня кнопкой attack, стоя рядом
## на той же глубине (см. Player, поля «Подбор» в ActorStats).
##
## collect(): HEAL — лечит подобравшего, SCORE — очки через Events.pickup_collected
## (их начисляет Game). Картинка — PickupData.texture_path; пока её нет — цветной прямоугольник.
## Бонус слегка покачивается.

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
## Картинка бонуса (null — плейсхолдер).
var _texture: Texture2D


func _ready() -> void:
	add_to_group(GROUP)
	if data == null:
		push_error("%s: не задан data (PickupData)" % name)
		data = PickupData.new()
	if not data.texture_path.is_empty() and ResourceLoader.exists(data.texture_path):
		_texture = load(data.texture_path) as Texture2D


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
	if _texture != null:
		var k: float = data.sprite_height / float(_texture.get_height())
		var tex_size := Vector2(_texture.get_width(), _texture.get_height()) * k
		draw_texture_rect(_texture, Rect2(Vector2(-tex_size.x * 0.5, -tex_size.y - lift), tex_size), false)
		return
	var rect := Rect2(Vector2(-size.x * 0.5, -size.y - lift), size)
	draw_rect(rect.grow(2.0), OUTLINE_COLOR)
	draw_rect(rect, data.placeholder_color)
	# Блик, чтобы бонус отличался от предметов.
	draw_rect(Rect2(rect.position + Vector2(4.0, 3.0), Vector2(size.x * 0.35, 4.0)), Color(1.0, 1.0, 1.0, 0.6))
