class_name WaveData
extends Resource
## Волна врагов. Следующая волна сегмента выходит, когда все враги этой
## уже появились и живых на улице осталось не больше одного.

@export var spawns: Array[WaveSpawn] = []


## Время появления последнего врага волны, с.
func get_duration() -> float:
	var result: float = 0.0
	for spawn in spawns:
		result = maxf(result, spawn.delay)
	return result
