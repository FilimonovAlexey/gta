extends Node
## Autoload «Debug» — флаг отладочной отрисовки, переключается по F1
## (действие debug_toggle).
##
## Когда флаг включён, бойцы рисуют подписи состояний, хитбоксы, хёртбоксы
## и полосу глубины. Узлы читают Debug.enabled или подписываются на toggled.
## В режиме отладки: R (debug_revive) воскрешает героиню, G (debug_god_mode) —
## бессмертие героини, 1/2/3 (debug_spawn_1..3) — спавн врага соответствующего
## типа (список типов — у EnemySpawner уровня).
## Пользовательские аргументы: --debug-draw (отрисовка сразу), --god-mode (бессмертие сразу).
##
## class_name не задаётся намеренно: он конфликтовал бы с именем autoload.

## Испускается при переключении флага.
signal toggled(is_enabled: bool)
## Испускается по R в режиме отладки: героиня воскресает.
signal revive_requested
## Бессмертие героини включено или выключено.
signal god_mode_changed(is_on: bool)
## Запрошен спавн врага с индексом index (0 — клавиша 1).
signal spawn_requested(index: int)

## Действия спавна по порядку индексов.
const SPAWN_ACTIONS: Array[StringName] = [&"debug_spawn_1", &"debug_spawn_2", &"debug_spawn_3"]

## Включена ли отладочная отрисовка.
var enabled: bool = false
## Бессмертие героини.
var god_mode: bool = false


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	enabled = args.has("--debug-draw")
	god_mode = args.has("--god-mode")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		enabled = not enabled
		toggled.emit(enabled)
		get_viewport().set_input_as_handled()
	elif not enabled:
		return
	elif event.is_action_pressed("debug_revive"):
		revive_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("debug_god_mode"):
		god_mode = not god_mode
		print("Бессмертие героини: ", "вкл" if god_mode else "выкл")
		god_mode_changed.emit(god_mode)
		get_viewport().set_input_as_handled()
	else:
		for i in SPAWN_ACTIONS.size():
			if event.is_action_pressed(SPAWN_ACTIONS[i]):
				spawn_requested.emit(i)
				get_viewport().set_input_as_handled()
				return
