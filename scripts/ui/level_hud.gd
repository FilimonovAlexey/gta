class_name LevelHud
extends CanvasLayer
## Надписи уровня поверх игры: мигающая стрелка «GO →» справа (замок снят —
## идти дальше) и баннер по центру (например, «BOSS — TODO» в арене босса).

## Полупериод мигания стрелки, с.
const GO_BLINK_PERIOD: float = 0.3
const GO_COLOR := Color(1.0, 0.85, 0.2)
const BANNER_COLOR := Color(1.0, 0.45, 0.7)
const OUTLINE_COLOR := Color(0.12, 0.04, 0.2)

var _go_label: Label
var _banner_label: Label
var _go_time: float = 0.0


func _ready() -> void:
	_go_label = _make_label("GO →", 64, GO_COLOR)
	_go_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_go_label.offset_left = -260.0
	_go_label.offset_right = -40.0
	_go_label.offset_top = -160.0
	_go_label.offset_bottom = -80.0
	_go_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_banner_label = _make_label("", 72, BANNER_COLOR)
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner_label.offset_left = -500.0
	_banner_label.offset_right = 500.0
	_banner_label.offset_top = 140.0
	_banner_label.offset_bottom = 240.0
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hide_go()
	hide_banner()


func _process(delta: float) -> void:
	if _go_label.visible or _go_time > 0.0:
		_go_time += delta
		_go_label.modulate.a = 1.0 if fmod(_go_time, GO_BLINK_PERIOD * 2.0) < GO_BLINK_PERIOD else 0.15


func show_go() -> void:
	_go_time = 0.0
	_go_label.visible = true


func hide_go() -> void:
	_go_time = 0.0
	_go_label.visible = false


func is_go_visible() -> bool:
	return _go_label.visible


func show_banner(text: String) -> void:
	_banner_label.text = text
	_banner_label.visible = true


func hide_banner() -> void:
	_banner_label.visible = false


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 12)
	add_child(label)
	return label
