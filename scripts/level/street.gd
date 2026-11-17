@tool
class_name Street
extends Node2D
## Уровень-улица: рисует фон (асфальт и тротуар) и задаёт полосу,
## по которой могут ходить бойцы.
##
## Ожидает дочерний узел World (y_sort_enabled) с бойцами. При запуске
## раздаёт каждому Actor в World границы ходьбы.
## @tool — чтобы фон был виден и в редакторе.

const ASPHALT_COLOR := Color(0.30, 0.31, 0.33)
const FACADE_COLORS: Array[Color] = [Color(0.38, 0.38, 0.40), Color(0.34, 0.35, 0.37)]
const SIDEWALK_COLOR := Color(0.56, 0.57, 0.58)
const SEAM_COLOR := Color(0.47, 0.48, 0.49)
const CURB_COLOR := Color(0.72, 0.72, 0.70)
const LANE_COLOR := Color(0.85, 0.80, 0.45)
## Ширина «фасада» в верхней части фона, px.
const FACADE_WIDTH: float = 320.0
## Шаг плиток тротуара, px.
const TILE_SIZE: float = 128.0

## Длина улицы, px.
@export var street_width: float = 2560.0:
	set(value):
		street_width = value
		queue_redraw()
## Высота фона, px.
@export var street_height: float = 720.0:
	set(value):
		street_height = value
		queue_redraw()
## Верхний край полосы ходьбы (дальний край тротуара).
@export var walk_top: float = 430.0:
	set(value):
		walk_top = value
		queue_redraw()
## Нижний край полосы ходьбы (ближний край тротуара).
@export var walk_bottom: float = 680.0:
	set(value):
		walk_bottom = value
		queue_redraw()
## Отступ от краёв улицы по x, за который бойцы не заходят.
@export var side_margin: float = 40.0


func _ready() -> void:
	queue_redraw()
	if Engine.is_editor_hint():
		return
	var world: Node = get_node_or_null("World")
	if world == null:
		push_error("Street: нет дочернего узла World")
		return
	var bounds: Rect2 = get_walk_bounds()
	for child in world.get_children():
		if child is Actor:
			(child as Actor).set_walk_bounds(bounds)


## Прямоугольник допустимых позиций бойцов (точек на земле).
func get_walk_bounds() -> Rect2:
	return Rect2(side_margin, walk_top, street_width - 2.0 * side_margin, walk_bottom - walk_top)


func _draw() -> void:
	# Асфальт на всю улицу.
	draw_rect(Rect2(0.0, 0.0, street_width, street_height), ASPHALT_COLOR)
	# Фасады над тротуаром — чтобы была видна прокрутка.
	var facade_count: int = ceili(street_width / FACADE_WIDTH)
	for i in facade_count:
		var color: Color = FACADE_COLORS[i % FACADE_COLORS.size()]
		draw_rect(Rect2(i * FACADE_WIDTH, 0.0, FACADE_WIDTH, walk_top - 40.0), color)
	# Тротуар с плиткой.
	draw_rect(Rect2(0.0, walk_top, street_width, walk_bottom - walk_top), SIDEWALK_COLOR)
	var x: float = TILE_SIZE
	while x < street_width:
		draw_line(Vector2(x, walk_top), Vector2(x, walk_bottom), SEAM_COLOR, 2.0)
		x += TILE_SIZE
	draw_line(Vector2(0.0, (walk_top + walk_bottom) * 0.5), Vector2(street_width, (walk_top + walk_bottom) * 0.5), SEAM_COLOR, 2.0)
	# Бордюр и разметка проезжей части.
	draw_rect(Rect2(0.0, walk_bottom, street_width, 8.0), CURB_COLOR)
	var lane_y: float = (walk_bottom + 8.0 + street_height) * 0.5
	x = 40.0
	while x < street_width:
		draw_line(Vector2(x, lane_y), Vector2(x + 60.0, lane_y), LANE_COLOR, 3.0)
		x += 160.0
