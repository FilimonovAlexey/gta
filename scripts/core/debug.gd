extends Node
## Autoload «Debug» — флаг отладочной отрисовки, переключается по F1
## (действие debug_toggle).
##
## Когда флаг включён, бойцы рисуют подписи состояний, хитбоксы, хёртбоксы
## и полосу глубины. Узлы читают Debug.enabled или подписываются на toggled.
##
## class_name не задаётся намеренно: он конфликтовал бы с именем autoload.

## Испускается при переключении флага.
signal toggled(is_enabled: bool)

## Включена ли отладочная отрисовка.
var enabled: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		enabled = not enabled
		toggled.emit(enabled)
		get_viewport().set_input_as_handled()
