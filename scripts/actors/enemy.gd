class_name Enemy
extends Actor
## Враг-полицейский. Тип целиком задаётся EnemyData (data/enemies/*.tres):
## здоровье, скорости, атаки, дистанции, характер ИИ, щит. Сцена общая —
## scenes/enemies/enemy.tscn.
##
## Автомат поведения (реакции на урон ведёт базовый Actor):
## - ENTER — выходит из-за края экрана к точке входа (set_enter_point);
## - APPROACH — идёт к своему месту слева или справа от героини
##   (на preferred_distance), выравниваясь по глубине;
## - WAIT — держит дистанцию, понемногу переступает и просит токен атаки
##   у AttackDirector; с токеном подходит на attack_range и встаёт на линию героини;
## - ATTACK — проводит все атаки из data.attacks подряд; замах виден —
##   плейсхолдер мигает жёлтым;
## - RETREAT — отходит после атаки или удара (вероятности — в EnemyData).
## Решения (куда идти, просить ли токен, переступить ли) принимаются раз
## в decision_interval_min..max со случайным разбросом, между ними враг идёт
## к последней выбранной точке. Враги отталкиваются друг от друга.

enum State { ENTER, APPROACH, WAIT, ATTACK, RETREAT }

const GROUP: StringName = &"enemies"
## Цвет и полупериод мигания в замахе.
const WINDUP_COLOR := Color(1.0, 0.9, 0.15)
const WINDUP_BLINK_PERIOD: float = 0.05
## Плейсхолдер щита (в координатах Visual, взгляд вправо).
const SHIELD_RECT := Rect2(26.0, -172.0, 14.0, 140.0)
const SHIELD_COLOR := Color(0.55, 0.72, 0.92, 0.95)
## Точка считается достигнутой с такой точностью, px.
const ARRIVE_X: float = 10.0
const ARRIVE_Y: float = 6.0
## На каком расстоянии до точки враг начинает притормаживать, px.
const SLOW_RADIUS_X: float = 40.0
const SLOW_RADIUS_Y: float = 20.0
## Атака начинается, только если враг стоит на линии героини с такой точностью, px.
const ATTACK_DEPTH_TOLERANCE: float = 10.0
## Ближе этого по x враг не атакует, а отступает на дистанцию удара, px.
const MIN_ATTACK_DISTANCE: float = 45.0
## С токеном враг встаёт на attack_range * этот множитель.
const ATTACK_SPOT_FACTOR: float = 0.8
## Сколько враг с токеном пытается подойти, прежде чем вернуть токен, с.
const CLOSE_IN_TIMEOUT: float = 2.5
## Страховочные пределы состояний, с.
const ENTER_TIMEOUT: float = 4.0
const RETREAT_TIMEOUT: float = 1.2
## Героиня ушла от места ожидания дальше — враг снова идёт к ней (APPROACH), px.
const SLOT_LEAVE_DISTANCE: float = 90.0
## Переступание в WAIT: вероятность на одно решение, разброс и скорость.
const WAIT_STEP_CHANCE: float = 0.35
const WAIT_STEP_RANGE := Vector2(30.0, 16.0)
const WAIT_STEP_SPEED: float = 0.35
## Скорость отхода (доля от ходьбы).
const RETREAT_SPEED: float = 0.8
## Индивидуальный разброс дистанции и глубины ожидания, px.
const WAIT_DISTANCE_JITTER: float = 50.0
const DEPTH_OFFSET_RANGE: float = 18.0
## Обход героини при смене стороны: насколько уходить по глубине, px.
const DETOUR_DEPTH: float = 70.0
## Шаг между рядами ожидающих на одной стороне: второй ждёт дальше первого и т. д., px.
const SLOT_SPACING: float = 80.0
## Сколько врагов должно быть перевесом на одной стороне, чтобы враг перешёл на другую.
const SIDE_IMBALANCE: int = 2
## Отталкивание врагов друг от друга: радиус (по x; глубина растянута) и сила.
const SEPARATION_RADIUS: float = 90.0
const SEPARATION_DEPTH_SCALE: float = 2.5
const SEPARATION_STRENGTH: float = 0.9
## Место ожидания должно быть хотя бы на столько внутри экрана, px.
const WAIT_SCREEN_MARGIN: float = 30.0
## Минимальное ожидание перед просьбой о токене: от спокойного к агрессивному, с.
const MIN_WAIT_CALM: float = 1.6
const MIN_WAIT_AGGRESSIVE: float = 0.3

