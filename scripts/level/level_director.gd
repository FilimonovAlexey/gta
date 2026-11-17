class_name LevelDirector
extends Node
## Ведёт уровень по сегментам LevelData: ставит камере замок следующего сегмента,
## в замке выпускает волны, по последней волне снимает замок и показывает «GO →».
##
## Волна: каждый WaveSpawn появляется через свой delay после начала волны
## (EnemySpawner.spawn с заданными стороной и глубиной). Следующая волна выходит,
## когда все враги текущей уже появились и живых на улице осталось
## не больше next_wave_threshold. Сегмент пройден — все волны вышли, живых 0.
## Арена босса (is_boss_arena): замок с баннером, не снимается.
## Debug: N (Debug.kill_all_requested) — убить всех живых врагов на экране и у его краёв.

enum Phase { MOVING, WAVES, BOSS }

## Стрелка «GO →» гаснет, когда камера проехала столько после снятия замка, px.
const GO_HIDE_DISTANCE: float = 300.0
## Клавиша N задевает врагов на столько за краями экрана (те, кто выходит), px.
const KILL_ALL_MARGIN: float = 200.0

@export var level_data: LevelData
@export var camera: BeatCamera
@export var spawner: EnemySpawner
@export var hud: LevelHud
## Следующая волна выходит, когда живых врагов не больше этого.
@export var next_wave_threshold: int = 1

var phase: Phase = Phase.MOVING
## Индекс текущего (или следующего, если камера едет) сегмента.
var segment_index: int = 0
## Индекс текущей волны сегмента.
var wave_index: int = -1

## Время с начала текущей волны, с.
var _wave_time: float = 0.0
## Индексы ещё не появившихся спавнов текущей волны.
var _pending: Array[int] = []
## Где камера сняла замок — для гашения «GO →».
var _release_x: float = 0.0


func _ready() -> void:
	Debug.kill_all_requested.connect(_on_kill_all_requested)
	if level_data == null or camera == null or spawner == null:
		push_error("LevelDirector: не заданы level_data, camera или spawner")
		return
	camera.stop_reached.connect(_on_stop_reached)
	_aim_camera()


func _physics_process(delta: float) -> void:
	if hud != null and hud.is_go_visible():
		if camera.global_position.x - _release_x >= GO_HIDE_DISTANCE or camera.locked:
			hud.hide_go()
	if phase != Phase.WAVES:
		return
	_wave_time += delta
	_spawn_due()
	if not _pending.is_empty():
		return
	var alive: int = count_alive_enemies()
	var segment: LevelSegment = level_data.segments[segment_index]
	if wave_index + 1 < segment.waves.size():
		if alive <= next_wave_threshold:
			_start_wave(wave_index + 1)
	elif alive == 0:
		_clear_segment()


func count_alive_enemies() -> int:
	var count: int = 0
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and enemy.is_alive():
			count += 1
	return count


## Камере — замок текущего сегмента (или до конца улицы, если сегментов больше нет).
func _aim_camera() -> void:
	if segment_index < level_data.segments.size():
		camera.release(level_data.segments[segment_index].lock_x)
	else:
		camera.release(INF)


func _on_stop_reached() -> void:
	if segment_index >= level_data.segments.size():
		return
	var segment: LevelSegment = level_data.segments[segment_index]
	if not segment.banner_text.is_empty() and hud != null:
		hud.show_banner(segment.banner_text)
	if segment.is_boss_arena:
		phase = Phase.BOSS
		print("Арена босса (x = %d)" % segment.lock_x)
		Events.boss_arena_reached.emit()
		return
	print("Сегмент %d: замок (x = %d), волн: %d" % [segment_index + 1, segment.lock_x, segment.waves.size()])
	Events.segment_started.emit(segment_index)
	phase = Phase.WAVES
	if segment.waves.is_empty():
		_clear_segment()
	else:
		_start_wave(0)


func _start_wave(index: int) -> void:
	wave_index = index
	_wave_time = 0.0
	_pending.clear()
	var wave: WaveData = level_data.segments[segment_index].waves[index]
	for i in wave.spawns.size():
		_pending.append(i)
	print("Сегмент %d, волна %d: врагов %d" % [segment_index + 1, index + 1, wave.spawns.size()])
	Events.wave_started.emit(segment_index, index)
	_spawn_due()


func _spawn_due() -> void:
	var wave: WaveData = level_data.segments[segment_index].waves[wave_index]
	for i in range(_pending.size() - 1, -1, -1):
		var spawn: WaveSpawn = wave.spawns[_pending[i]]
		if spawn.delay <= _wave_time:
			_pending.remove_at(i)
			var side: int = 1 if spawn.side == WaveSpawn.ScreenSide.RIGHT else -1
			spawner.spawn(spawn.enemy, side, spawn.depth)


func _clear_segment() -> void:
	print("Сегмент %d пройден" % [segment_index + 1])
	Events.segment_cleared.emit(segment_index)
	phase = Phase.MOVING
	wave_index = -1
	segment_index += 1
	_release_x = camera.global_position.x
	_aim_camera()
	if hud != null:
		hud.hide_banner()
		hud.show_go()


func _on_kill_all_requested() -> void:
	var view: Rect2 = camera.get_view_rect().grow(KILL_ALL_MARGIN) if camera != null else Rect2()
	var killed: int = 0
	for node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and enemy.is_alive() and view.has_point(enemy.global_position):
			enemy.kill()
			killed += 1
	print("Debug N: убито врагов: %d" % killed)
