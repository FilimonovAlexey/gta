class_name Player
extends Actor
## Героиня. Автомат поведения IDLE / WALK / JUMP / JUMP_ATTACK / LAND / ATTACK;
## реакции на урон (HURT, KNOCKDOWN, …) ведёт базовый Actor.
##
## - Ходьба в 8 направлений; Input.get_vector нормирует диагональ.
## - Прыжок: скорость по земле фиксируется в момент отталкивания,
##   в воздухе управлять нельзя. attack в прыжке — удар ногой, один раз за прыжок.
## - Серия combo: джеб → кросс → нога → апперкот. Следующий удар идёт,
##   только если предыдущий попал; промах сбрасывает серию к первому удару,
##   как и combo_reset_time без нажатий.
## - Буфер: нажатие attack помнится stats.attack_buffer_time; следующий удар
##   серии начинается в конце активного окна предыдущего.
## - Во время атаки ходить нельзя; разворот — только в момент начала удара.
## - С пользовательским аргументом --autoplay вместо игрока управляет бот.
## - Здоровье и смерть пока только в выводе отладки; бессмертие — Debug.god_mode,
##   R в режиме отладки воскрешает.

enum State { IDLE, WALK, JUMP, JUMP_ATTACK, LAND, ATTACK }

## Бот без цели: как часто меняет направление, с.
const BOT_MOVE_PERIOD: float = 1.2
## Маршрут бота без цели: в целом вправо по улице, с заходами вглубь и назад.
const BOT_MOVES: Array[Vector2] = [
	Vector2(1, 0), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1),
	Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1),
]
## Бот: как часто прыгает рядом с целью (удар ногой в прыжке), с.
const BOT_JUMP_PERIOD: float = 3.0
## Бот: как часто жмёт attack рядом с целью, с.
const BOT_ATTACK_PERIOD: float = 0.1
## Бот: на каком расстоянии по x от цели встаёт, px.
const BOT_STAND_DISTANCE: float = 70.0
## Бот: на каком расстоянии по x начинает бить, px.
const BOT_ATTACK_RANGE_X: float = 110.0
## Бот: допуск по глубине, при котором считает, что стоит на линии цели, px.
const BOT_DEPTH_TOLERANCE: float = 10.0
## Бот: с какой высоты прыжка бьёт ногой, px.
const BOT_AIR_ATTACK_HEIGHT: float = 30.0

## Удары серии по порядку.
@export var combo: Array[AttackData] = []
## Удар в прыжке.
@export var jump_attack: AttackData

var state: State = State.IDLE

## Сколько времени прошло в текущем состоянии, с.
var _state_time: float = 0.0
## Ввод: направление (длина <= 1) и нажатие прыжка (живёт до конца ближайшего
## _update_behavior, чтобы не терялось в хитстопе).
var _input_move: Vector2 = Vector2.ZERO
var _jump_pressed: bool = false
## Сколько ещё помнится нажатие attack, с.
var _attack_buffer: float = 0.0
## Индекс текущего удара серии и того, с которого начнётся следующая атака.
var _combo_index: int = 0
var _next_combo_index: int = 0
## Сколько прошло после конца последнего удара серии, с.
var _combo_idle_time: float = 0.0
## Был ли уже удар в текущем прыжке.
var _air_attack_used: bool = false

var _autoplay: bool = OS.get_cmdline_user_args().has("--autoplay")
var _bot_time: float = 0.0
var _bot_jump_timer: float = BOT_JUMP_PERIOD
var _bot_attack_timer: float = 0.0


func _ready() -> void:
	super._ready()
	immortal = Debug.god_mode
	Debug.god_mode_changed.connect(_on_god_mode_changed)
	Debug.revive_requested.connect(_on_revive_requested)
	health_changed.connect(_on_health_changed)
	died.connect(_on_died)


func get_state_name() -> String:
	var text: String = State.keys()[state]
	if current_attack != null:
		text += " %s:%s" % [current_attack.name, AttackPhase.keys()[get_attack_phase()]]
	return text


func _read_controls(delta: float) -> void:
	var attack_pressed: bool = false
	if _autoplay:
		attack_pressed = _read_bot_input(delta)
	else:
		_input_move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if Input.is_action_just_pressed("jump"):
			_jump_pressed = true
		attack_pressed = Input.is_action_just_pressed("attack")
	if attack_pressed:
		_attack_buffer = stats.attack_buffer_time
	else:
		_attack_buffer = maxf(_attack_buffer - delta, 0.0)