## Тип врага. Задаётся до добавления в дерево (спавнер) или в инспекторе.
@export var data: EnemyData

var state: State = State.APPROACH

var _state_time: float = 0.0
var _decision_timer: float = 0.0
## Цель — героиня (ближайший живой боец команды PLAYER).
var _target: Actor
var _director: AttackDirector
## С какой стороны от героини держится: -1 слева, 1 справа.
var _side: int = 1
## Ряд на своей стороне: сколько врагов той же стороны стоят к героине ближе.
var _slot_rank: int = 0
## Личная дистанция и сдвиг по глубине в ожидании — чтобы копы не стояли столбиком.
var _wait_distance: float = 0.0
var _depth_offset: float = 0.0
## Точка, к которой враг идёт до следующего решения.
var _move_target: Vector2
## APPROACH: идёт к точке обхода героини, а не к месту ожидания.
var _detouring: bool = false
## Точка входа на экран (ENTER).
var _enter_point: Vector2
var _has_enter_point: bool = false
## Сколько героиня уже за спиной (разворот через data.turn_delay), с.
var _turn_timer: float = 0.0
## Время на экране без атаки — приоритет у AttackDirector, с.
var _time_without_attack: float = 0.0
## Сколько враг с токеном подходит к героине, с.
var _close_in_time: float = 0.0
## Индекс текущей атаки из data.attacks.
var _attack_index: int = 0
## Получил удар: после реакции решить, отходить ли.
var _was_hit: bool = false
var _shield: ColorRect


func _ready() -> void:
	if data == null:
		push_error("%s: не задан data (EnemyData)" % name)
		data = EnemyData.new()
	stats = data
	placeholder_color = data.placeholder_color
	team = Team.ENEMY
	super._ready()
	add_to_group(GROUP)
	_director = get_tree().get_first_node_in_group(AttackDirector.GROUP) as AttackDirector
	_wait_distance = data.preferred_distance + randf_range(0.0, WAIT_DISTANCE_JITTER)
	_depth_offset = randf_range(-DEPTH_OFFSET_RANGE, DEPTH_OFFSET_RANGE)
	_decision_timer = randf_range(0.0, data.decision_interval_max)
	_move_target = position
	if data.has_shield:
		_create_shield()
	died.connect(_on_died)
	if _has_enter_point:
		_set_state(State.ENTER)
	else:
		_enter_state(State.APPROACH)


func _exit_tree() -> void:
	_release_token()


## Выйти из-за края экрана к точке point. Вызывать до добавления в дерево.
func set_enter_point(point: Vector2) -> void:
	_enter_point = point
	_has_enter_point = true


func get_time_without_attack() -> float:
	return _time_without_attack


func has_attack_token() -> bool:
	return _director != null and _director.has_token(self)


func is_requesting_token() -> bool:
	return _director != null and _director.is_requesting(self)


## Виден ли враг сейчас на экране.
func is_on_screen() -> bool:
	return StreetCamera.get_visible_world_rect(get_viewport()).has_point(global_position)


func get_state_name() -> String:
	var text: String = "%s %s" % [data.enemy_type, State.keys()[state]]
	if current_attack != null:
		text += " %s:%s" % [current_attack.name, AttackPhase.keys()[get_attack_phase()]]
	return text


# --- Автомат -----------------------------------------------------------------

