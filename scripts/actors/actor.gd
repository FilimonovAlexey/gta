class_name Actor
extends Node2D
## Базовый класс всех бойцов: героини, врагов и босса.
##
## position — точка на земле под ногами (x — вдоль улицы, y — глубина).
## Прыжок хранится отдельно в height; спрайт (Visual) смещается на -height,
## а тень (Shadow) остаётся на земле.
##
## Наследники переопределяют _update_behavior() (автомат состояний) и
## задают velocity — скорость по земле. Остальное делает базовый класс:
## движение с ограничением полосой улицы, гравитация, приземление, отрисовка.

## Испускается в момент касания земли после прыжка или падения.
signal landed

## Сколько вершин у эллипса тени.
const SHADOW_SEGMENTS: int = 24

## Параметры бойца.
@export var stats: ActorStats
## Цвет плейсхолдер-прямоугольника, пока нет арта.
@export var placeholder_color: Color = Color(0.5, 0.5, 0.5)

@export_group("Shadow")
## Полуоси эллипса тени на земле.
@export var shadow_radius: Vector2 = Vector2(38.0, 12.0)
## Непрозрачность тени, когда боец стоит на земле.
@export_range(0.0, 1.0) var shadow_alpha: float = 0.35
## Непрозрачность тени на высоте shadow_fade_height и выше.
@export_range(0.0, 1.0) var shadow_min_alpha: float = 0.15
## Масштаб тени на высоте shadow_fade_height и выше.
@export_range(0.1, 1.0) var shadow_min_scale: float = 0.6
## Высота, на которой тень уменьшается и бледнеет до минимума.
@export var shadow_fade_height: float = 180.0

## Высота над землёй (>= 0).
var height: float = 0.0
## Вертикальная скорость по height, px/с (вверх — положительная).
var vertical_velocity: float = 0.0
## Скорость по земле: x — вдоль улицы, y — вглубь, px/с.
var velocity: Vector2 = Vector2.ZERO
## Направление взгляда: 1 — вправо, -1 — влево.
var facing: int = 1:
	set(value):
		facing = 1 if value >= 0 else -1
## Прямоугольник, в котором может находиться position. Пустой — без ограничений.
var walk_bounds: Rect2 = Rect2()

@onready var shadow: Polygon2D = $Shadow
@onready var visual: Node2D = $Visual
@onready var body: ColorRect = $Visual/Body


func _ready() -> void:
	add_to_group("actors")
	if stats == null:
		push_error("%s: не задан stats (ActorStats)" % name)
		stats = ActorStats.new()
	body.color = placeholder_color
	shadow.polygon = _make_ellipse(shadow_radius)
	_update_visual()


func _physics_process(delta: float) -> void:
	_update_behavior(delta)
	_move_on_ground(delta)
	_apply_gravity(delta)
	_update_visual()


## Логика бойца (автомат состояний). Переопределяется наследниками.
func _update_behavior(_delta: float) -> void:
	pass


## Вызывается при приземлении. Переопределяется наследниками.
func _on_landed() -> void:
	pass


## Имя текущего состояния для отладочной подписи.
func get_state_name() -> String:
	return "NONE"


## В воздухе ли боец.
func is_airborne() -> bool:
	return height > 0.0 or vertical_velocity > 0.0


## Оттолкнуться от земли с силой прыжка из stats.
func start_jump() -> void:
	vertical_velocity = stats.jump_velocity


## Задать полосу улицы и сразу поставить бойца в её пределы.
func set_walk_bounds(bounds: Rect2) -> void:
	walk_bounds = bounds
	position = _clamp_to_bounds(position)


func _move_on_ground(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return
	position = _clamp_to_bounds(position + velocity * delta)


func _apply_gravity(delta: float) -> void:
	if not is_airborne():
		return
	vertical_velocity -= stats.gravity * delta
	height += vertical_velocity * delta
	if height <= 0.0:
		height = 0.0
		vertical_velocity = 0.0
		_on_landed()
		landed.emit()


func _clamp_to_bounds(point: Vector2) -> Vector2:
	if not walk_bounds.has_area():
		return point
	return point.clamp(walk_bounds.position, walk_bounds.end)


func _update_visual() -> void:
	visual.position.y = -height
	visual.scale.x = facing
	var t: float = clampf(height / shadow_fade_height, 0.0, 1.0)
	shadow.scale = Vector2.ONE * lerpf(1.0, shadow_min_scale, t)
	shadow.color = Color(0.0, 0.0, 0.0, lerpf(shadow_alpha, shadow_min_alpha, t))


func _make_ellipse(radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SHADOW_SEGMENTS:
		var angle: float = TAU * i / SHADOW_SEGMENTS
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
