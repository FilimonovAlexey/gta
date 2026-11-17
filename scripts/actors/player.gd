class_name Player
extends Actor
## Героиня. Автомат состояний IDLE / WALK / JUMP / LAND.
##
## - Ходьба в 8 направлений; Input.get_vector нормирует диагональ,
##   поэтому по диагонали не быстрее, чем по прямой.
## - Прыжок: скорость по земле фиксируется в момент отталкивания,
##   в воздухе управлять нельзя.
## - LAND: короткая пауза после приземления (stats.land_time), двигаться нельзя.
## - С пользовательским аргументом --autoplay вместо игрока управляет бот.

enum State { IDLE, WALK, JUMP, LAND }

## Как часто бот меняет направление, с.
const BOT_MOVE_PERIOD: float = 1.2
## Как часто бот прыгает, с.
const BOT_JUMP_PERIOD: float = 1.7
## Маршрут бота: в целом вправо по улице, с заходами вглубь и назад.
const BOT_MOVES: Array[Vector2] = [
	Vector2(1, 0), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1),
	Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, -1),
]

var state: State = State.IDLE

## Сколько времени прошло в текущем состоянии, с.
var _state_time: float = 0.0
## Ввод текущего кадра: направление (длина <= 1) и нажатие прыжка.
var _input_move: Vector2 = Vector2.ZERO
var _input_jump: bool = false

var _autoplay: bool = OS.get_cmdline_user_args().has("--autoplay")
var _bot_time: float = 0.0
var _bot_jump_timer: float = BOT_JUMP_PERIOD


func get_state_name() -> String:
	return State.keys()[state]


func _update_behavior(delta: float) -> void:
	_state_time += delta
	_read_input(delta)
	match state:
		State.IDLE, State.WALK:
			_walk_from_input()
			if _input_jump:
				# Скорость, набранная в этот кадр, остаётся на весь прыжок.
				start_jump()
				_set_state(State.JUMP)
			else:
				_set_state(State.IDLE if _input_move == Vector2.ZERO else State.WALK)
		State.JUMP:
			pass  # В воздухе управления нет: velocity не меняется до приземления.
		State.LAND:
			velocity = Vector2.ZERO
			if _state_time >= stats.land_time:
				_set_state(State.IDLE)


func _on_landed() -> void:
	velocity = Vector2.ZERO
	if state == State.JUMP:
		_set_state(State.LAND)


func _walk_from_input() -> void:
	velocity = Vector2(_input_move.x * stats.walk_speed_x, _input_move.y * stats.walk_speed_y)
	if not is_zero_approx(_input_move.x):
		facing = 1 if _input_move.x > 0.0 else -1


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	_state_time = 0.0


func _read_input(delta: float) -> void:
	if _autoplay:
		_read_bot_input(delta)
		return
	_input_move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_input_jump = Input.is_action_just_pressed("jump")


func _read_bot_input(delta: float) -> void:
	_bot_time += delta
	var index: int = int(_bot_time / BOT_MOVE_PERIOD) % BOT_MOVES.size()
	_input_move = BOT_MOVES[index].normalized()
	_bot_jump_timer -= delta
	_input_jump = _bot_jump_timer <= 0.0
	if _input_jump:
		_bot_jump_timer = BOT_JUMP_PERIOD