func _update_behavior(delta: float) -> void:
	_state_time += delta
	if state != State.ATTACK and is_on_screen():
		_time_without_attack += delta
	if not _is_target_valid():
		_target = _find_target()
	if _was_hit:
		_was_hit = false
		_set_state(State.RETREAT if randf() < data.retreat_after_hit_chance else State.APPROACH)
	_decision_timer -= delta
	var decide: bool = _decision_timer <= 0.0
	if decide:
		_decision_timer = randf_range(data.decision_interval_min, data.decision_interval_max)
	match state:
		State.ENTER:
			_update_enter()
		State.APPROACH:
			_update_approach(decide)
		State.WAIT:
			_update_wait(decide, delta)
		State.ATTACK:
			_update_attack()
		State.RETREAT:
			_update_retreat(decide)
	if state != State.ATTACK:
		velocity += _get_separation()
		_update_facing(delta)


func _update_enter() -> void:
	if _walk_to(_enter_point, 1.0) or _state_time >= ENTER_TIMEOUT:
		_set_state(State.APPROACH)


func _update_approach(decide: bool) -> void:
	if _target == null:
		_set_state(State.WAIT)
		return
	if decide:
		_choose_side()
		_move_target = _get_approach_point()
	if _walk_to(_move_target, 1.0):
		if _detouring:
			# Обошли героиню — теперь к месту ожидания.
			_move_target = _get_approach_point()
		else:
			_set_state(State.WAIT)


func _update_wait(decide: bool, delta: float) -> void:
	if _target == null:
		_release_token()
		velocity = Vector2.ZERO
		return
	if _director == null or _director.has_token(self):
		_update_close_in(delta)
		return
	if decide:
		var slot: Vector2 = _get_slot_point()
		if absf(slot.x - position.x) > SLOT_LEAVE_DISTANCE or absf(slot.y - position.y) > SLOT_LEAVE_DISTANCE * 0.5:
			_set_state(State.APPROACH)
			return
		var min_wait: float = lerpf(MIN_WAIT_CALM, MIN_WAIT_AGGRESSIVE, data.aggression)
		if not _director.is_requesting(self) and _state_time >= min_wait and randf() < data.aggression:
			_director.request_token(self)
		elif randf() < WAIT_STEP_CHANCE:
			var step := Vector2(randf_range(-WAIT_STEP_RANGE.x, WAIT_STEP_RANGE.x), randf_range(-WAIT_STEP_RANGE.y, WAIT_STEP_RANGE.y))
			_move_target = _clamp_to_bounds(slot + step)
	_walk_to(_move_target, WAIT_STEP_SPEED)


## С токеном: подойти на дистанцию удара, встать на линию героини, повернуться — и атаковать.
func _update_close_in(delta: float) -> void:
	_close_in_time += delta
	if _close_in_time >= CLOSE_IN_TIMEOUT:
		_set_state(State.APPROACH)
		return
	var offset: Vector2 = position - _target.position
	var side: int = _side if is_zero_approx(offset.x) else (1 if offset.x > 0.0 else -1)
	var spot := Vector2(_target.position.x + side * data.attack_range * ATTACK_SPOT_FACTOR, _target.position.y)
	_walk_to(_clamp_to_bounds(spot), 1.0)
	var dx: float = absf(offset.x)
	var in_range: bool = dx <= data.attack_range and dx >= MIN_ATTACK_DISTANCE and absf(offset.y) <= ATTACK_DEPTH_TOLERANCE
	if in_range and facing == -side and _target.can_be_hit() and not data.attacks.is_empty():
		_set_state(State.ATTACK)


func _update_attack() -> void:
	match get_attack_phase():
		AttackPhase.NONE:
			_finish_attack()
		AttackPhase.ACTIVE:
			velocity = Vector2(facing * current_attack.lunge_speed, 0.0)
		AttackPhase.FINISHED:
			if _attack_index + 1 < data.attacks.size():
				_attack_index += 1
				velocity = Vector2.ZERO
				start_attack(data.attacks[_attack_index])
			else:
				_finish_attack()
		_:
			velocity = Vector2.ZERO


func _finish_attack() -> void:
	stop_attack()
	velocity = Vector2.ZERO
	_set_state(State.RETREAT if randf() < data.retreat_after_attack_chance else State.WAIT)


