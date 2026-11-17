extends Node
## Autoload «Game» — состояние текущего забега: очки, жизни.
##
## Здесь будет: начальные значения из data/*.tres, сброс при новой игре,
## начисление очков и потеря жизней с оповещением через Events.
## В режиме --autoplay сохранения не пишутся.
##
## class_name не задаётся намеренно: он конфликтовал бы с именем autoload.

## Текущие очки.
var score: int = 0
## Оставшиеся жизни героини.
var lives: int = 3


func _ready() -> void:
	Events.enemy_defeated.connect(_on_enemy_defeated)


func _on_enemy_defeated(points: int) -> void:
	score += points
