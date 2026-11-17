class_name Actor
extends Node2D
## Базовый класс всех бойцов: героини, врагов и босса.
##
## position — точка на земле под ногами (x — вдоль улицы, y — глубина).
## Прыжок хранится отдельно в height; спрайт (Visual) смещается на -height,
## а тень (Shadow) остаётся на земле.
##
## Автомат двухуровневый:
## - верхний уровень — реакции на урон (Reaction), общий для всех и живёт здесь:
##   HURT → NONE, KNOCKDOWN (полёт) → DOWN (лежит) → GETUP → NONE, DEAD;
## - нижний — поведение наследника: он переопределяет _update_behavior()
##   и задаёт velocity. Пока реакция не NONE, _update_behavior() не вызывается.
##
## Атаки: наследник вызывает start_attack(), база ведёт фазы
## startup / active / recovery, включает Hitbox в активное окно, наносит урон
## найденным целям, ставит хитстоп и рисует «руку»-плейсхолдер.

## Испускается в момент касания земли после прыжка или падения.
signal landed
## Здоровье изменилось (попадание или воскрешение).
signal health_changed(current: int, maximum: int)
## Здоровье дошло до нуля (в начале падения DEAD).
signal died

## Команда бойца: от неё зависят слои хёртбокса и маска хитбокса.
enum Team { PLAYER, ENEMY }
## Реакции на урон — верхний уровень автомата.
enum Reaction { NONE, HURT, KNOCKDOWN, DOWN, GETUP, DEAD }
## Фаза текущей атаки.
enum AttackPhase { NONE, STARTUP, ACTIVE, RECOVERY, FINISHED }

## Сколько вершин у эллипса тени.
const SHADOW_SEGMENTS: int = 24
## Биты слоёв 2D-физики (имена — в project.godot, раздел layer_names).
const LAYER_PLAYER_HURTBOX: int = 1
const LAYER_ENEMY_HURTBOX: int = 2
## Полупериод мигания при неуязвимости и смерти, с.
const BLINK_PERIOD: float = 0.06
## Минимальная длительность белой вспышки при попадании, с.
const FLASH_MIN_TIME: float = 0.06
const FLASH_COLOR := Color(1.0, 1.0, 1.0)
## За сколько секунд полёта боец поворачивается в лежачее положение.
const FALL_ROTATE_TIME: float = 0.25
## Толщина и минимальная длина «руки»-плейсхолдера, px.
const ARM_THICKNESS: float = 12.0
const ARM_MIN_LENGTH: float = 16.0

## Параметры бойца.
@export var stats: ActorStats
## Цвет плейсхолдер-прямоугольника, пока нет арта.
@export var placeholder_color: Color = Color(0.5, 0.5, 0.5)
## Команда: атаки героини бьют только врагов, атаки врагов — только героиню.
@export var team: Team = Team.ENEMY

@export_group("Shadow")
## Полуоси эллипса тени на земле.
@export var shadow_radius: Vector2 = Vector2(38.0, 12.0)
## Непрозрачность тени, когда боец стоит на земле.
@export_range(0.0, 1.0) var shadow_alpha: float = 0.35
## Непрозрачность тени на высоте shadow_fade_height и выше.
@export_range(0.0, 1.0) var shadow_min_alpha: float = 0.15
## Масштаб тени на высоте shadow_fade_height и выше.
@export_range(0.1, 1.0) var shadow_min_scale: float = 0.6
## Высота, на которой тень уменьшается и бледнеет до минимума.
@export var shadow_fade_height: float = 180.0

## Высота над землёй (>= 0).
var height: float = 0.0
## Вертикальная скорость по height, px/с (вверх — положительная).
var vertical_velocity: float = 0.0
## Скорость по земле: x — вдоль улицы, y — вглубь, px/с.
var velocity: Vector2 = Vector2.ZERO
## Направление взгляда: 1 — вправо, -1 — влево.
var facing: int = 1:
	set(value):
		facing = 1 if value >= 0 else -1
## Прямоугольник, в котором может находиться position. Пустой — без ограничений.
var walk_bounds: Rect2 = Rect2()
## Текущее здоровье.
var health: int = 0
## Текущая реакция на урон (NONE — боец управляет собой сам).
var reaction: Reaction = Reaction.NONE
## Текущая атака (null — не атакует).
var current_attack: AttackData
## Попала ли текущая атака хотя бы по одной цели.
var attack_connected: bool = false

