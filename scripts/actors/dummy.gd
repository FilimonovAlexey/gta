class_name Dummy
extends Actor
## Тренировочный манекен: стоит на месте, получает удары, не атакует.
##
## После смерти прячется (а не удаляется), чтобы его можно было воскресить
## клавишей R в режиме отладки (сигнал Debug.revive_requested).

## Точка появления: сюда манекен возвращается при воскрешении.
var _spawn_position: Vector2


func _ready() -> void:
	super._ready()
	_spawn_position = position
	Debug.revive_requested.connect(_on_revive_requested)


func get_state_name() -> String:
	return "IDLE"


func _on_death_finished() -> void:
	visible = false
	set_physics_process(false)


func _on_revive_requested() -> void:
	revive(_spawn_position)