func _update_behavior(delta: float) -> void:
	_state_time += delta
	match state:
		State.IDLE, State.WALK:
			_combo_idle_time += delta
			if _combo_idle_time > stats.combo_reset_time:
				_next_combo_index = 0
			if not combo.is_empty() and _consume_attack_press():
				_start_combo_attack(_next_combo_index)
			elif _jump_pressed:
				# Скорость, набранная в этот кадр, остаётся на весь прыжок.
				_walk_from_input()
				start_jump()
				_air_attack_used = false
				_set_state(State.JUMP)
			else:
				_walk_from_input()
				_set_state(State.IDLE if _input_move == Vector2.ZERO else State.WALK)
		State.JUMP:
			# В воздухе управления нет: velocity не меняется до приземления.
			if not _air_attack_used and jump_attack != null and _consume_attack_press():
				_air_attack_used = true
				start_attack(jump_attack)
				_set_state(State.JUMP_ATTACK)
		State.JUMP_ATTACK:
			if get_attack_phase() == AttackPhase.FINISHED:
				stop_attack()
				_set_state(State.JUMP)
		State.LAND:
			velocity = Vector2.ZERO
			if _state_time >= stats.land_time:
				_set_state(State.IDLE)
		State.ATTACK:
			_update_ground_attack()
	_jump_pressed = false


func _update_ground_attack() -> void:
	velocity = Vector2.ZERO
	var phase: AttackPhase = get_attack_phase()
	var can_chain: bool = attack_connected and _combo_index < combo.size() - 1
	if phase >= AttackPhase.RECOVERY and can_chain and _consume_attack_press():
		# Конец активного окна (или recovery) попавшего удара: сразу следующий.
		_start_combo_attack(_combo_index + 1)
	elif phase == AttackPhase.FINISHED:
		_next_combo_index = (_combo_index + 1) % combo.size() if attack_connected else 0
		stop_attack()
		_combo_idle_time = 0.0
		_set_state(State.IDLE)


func _start_combo_attack(index: int) -> void:
	_combo_index = index
	velocity = Vector2.ZERO
	# Развернуться можно только между ударами — в момент начала очередного.
	if not is_zero_approx(_input_move.x):
		facing = 1 if _input_move.x > 0.0 else -1
	start_attack(combo[index])
	_set_state(State.ATTACK)


func _consume_attack_press() -> bool:
	if _attack_buffer <= 0.0:
		return false
	_attack_buffer = 0.0
	return true


func _on_landed() -> void:
	velocity = Vector2.ZERO
	if state == State.JUMP_ATTACK:
		stop_attack()
	if state == State.JUMP or state == State.JUMP_ATTACK:
		_set_state(State.LAND)


func _on_hit_taken() -> void:
	_set_state(State.IDLE)
	_next_combo_index = 0
	_attack_buffer = 0.0


func _on_death_finished() -> void:
	# Героиня не исчезает: остаётся лежать, игра узнаёт о смерти через шину.
	Events.player_died.emit()


func _on_health_changed(current: int, maximum: int) -> void:
	print("Героиня: HP %d/%d" % [current, maximum])


func _on_died() -> void:
	print("Героиня погибла")


func _on_god_mode_changed(is_on: bool) -> void:
	immortal = is_on


func _on_revive_requested() -> void:
	if not is_alive():
		_set_state(State.IDLE)
		revive(position)


func _walk_from_input() -> void:
	velocity = Vector2(_input_move.x * stats.walk_speed_x, _input_move.y * stats.walk_speed_y)
	if not is_zero_approx(_input_move.x):
		facing = 1 if _input_move.x > 0.0 else -1


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	_state_time = 0.0


# --- Бот (--autoplay) --------------------------------------------------------

## Задаёт _input_move и _jump_pressed; возвращает, нажат ли attack в этот кадр.
func _read_bot_input(delta: float) -> bool:
	_bot_time += delta
	_bot_jump_timer -= delta
	_bot_attack_timer -= delta
	var target: Actor = _find_bot_target()
	if target == null:
		var index: int = int(_bot_time / BOT_MOVE_PERIOD) % BOT_MOVES.size()
		_input_move = BOT_MOVES[index].normalized()
		return false
	if state == State.JUMP:
		return height >= BOT_AIR_ATTACK_HEIGHT
	var offset: Vector2 = target.global_position - global_position
	var side: float = 1.0 if offset.x >= 0.0 else -1.0
	var in_range: bool = absf(offset.x) <= BOT_ATTACK_RANGE_X and absf(offset.y) <= BOT_DEPTH_TOLERANCE
	if not in_range:
		var to_spot := Vector2(offset.x - side * BOT_STAND_DISTANCE, offset.y)
		_input_move = Vector2(clampf(to_spot.x / 40.0, -1.0, 1.0), clampf(to_spot.y / 20.0, -1.0, 1.0)).limit_length(1.0)
		return false
	# Рядом с целью: почти стоим, но смотрим на неё.
	_input_move = Vector2(side * 0.05, 0.0)
	if _bot_jump_timer <= 0.0 and state != State.ATTACK:
		_bot_jump_timer = BOT_JUMP_PERIOD
		_jump_pressed = true
		return false
	if _bot_attack_timer <= 0.0:
		_bot_attack_timer = BOT_ATTACK_PERIOD
		return true
	return false


## Ближайший живой боец другой команды.
func _find_bot_target() -> Actor:
	var best: Actor = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("actors"):
		var actor := node as Actor
		if actor == null or actor == self or actor.team == team:
			continue
		if not actor.is_alive() or not actor.visible:
			continue
		var distance: float = global_position.distance_squared_to(actor.global_position)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best
