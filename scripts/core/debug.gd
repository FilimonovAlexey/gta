extends Node
## Autoload «Debug» — флаг отладочной отрисовки, переключается по F1
## (действие debug_toggle).
##
## Когда флаг включён, бойцы рисуют подписи состояний, хитбоксы, хёртбоксы
## и полосу глубины. Узлы читают Debug.enabled или подписываются на toggled.
## В режиме отладки R (действие debug_revive) воскрешает манекенов.
##
## class_name не задаётся намеренно: он конфликтовал бы с именем autoload.

## Испускается при переключении флага.
signal toggled(is_enabled: bool)
## Испускается по R в режиме отладки: манекены воскресают.
signal revive_requested

## Включена ли отладочная отрисовка.
var enabled: bool = false


func _ready() -> void:
	# Пользовательский аргумент --debug-draw включает отрисовку сразу (для автотестов).
	enabled = OS.get_cmdline_user_args().has("--debug-draw")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		enabled = not enabled
		toggled.emit(enabled)
		get_viewport().set_input_as_handled()
	elif enabled and event.is_action_pressed("debug_revive"):
		revive_requested.emit()
		get_viewport().set_input_as_handled()