## Время от начала текущей атаки (без учёта хитстопа), с.
var _attack_time: float = 0.0
## Время в текущей реакции, с.
var _reaction_time: float = 0.0
## Оставшийся хитстоп, с. Пока > 0, боец замер.
var _hitstop_time: float = 0.0
## Оставшаяся белая вспышка, с.
var _flash_time: float = 0.0
## Оставшаяся неуязвимость после подъёма, с.
var _invuln_time: float = 0.0
## Попаданий подряд и время с последнего попадания.
var _chain_hits: int = 0
var _since_last_hit: float = INF
## Начальная скорость отката при HURT (со знаком), px/с.
var _hurt_push_speed: float = 0.0
## DEAD: упал ли уже на землю (с этого момента идёт мигание).
var _dead_on_ground: bool = false
## DEAD: отработал ли уже _on_death_finished().
var _death_finished: bool = false
## Часы для мигания.
var _blink_clock: float = 0.0

@onready var shadow: Polygon2D = $Shadow
@onready var visual: Node2D = $Visual
@onready var body: ColorRect = $Visual/Body
@onready var arm: ColorRect = $Visual/Arm
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hitbox: Hitbox = $Hitbox


func _ready() -> void:
	add_to_group("actors")
	if stats == null:
		push_error("%s: не задан stats (ActorStats)" % name)
		stats = ActorStats.new()
	health = stats.max_health
	body.color = placeholder_color
	arm.color = placeholder_color.darkened(0.25)
	arm.visible = false
	shadow.polygon = _make_ellipse(shadow_radius)
	var is_player: bool = team == Team.PLAYER
	hurtbox.collision_layer = LAYER_PLAYER_HURTBOX if is_player else LAYER_ENEMY_HURTBOX
	hitbox.collision_mask = LAYER_ENEMY_HURTBOX if is_player else LAYER_PLAYER_HURTBOX
	_update_visual()


func _physics_process(delta: float) -> void:
	# Ввод читается всегда, даже в хитстопе, — иначе нажатие в замершем кадре потеряется.
	_read_controls(delta)
	_flash_time = maxf(_flash_time - delta, 0.0)
	if _hitstop_time > 0.0:
		_hitstop_time -= delta
		_update_visual()
		return
	_update_timers(delta)
	if reaction == Reaction.NONE:
		_tick_attack(delta)
		_update_behavior(delta)
	else:
		_update_reaction()
	_move_on_ground(delta)
	_apply_gravity(delta)
	_update_visual()
	_check_hits()


# --- Точки расширения для наследников ---------------------------------------

## Чтение ввода (игрок или бот). Вызывается каждый кадр, даже в хитстопе и реакциях.
func _read_controls(_delta: float) -> void:
	pass


## Логика бойца (автомат состояний). Переопределяется наследниками.
func _update_behavior(_delta: float) -> void:
	pass


## Вызывается при приземлении, если боец не в реакции. Переопределяется наследниками.
func _on_landed() -> void:
	pass


## Вызывается при каждом полученном попадании, после отмены текущей атаки.
## Наследник сбрасывает своё состояние (серию, буферы).
func _on_hit_taken() -> void:
	pass


## Вызывается, когда мёртвый боец отмигал. По умолчанию — исчезает.
func _on_death_finished() -> void:
	queue_free()


## Имя состояния поведения наследника для отладочной подписи.
func get_state_name() -> String:
	return "NONE"


# --- Общий интерфейс ---------------------------------------------------------

## Подпись для отладки: реакция, если идёт, иначе состояние наследника.
func get_display_state() -> String:
	if reaction != Reaction.NONE:
		return Reaction.keys()[reaction]
	return get_state_name()


## В воздухе ли боец.
func is_airborne() -> bool:
	return height > 0.0 or vertical_velocity > 0.0


func is_alive() -> bool:
	return reaction != Reaction.DEAD


## Можно ли сейчас по бойцу попасть. В полёте после сбивания, лёжа, при подъёме,
## в неуязвимости после подъёма и мёртвым — нельзя.
func can_be_hit() -> bool:
	if _invuln_time > 0.0:
		return false
	return reaction == Reaction.NONE or reaction == Reaction.HURT


## Оттолкнуться от земли с силой прыжка из stats.
func start_jump() -> void:
	vertical_velocity = stats.jump_velocity


## Задать полосу улицы и сразу поставить бойца в её пределы.
func set_walk_bounds(bounds: Rect2) -> void:
	walk_bounds = bounds
	position = _clamp_to_bounds(position)


## Заморозить бойца на t секунд (хитстоп). Перекрывающиеся заморозки не суммируются.
func freeze(t: float) -> void:
	_hitstop_time = maxf(_hitstop_time, t)


## Начать атаку с нуля (предыдущая, если была, отменяется).
func start_attack(attack: AttackData) -> void:
	current_attack = attack
	attack_connected = false
	_attack_time = 0.0
	hitbox.deactivate()
	_sync_hitbox()


