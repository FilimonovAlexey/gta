class_name StreetDebugOverlay
extends Node2D
## Отладочная отрисовка поверх уровня (включается F1, см. autoload Debug):
## линии walk_top / walk_bottom, точка на земле под каждым бойцом,
## линия до спрайта в прыжке, подпись состояния и height.

const BOUNDS_COLOR := Color(1.0, 0.9, 0.2, 0.9)
const GROUND_COLOR := Color(1.0, 0.2, 0.2)
const HEIGHT_COLOR := Color(1.0, 0.2, 0.2, 0.6)
const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0)
const FONT_SIZE: int = 16
const LABEL_WIDTH: float = 160.0
## На сколько выше точки опоры спрайта рисовать подпись (рост ~180 px).
const LABEL_OFFSET: float = 200.0

## Улица, чьи границы рисовать.
@export var street: Street


func _ready() -> void:
	Debug.toggled.connect(_on_debug_toggled)
	visible = Debug.enabled


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _on_debug_toggled(is_enabled: bool) -> void:
	visible = is_enabled
	queue_redraw()


func _draw() -> void:
	if street != null:
		var top: float = to_local(street.to_global(Vector2(0.0, street.walk_top))).y
		var bottom: float = to_local(street.to_global(Vector2(0.0, street.walk_bottom))).y
		draw_line(Vector2(0.0, top), Vector2(street.street_width, top), BOUNDS_COLOR, 2.0)
		draw_line(Vector2(0.0, bottom), Vector2(street.street_width, bottom), BOUNDS_COLOR, 2.0)

	var font: Font = ThemeDB.fallback_font
	for node in get_tree().get_nodes_in_group("actors"):
		var actor := node as Actor
		if actor == null:
			continue
		var ground: Vector2 = to_local(actor.global_position)
		if actor.height > 0.0:
			draw_line(ground, ground - Vector2(0.0, actor.height), HEIGHT_COLOR, 2.0)
		draw_circle(ground, 5.0, GROUND_COLOR)
		var label_pos: Vector2 = ground + Vector2(-LABEL_WIDTH * 0.5, -actor.height - LABEL_OFFSET)
		_draw_label(font, label_pos, actor.get_state_name())
		_draw_label(font, label_pos + Vector2(0.0, FONT_SIZE + 2.0), "h=%d" % roundi(actor.height))


func _draw_label(font: Font, pos: Vector2, text: String) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, FONT_SIZE, 4, OUTLINE_COLOR)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, FONT_SIZE, TEXT_COLOR)