func _update_retreat(decide: bool) -> void:
	if decide:
		_move_target = _get_retreat_point()
	if _walk_to(_move_target, RETREAT_SPEED) or _state_time >= RETREAT_TIMEOUT:
		_set_state(State.APPROACH)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	# Токен живёт только в WAIT (подход с токеном) и ATTACK.
	var keeps_token: bool = state == State.WAIT and new_state == State.ATTACK
	if (state == State.WAIT or state == State.ATTACK) and not keeps_token:
		_release_token()
	_enter_state(new_state)


func _enter_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	match new_state:
		State.ENTER:
			_move_target = _enter_point
		State.APPROACH:
			_choose_side()
			_move_target = _get_approach_point()
		State.WAIT:
			_move_target = position
		State.ATTACK:
			_attack_index = 0
			_time_without_attack = 0.0
			velocity = Vector2.ZERO
			start_attack(data.attacks[0])
		State.RETREAT:
			_move_target = _get_retreat_point()


# --- Хуки Actor ----------------------------------------------------------------

func _on_hit_taken() -> void:
	_release_token()
	_set_state(State.WAIT)
	_was_hit = true


func _on_died() -> void:
	_release_token()
	Events.enemy_defeated.emit(data.score)


## Щит: спереди держит всё, кроме guard_break; сзади лёгкие удары проходят
## уроном, но не прерывают (ARMORED), сбивающие — обычное попадание.
func _get_hit_response(attack: AttackData, attacker: Actor) -> HitResult:
	if not data.has_shield or reaction != Reaction.NONE:
		return HitResult.HIT
	if is_facing_towards(attacker):
		return HitResult.HIT if attack.guard_break else HitResult.BLOCKED
	return HitResult.HIT if attack.knockdown else HitResult.ARMORED


func _get_block_pushback() -> float:
	return data.shield_pushback


func _get_body_color() -> Color:
	if _flash_time <= 0.0 and get_attack_phase() == AttackPhase.STARTUP:
		if fmod(get_attack_time(), WINDUP_BLINK_PERIOD * 2.0) < WINDUP_BLINK_PERIOD:
			return WINDUP_COLOR
	return super._get_body_color()


# --- Вспомогательное -----------------------------------------------------------

func _release_token() -> void:
	_close_in_time = 0.0
	if _director != null and is_instance_valid(_director):
		_director.release_token(self)


func _is_target_valid() -> bool:
	return _target != null and is_instance_valid(_target) and _target.is_alive()


## Ближайший живой боец команды героини.
func _find_target() -> Actor:
	var best: Actor = null
	var best_distance: float = INF
	for node in get_tree().get_nodes_in_group("actors"):
		var actor := node as Actor
		if actor == null or actor.team != Team.PLAYER or not actor.is_alive():
			continue
		var distance: float = position.distance_squared_to(actor.position)
		if distance < best_distance:
			best_distance = distance
			best = actor
	return best


## Выбрать сторону от героини: обычно ту, где враг уже стоит; если там
## тесно (перевес SIDE_IMBALANCE) или места нет из-за края улицы — другую.
func _choose_side() -> void:
	if _target == null:
		return
	var natural: int = 1 if position.x >= _target.position.x else -1
	var left: int = 0
	var right: int = 0
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Enemy
		if other == null or other == self or not other.is_alive() or other.state == State.ENTER:
			continue
		if other._side > 0:
			right += 1
		else:
			left += 1
	var same: int = right if natural > 0 else left
	var opposite: int = left if natural > 0 else right
	var side: int = -natural if same - opposite >= SIDE_IMBALANCE else natural
	# Места нет (край улицы) или оно за кадром, а с другой стороны есть — на другую сторону.
	if not _is_wait_x_ok(_target.position.x + side * _wait_distance) and _is_wait_x_ok(_target.position.x - side * _wait_distance):
		side = -side
	_side = side
	# Ряд: чем больше своих ближе к героине, тем дальше место ожидания.
	var my_distance: float = absf(position.x - _target.position.x)
	_slot_rank = 0
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Enemy
		if other == null or other == self or not other.is_alive() or other.state == State.ENTER:
			continue
		if other._side == _side and absf(other.position.x - _target.position.x) < my_distance:
			_slot_rank += 1