## Прервать или завершить текущую атаку.
func stop_attack() -> void:
	current_attack = null
	hitbox.deactivate()


func get_attack_phase() -> AttackPhase:
	if current_attack == null:
		return AttackPhase.NONE
	if _attack_time < current_attack.startup:
		return AttackPhase.STARTUP
	if _attack_time < current_attack.get_active_end():
		return AttackPhase.ACTIVE
	if _attack_time < current_attack.get_total_time():
		return AttackPhase.RECOVERY
	return AttackPhase.FINISHED


## Получить удар. Вызывается атакующим, когда его Hitbox нашёл этого бойца.
func take_hit(attack: AttackData, attacker: Actor) -> void:
	if not can_be_hit():
		return
	# Куда отбрасывает: от атакующего. Лицом боец поворачивается к нему.
	var push_dir: int = 1 if global_position.x >= attacker.global_position.x else -1
	facing = -push_dir
	health = maxi(health - attack.damage, 0)
	health_changed.emit(health, stats.max_health)
	_chain_hits = _chain_hits + 1 if _since_last_hit <= stats.hit_chain_window else 1
	_since_last_hit = 0.0
	freeze(attack.hitstop)
	_flash_time = maxf(attack.hitstop, FLASH_MIN_TIME)
	stop_attack()
	_on_hit_taken()
	var push_speed: float = push_dir * attack.knockback
	if health == 0:
		_start_fall(push_speed, Reaction.DEAD)
		died.emit()
	elif attack.knockdown or is_airborne() or _chain_hits >= stats.hits_to_knockdown:
		_start_fall(push_speed, Reaction.KNOCKDOWN)
	else:
		_set_reaction(Reaction.HURT)
		_hurt_push_speed = push_speed
		velocity = Vector2(push_speed, 0.0)


## Вернуть бойца к жизни в точке at с полным здоровьем.
func revive(at: Vector2) -> void:
	stop_attack()
	_set_reaction(Reaction.NONE)
	health = stats.max_health
	height = 0.0
	vertical_velocity = 0.0
	velocity = Vector2.ZERO
	_hitstop_time = 0.0
	_flash_time = 0.0
	_invuln_time = 0.0
	_chain_hits = 0
	_since_last_hit = INF
	position = _clamp_to_bounds(at)
	visible = true
	set_physics_process(true)
	health_changed.emit(health, stats.max_health)
	_update_visual()


# --- Реакции на урон ---------------------------------------------------------

func _set_reaction(new_reaction: Reaction) -> void:
	reaction = new_reaction
	_reaction_time = 0.0
	if new_reaction == Reaction.DEAD:
		_dead_on_ground = false
		_death_finished = false


## Подбросить бойца по дуге: KNOCKDOWN или DEAD.
func _start_fall(push_speed: float, fall_reaction: Reaction) -> void:
	_set_reaction(fall_reaction)
	_chain_hits = 0
	velocity = Vector2(push_speed, 0.0)
	vertical_velocity = stats.knockdown_launch_velocity


func _update_timers(delta: float) -> void:
	_reaction_time += delta
	_invuln_time = maxf(_invuln_time - delta, 0.0)
	_since_last_hit += delta
	_blink_clock += delta


func _update_reaction() -> void:
	match reaction:
		Reaction.HURT:
			var t: float = clampf(_reaction_time / maxf(stats.hurt_time, 0.001), 0.0, 1.0)
			velocity = Vector2(_hurt_push_speed * (1.0 - t), 0.0)
			if _reaction_time >= stats.hurt_time:
				velocity = Vector2.ZERO
				_set_reaction(Reaction.NONE)
		Reaction.KNOCKDOWN:
			# Страховка на случай нулевого подброса: приземление обычно ловит _apply_gravity.
			if not is_airborne():
				velocity = Vector2.ZERO
				_set_reaction(Reaction.DOWN)
		Reaction.DOWN:
			if _reaction_time >= stats.down_time:
				_set_reaction(Reaction.GETUP)
		Reaction.GETUP:
			if _reaction_time >= stats.getup_time:
				_invuln_time = stats.getup_invuln_time
				_set_reaction(Reaction.NONE)
		Reaction.DEAD:
			if not _dead_on_ground and not is_airborne():
				_reach_ground_dead()
			if _dead_on_ground and not _death_finished and _reaction_time >= stats.death_blink_time:
				_death_finished = true
				_on_death_finished()


func _reach_ground_dead() -> void:
	velocity = Vector2.ZERO
	_dead_on_ground = true
	_reaction_time = 0.0


