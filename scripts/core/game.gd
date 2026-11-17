extends Node
## Autoload «Game» — состояние текущего забега: очки, жизни, текущий уровень.
##
## Уровни идут по сюжету (LEVELS): тюремный корпус → двор → болота → Ошен-драйв → порт.
## Level берёт свои данные через get_current_level_data(). После зачистки арены
## LevelDirector вызывает next_level(): следующий уровень грузится, очки и жизни сохраняются.
## Пользовательский аргумент --level=N (1..5) — начать с уровня N.
## Debug: F2–F6 (Debug.level_requested) — открыть уровень 1–5.
## В режиме --autoplay сохранения не пишутся.
##
## class_name не задаётся намеренно: он конфликтовал бы с именем autoload.

## Данные уровней по порядку сюжета.
const LEVELS: Array[String] = [
	"res://data/levels/cellblock.tres",
	"res://data/levels/yard.tres",
	"res://data/levels/everglades.tres",
	"res://data/levels/ocean_drive.tres",
	"res://data/levels/port.tres",
]
## Сцена уровня.
const LEVEL_SCENE: String = "res://scenes/level/level.tscn"

## Текущие очки.
var score: int = 0
## Оставшиеся жизни героини.
var lives: int = 3
## Индекс текущего уровня в LEVELS.
var level_index: int = 0


func _init() -> void:
	# В _init, а не в _ready: _ready автозагрузок идёт уже после _enter_tree главной сцены,
	# а Level спрашивает уровень именно там.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level="):
			level_index = clampi(arg.get_slice("=", 1).to_int() - 1, 0, LEVELS.size() - 1)


func _ready() -> void:
	Events.enemy_defeated.connect(_on_enemy_defeated)
	Events.pickup_collected.connect(_on_pickup_collected)
	Debug.level_requested.connect(load_level)


## Данные текущего уровня (null — если файла нет).
func get_current_level_data() -> LevelData:
	var path: String = LEVELS[level_index]
	return load(path) as LevelData if ResourceLoader.exists(path) else null


## Загрузить уровень index (0..LEVELS.size()-1); очки и жизни сохраняются.
func load_level(index: int) -> void:
	if index < 0 or index >= LEVELS.size():
		return
	level_index = index
	print("Загрузка уровня %d (очки %d, жизни %d)" % [index + 1, score, lives])
	get_tree().change_scene_to_file.call_deferred(LEVEL_SCENE)


## Следующий уровень по сюжету. Возвращает false, если уровней больше нет.
func next_level() -> bool:
	if level_index + 1 >= LEVELS.size():
		print("Все уровни пройдены")
		return false
	load_level(level_index + 1)
	return true


func _on_enemy_defeated(points: int) -> void:
	score += points


func _on_pickup_collected(data: PickupData, _collector: Node2D) -> void:
	if data.kind == PickupData.Kind.SCORE:
		score += data.amount
		print("Очки: +%d (всего %d)" % [data.amount, score])
