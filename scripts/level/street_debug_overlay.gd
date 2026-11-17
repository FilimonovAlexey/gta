class_name StreetDebugOverlay
extends Node2D
## Отладочная отрисовка поверх уровня (включается F1, см. autoload Debug):
## линии walk_top / walk_bottom, точка на земле под каждым бойцом,
## линия до спрайта в прыжке, хёртбоксы (зелёные), хитбоксы в активное окно
## (красные), полоса допуска по глубине под бойцом, подпись состояния, height и HP.

const BOUNDS_COLOR := Color(1.0, 0.9, 0.2, 0.9)
const GROUND_COLOR := Color(1.0, 0.2, 0.2)
const HEIGHT_COLOR := Color(1.0, 0.2, 0.2, 0.6)
const HURTBOX_COLOR := Color(0.2, 1.0, 0.3)
const HITBOX_COLOR := Color(1.0, 0.15, 0.15)
const DEPTH_COLOR := Color(0.3, 0.7, 1.0)
const TEXT_COLOR := Color(1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0)
const FONT_SIZE: int = 16
const LABEL_WIDTH: float = 220.0
## На сколько выше точки опоры спрайта рисовать подпись (рост ~180 px).
const LABEL_OFFSET: float = 236.0

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
		if actor == null or not actor.is_visible_in_tree():
			continue
		var ground: Vector2 = to_local(actor.global_position)
		_draw_depth_strip(actor, ground)
		_draw_box(actor.hurtbox.get_global_rect(), HURTBOX_COLOR)
		if actor.hitbox.is_active():
			_draw_box(actor.hitbox.get_global_rect(), HITBOX_COLOR)
		if actor.height > 0.0:
			draw_line(ground, ground - Vector2(0.0, actor.height), HEIGHT_COLOR, 2.0)
		draw_circle(ground, 5.0, GROUND_COLOR)
		var label_pos: Vector2 = ground + Vector2(-LABEL_WIDTH * 0.5, -actor.height - LABEL_OFFSET)
		var line_step := Vector2(0.0, FONT_SIZE + 2.0)
		_draw_label(font, label_pos, actor.get_display_state())
		_draw_label(font, label_pos + line_step, "h=%d  hp=%d" % [roundi(actor.height), actor.health])


## Полоса под бойцом: глубины, в пределах которых его удары засчитываются.
func _draw_depth_strip(actor: Actor, ground: Vector2) -> void:
	var tolerance: float = actor.hitbox.depth_tolerance
	var half_width: float = actor.shadow_radius.x
	var rect := Rect2(ground.x - half_width, ground.y - tolerance, half_width * 2.0, tolerance * 2.0)
	draw_rect(rect, Color(DEPTH_COLOR, 0.2))
	draw_rect(rect, Color(DEPTH_COLOR, 0.8), false, 1.0)


func _draw_box(global_rect: Rect2, color: Color) -> void:
	if not global_rect.has_area():
		return
	var rect := Rect2(to_local(global_rect.position), global_rect.size)
	draw_rect(rect, Color(color, 0.18))
	draw_rect(rect, color, false, 2.0)


func _draw_label(font: Font, pos: Vector2, text: String) -> void:
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, FONT_SIZE, 4, OUTLINE_COLOR)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, FONT_SIZE, TEXT_COLOR)