## Можно ли ждать на x: в пределах улицы и на экране (в замке камеры за кадром не стоят).
func _is_wait_x_ok(x: float) -> bool:
	if walk_bounds.has_area() and (x < walk_bounds.position.x or x > walk_bounds.end.x):
		return false
	var view: Rect2 = StreetCamera.get_visible_world_rect(get_viewport())
	return x >= view.position.x + WAIT_SCREEN_MARGIN and x <= view.end.x - WAIT_SCREEN_MARGIN


## Место ожидания рядом с героиней.
func _get_slot_point() -> Vector2:
	var distance: float = _wait_distance + _slot_rank * SLOT_SPACING
	var point := Vector2(_target.position.x + _side * distance, _target.position.y + _depth_offset)
	return _clamp_to_bounds(point)


## Куда идти в APPROACH: к месту ожидания, а если оно по ту сторону героини —
## в обход по глубине, чтобы не проходить сквозь неё.
func _get_approach_point() -> Vector2:
	_detouring = false
	if _target == null:
		return position
	var dx: float = position.x - _target.position.x
	var wrong_side: bool = signf(dx) != float(_side) and not is_zero_approx(dx)
	if wrong_side and absf(dx) < _wait_distance:
		# Точка обхода — уже на нужной стороне, со сдвигом по глубине.
		_detouring = true
		var detour_dir: float = 1.0 if _depth_offset >= 0.0 else -1.0
		return _clamp_to_bounds(Vector2(_target.position.x + _side * DETOUR_DEPTH, _target.position.y + detour_dir * DETOUR_DEPTH))
	return _get_slot_point()


func _get_retreat_point() -> Vector2:
	if _target == null:
		return position
	var away: int = 1 if position.x >= _target.position.x else -1
	var x: float = _target.position.x + away * (_wait_distance + data.retreat_distance)
	return _clamp_to_bounds(Vector2(x, _target.position.y + _depth_offset * 2.0))


## Идти к point (с притормаживанием у цели). Возвращает true, если уже на месте.
func _walk_to(point: Vector2, speed_scale: float) -> bool:
	var to: Vector2 = point - position
	if absf(to.x) <= ARRIVE_X and absf(to.y) <= ARRIVE_Y:
		velocity = Vector2.ZERO
		return true
	velocity = Vector2(
		clampf(to.x / SLOW_RADIUS_X, -1.0, 1.0) * stats.walk_speed_x,
		clampf(to.y / SLOW_RADIUS_Y, -1.0, 1.0) * stats.walk_speed_y
	) * speed_scale
	return false


## Отталкивание от соседних врагов, чтобы не сливались в одну точку.
func _get_separation() -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Enemy
		if other == null or other == self or not other.is_alive():
			continue
		var d: Vector2 = position - other.position
		d.y *= SEPARATION_DEPTH_SCALE
		var length: float = d.length()
		if length >= SEPARATION_RADIUS:
			continue
		if length < 0.01:
			# Стоят точно друг в друге: разводим по номеру экземпляра.
			d = Vector2(1.0 if get_instance_id() > other.get_instance_id() else -1.0, 0.0)
			length = 1.0
		push += d / length * (1.0 - length / SEPARATION_RADIUS)
	return Vector2(push.x * stats.walk_speed_x, push.y * stats.walk_speed_y) * SEPARATION_STRENGTH


## Поворот к героине с задержкой data.turn_delay; в ENTER — по ходу движения.
func _update_facing(delta: float) -> void:
	var desired: int = facing
	if state == State.ENTER:
		if absf(velocity.x) > 1.0:
			desired = 1 if velocity.x > 0.0 else -1
	elif _target != null:
		desired = 1 if _target.position.x >= position.x else -1
	if desired == facing:
		_turn_timer = 0.0
		return
	_turn_timer += delta
	if _turn_timer >= data.turn_delay:
		facing = desired
		_turn_timer = 0.0


func _create_shield() -> void:
	_shield = ColorRect.new()
	_shield.name = "Shield"
	_shield.position = SHIELD_RECT.position
	_shield.size = SHIELD_RECT.size
	_shield.color = SHIELD_COLOR
	_shield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.add_child(_shield)