func _handle_landed() -> void:
	match reaction:
		Reaction.NONE:
			_on_landed()
		Reaction.KNOCKDOWN:
			velocity = Vector2.ZERO
			_set_reaction(Reaction.DOWN)
		Reaction.DEAD:
			_reach_ground_dead()
		_:
			velocity = Vector2.ZERO


# --- Атаки -------------------------------------------------------------------

func _tick_attack(delta: float) -> void:
	if current_attack == null:
		return
	_attack_time += delta
	_sync_hitbox()


## Хитбокс включён ровно в активное окно текущей атаки.
func _sync_hitbox() -> void:
	var is_active_phase: bool = get_attack_phase() == AttackPhase.ACTIVE
	if is_active_phase and not hitbox.is_active():
		hitbox.activate(current_attack, facing)
	elif not is_active_phase and hitbox.is_active():
		hitbox.deactivate()


func _check_hits() -> void:
	if current_attack == null or not hitbox.is_active():
		return
	var targets: Array[Actor] = hitbox.collect_hits()
	if targets.is_empty():
		return
	attack_connected = true
	var attack: AttackData = current_attack
	for target in targets:
		target.take_hit(attack, self)
	freeze(attack.hitstop)


# --- Движение и отрисовка ----------------------------------------------------

func _move_on_ground(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return
	position = _clamp_to_bounds(position + velocity * delta)


func _apply_gravity(delta: float) -> void:
	if not is_airborne():
		return
	vertical_velocity -= stats.gravity * delta
	height += vertical_velocity * delta
	if height <= 0.0:
		height = 0.0
		vertical_velocity = 0.0
		_handle_landed()
		landed.emit()


func _clamp_to_bounds(point: Vector2) -> Vector2:
	if not walk_bounds.has_area():
		return point
	return point.clamp(walk_bounds.position, walk_bounds.end)


func _update_visual() -> void:
	visual.scale.x = facing
	visual.rotation = _get_fall_rotation()
	# Лёжа прямоугольник поворачивается вокруг ног; приподнимаем его, чтобы лежал на земле.
	visual.position.y = -height - body.size.x * 0.5 * absf(sin(visual.rotation))
	hurtbox.position.y = -height
	hitbox.position.y = -height
	body.color = FLASH_COLOR if _flash_time > 0.0 else placeholder_color
	visual.visible = not _is_blinking() or fmod(_blink_clock, BLINK_PERIOD * 2.0) < BLINK_PERIOD
	_update_arm()
	var t: float = clampf(height / shadow_fade_height, 0.0, 1.0)
	shadow.scale = Vector2.ONE * lerpf(1.0, shadow_min_scale, t)
	shadow.color = Color(0.0, 0.0, 0.0, lerpf(shadow_alpha, shadow_min_alpha, t))


func _is_blinking() -> bool:
	return _invuln_time > 0.0 or (reaction == Reaction.DEAD and _dead_on_ground)


## Поворот Visual при падении: боец падает спиной от атакующего.
func _get_fall_rotation() -> float:
	var lying: float = -PI * 0.5 * facing
	match reaction:
		Reaction.KNOCKDOWN:
			return lying * clampf(_reaction_time / FALL_ROTATE_TIME, 0.0, 1.0)
		Reaction.DEAD:
			if _dead_on_ground:
				return lying
			return lying * clampf(_reaction_time / FALL_ROTATE_TIME, 0.0, 1.0)
		Reaction.DOWN:
			return lying
		Reaction.GETUP:
			return lying * (1.0 - clampf(_reaction_time / maxf(stats.getup_time, 0.001), 0.0, 1.0))
	return 0.0


## «Рука»-плейсхолдер: растёт в замахе, вытянута в активное окно, убирается в recovery.
## Координаты Visual совпадают с системой hitbox_rect (бок взгляда вправо, с учётом height).
func _update_arm() -> void:
	if current_attack == null:
		arm.visible = false
		return
	var attack: AttackData = current_attack
	var k: float = 1.0
	if _attack_time < attack.startup:
		k = _attack_time / attack.startup
	elif _attack_time >= attack.get_active_end():
		k = 1.0 - (_attack_time - attack.get_active_end()) / maxf(attack.recovery, 0.001)
	k = clampf(k, 0.0, 1.0)
	var rect: Rect2 = attack.hitbox_rect
	var base_x: float = body.position.x + body.size.x
	var full_length: float = maxf(rect.end.x - base_x, ARM_MIN_LENGTH)
	arm.visible = k > 0.0
	arm.position = Vector2(base_x, rect.get_center().y - ARM_THICKNESS * 0.5)
	arm.size = Vector2(full_length * k, ARM_THICKNESS)


func _make_ellipse(radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in SHADOW_SEGMENTS:
		var angle: float = TAU * i / SHADOW_SEGMENTS
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
