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
## Атаки: наследник вызывает start_attack(), база ведёт кадры атаки
## (AttackData.frame_durations), показывает их на спрайте и включает Hitbox по сигналу
## frame_changed на активных кадрах; наносит урон найденным целям и ставит хитстоп.
## Если анимации атаки нет — из бойца вытягивается «рука»-плейсхолдер.
##
## Вид: Visual/Sprite (ActorSprite, SpriteFrames из stats.sprite_frames_path). Реакции и атаки
## анимирует база, поведение — наследник в _animate_behavior(). Нет ни анимации, ни замены —
## на это время виден прямоугольник Body. Вспышки и мигание — общий шейдер на Visual
## (assets/shaders/actor_flash.gdshader).
##
## Попадание: take_hit() спрашивает у наследника _get_hit_response() —
## HIT (обычный урон и реакция), BLOCKED (щит: урон 0, ударившего отталкивает,
## синяя вспышка) или ARMORED (урон проходит, но боец не прерывается).

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
## Чем закончилось попадание по бойцу.
enum HitResult { IGNORED, HIT, BLOCKED, ARMORED }

## Сколько вершин у эллипса тени.
const SHADOW_SEGMENTS: int = 24
## Биты слоёв 2D-физики (имена — в project.godot, раздел layer_names).
const LAYER_PLAYER_HURTBOX: int = 1
const LAYER_ENEMY_HURTBOX: int = 2
## Полупериод мигания при неуязвимости и смерти, с.
const BLINK_PERIOD: float = 0.06
## Минимальная длительность белой вспышки при попадании, с.
const FLASH_MIN_TIME: float = 0.06
## Цвет вспышки при попадании; альфа — сила подмешивания в шейдере (flash_amount).
const FLASH_COLOR := Color(1.0, 1.0, 1.0, 0.85)
## Вспышка при блоке щитом.
const BLOCK_FLASH_COLOR := Color(0.35, 0.6, 1.0, 0.75)
## Общий шейдер вспышки и мигания.
const FLASH_SHADER: Shader = preload("res://assets/shaders/actor_flash.gdshader")
## Ходьба: минимальная скорость анимации (доля от нормальной) и скорость, с которой боец считается идущим, px/с.
const WALK_ANIM_MIN_SPEED: float = 0.4
const MOVING_SPEED: float = 5.0
## Торможение внешнего толчка (apply_push), px/с².
const PUSH_FRICTION: float = 1500.0
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
## Непрозрачность тени, когда боец стоит на земле.
@export_range(0.0, 1.0) var shadow_alpha: float = 0.35
## Непрозрачность тени на высоте shadow_fade_height и выше.
@export_range(0.0, 1.0) var shadow_min_alpha: float = 0.15
## Масштаб тени на высоте shadow_fade_height и выше.
@export_range(0.1, 1.0) var shadow_min_scale: float = 0.6
## Высота, на которой тень уменьшается и бледнеет до минимума.
@export var shadow_fade_height: float = 180.0

## Полуоси эллипса тени. Нулевые — берутся из stats.shadow_radius (наследник может задать до super._ready()).
var shadow_radius: Vector2 = Vector2.ZERO
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
## Попала ли текущая атака хотя бы по одной цели (блок щитом тоже считается).
var attack_connected: bool = false
## Бессмертие (отладка): здоровье не опускается ниже 1.
var immortal: bool = false

## Время от начала текущей атаки (без учёта хитстопа), с.
var _attack_time: float = 0.0
## Время в текущей реакции, с.
var _reaction_time: float = 0.0
## Оставшийся хитстоп, с. Пока > 0, боец замер.
var _hitstop_time: float = 0.0
## Оставшаяся вспышка и её цвет.
var _flash_time: float = 0.0
var _flash_color: Color = FLASH_COLOR
## Внешний толчок вдоль улицы (отдача от щита), px/с. Затухает сам.
var _push_speed: float = 0.0
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
## Кадр текущей атаки (-1 — атаки нет или она кончилась).
var _attack_frame: int = -1
## Пришёл ли frame_changed от спрайта при последней смене кадра атаки.
var _frame_signal_seen: bool = false
## Что показал спрайт в этот кадр (NONE — виден прямоугольник).
var _sprite_shown: ActorSprite.Shown = ActorSprite.Shown.NONE
## Материал с шейдером вспышки — свой у каждого бойца (на Visual, дети берут его через use_parent_material).
var _flash_material: ShaderMaterial

@onready var shadow: Polygon2D = $Shadow
@onready var visual: Node2D = $Visual
@onready var body: ColorRect = $Visual/Body
@onready var arm: ColorRect = $Visual/Arm
@onready var facing_mark: CanvasItem = $Visual/FacingMark
@onready var sprite: ActorSprite = $Visual/Sprite
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
	if shadow_radius == Vector2.ZERO:
		shadow_radius = stats.shadow_radius
	shadow.polygon = _make_ellipse(shadow_radius)
	_apply_hurtbox_rect(stats.hurtbox_rect)
	_flash_material = ShaderMaterial.new()
	_flash_material.shader = FLASH_SHADER
	visual.material = _flash_material
	for child in visual.get_children():
		add_to_flash_material(child as CanvasItem)
	sprite.setup(stats.sprite_frames_path, stats.animation_fallbacks)
	sprite.frame_changed.connect(_on_sprite_frame_changed)
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


## Как боец принимает удар attack от attacker. По умолчанию — обычное попадание.
func _get_hit_response(_attack: AttackData, _attacker: Actor) -> HitResult:
	return HitResult.HIT


## С какой скоростью отталкивать ударившего при блоке, px/с.
func _get_block_pushback() -> float:
	return 0.0


## Вспышка в этот кадр: rgb — цвет, a — сила (0 — нет). Наследник может добавить свои.
func _get_flash() -> Color:
	return _flash_color if _flash_time > 0.0 else Color(1.0, 1.0, 1.0, 0.0)


## Анимация поведения (реакций и атаки нет): наследник вызывает play_animation() /
## show_animation_frame() / … и возвращает их результат. По умолчанию — стойка.
func _animate_behavior() -> ActorSprite.Shown:
	return play_animation(&"idle")


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
	_attack_frame = -1
	hitbox.deactivate()
	_sync_attack_frame()


## Прервать или завершить текущую атаку.
func stop_attack() -> void:
	current_attack = null
	_attack_frame = -1
	hitbox.deactivate()


func get_attack_phase() -> AttackPhase:
	if current_attack == null:
		return AttackPhase.NONE
	if _attack_time < current_attack.get_active_start():
		return AttackPhase.STARTUP
	if _attack_time < current_attack.get_active_end():
		return AttackPhase.ACTIVE
	if _attack_time < current_attack.get_total_time():
		return AttackPhase.RECOVERY
	return AttackPhase.FINISHED


## Получить удар. Вызывается атакующим, когда его Hitbox нашёл этого бойца.
func take_hit(attack: AttackData, attacker: Actor) -> HitResult:
	if not can_be_hit():
		return HitResult.IGNORED
	var result: HitResult = _get_hit_response(attack, attacker)
	match result:
		HitResult.BLOCKED:
			_block_hit(attack, attacker)
		HitResult.ARMORED:
			_receive_hit(attack, attacker, true)
		_:
			_receive_hit(attack, attacker, false)
	return result


## Толкнуть бойца вдоль улицы со скоростью speed (со знаком), px/с; толчок затухает.
func apply_push(speed: float) -> void:
	_push_speed = speed


## Смотрит ли боец в сторону other (стоящий ровно напротив считается спереди).
func is_facing_towards(other: Node2D) -> bool:
	var dx: float = other.global_position.x - global_position.x
	return is_zero_approx(dx) or signf(dx) == float(facing)


## Время от начала текущей атаки, с.
func get_attack_time() -> float:
	return _attack_time


## Восстановить amount здоровья (не выше максимума). Мёртвых не лечит.
func heal(amount: int) -> void:
	if not is_alive() or amount <= 0:
		return
	health = mini(health + amount, stats.max_health)
	health_changed.emit(health, stats.max_health)


## Убить сразу, в обход щита и неуязвимости (отладка, клавиша N).
## Боец падает как от смертельного удара и испускает died.
func kill() -> void:
	if not is_alive():
		return
	stop_attack()
	_on_hit_taken()
	_invuln_time = 0.0
	_hitstop_time = 0.0
	health = 0
	health_changed.emit(health, stats.max_health)
	_start_fall(0.0, Reaction.DEAD)
	died.emit()


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
	_push_speed = 0.0
	_invuln_time = 0.0
	_chain_hits = 0
	_since_last_hit = INF
	position = _clamp_to_bounds(at)
	visible = true
	set_physics_process(true)
	health_changed.emit(health, stats.max_health)
	_update_visual()


## Добавить узел внутри Visual к общему шейдеру вспышки (спрайт предмета, щит…).
func add_to_flash_material(item: CanvasItem) -> void:
	if item != null:
		item.use_parent_material = true


## Виден ли сейчас спрайт (своя анимация или запасной кадр), а не прямоугольник.
func is_sprite_shown() -> bool:
	return _sprite_shown != ActorSprite.Shown.NONE


## Проиграть анимацию по кругу (stop в хитстопе — сам).
func play_animation(anim: StringName, speed: float = 1.0) -> ActorSprite.Shown:
	return sprite.play_loop(anim, speed, _hitstop_time > 0.0)


## Показать кадр index анимации anim.
func show_animation_frame(anim: StringName, index: int) -> ActorSprite.Shown:
	return sprite.show_frame(anim, index)


## Растянуть анимацию на отрезок: t — доля пройденного, 0..1.
func show_animation_progress(anim: StringName, t: float) -> ActorSprite.Shown:
	var count: int = sprite.get_own_frame_count(anim)
	return sprite.show_frame(anim, mini(int(clampf(t, 0.0, 1.0) * count), count - 1))


## Проиграть анимацию один раз с её скоростью и остаться на последнем кадре; time — с начала, с.
func show_animation_once(anim: StringName, time: float) -> ActorSprite.Shown:
	return sprite.show_frame(anim, int(time * sprite.get_own_fps(anim)))


## Ходьба со скоростью по velocity: шаг совпадает с движением (stats.walk_stride).
## Пятится (движется против взгляда) — анимация идёт назад.
func play_walk_animation() -> ActorSprite.Shown:
	var count: int = sprite.get_own_frame_count(&"walk")
	var fps: float = sprite.get_own_fps(&"walk")
	if count == 0 or fps <= 0.0:
		return play_animation(&"walk")
	# Доля от полной скорости в любом направлении: по глубине боец ходит медленнее.
	var ratio: float = Vector2(velocity.x / maxf(stats.walk_speed_x, 1.0), velocity.y / maxf(stats.walk_speed_y, 1.0)).length()
	var natural_speed: float = stats.walk_stride * fps / count
	var speed: float = maxf(ratio * stats.walk_speed_x / maxf(natural_speed, 1.0), WALK_ANIM_MIN_SPEED)
	if velocity.x * facing < -MOVING_SPEED:
		speed = -speed
	return play_animation(&"walk", speed)


## Движется ли боец по земле.
func is_moving() -> bool:
	return velocity.length() > MOVING_SPEED


# --- Реакции на урон ---------------------------------------------------------

## Урон прошёл. armored — броня: боец не прерывается и не разворачивается,
## если удар его не сбивает и не убивает.
func _receive_hit(attack: AttackData, attacker: Actor, armored: bool) -> void:
	# Куда отбрасывает: от атакующего.
	var push_dir: int = 1 if global_position.x >= attacker.global_position.x else -1
	health = maxi(health - attack.damage, 1 if immortal else 0)
	health_changed.emit(health, stats.max_health)
	_chain_hits = _chain_hits + 1 if _since_last_hit <= stats.hit_chain_window else 1
	_since_last_hit = 0.0
	freeze(attack.hitstop)
	_start_flash(FLASH_COLOR, attack.hitstop)
	var falls: bool = attack.knockdown or is_airborne() or _chain_hits >= stats.hits_to_knockdown
	if armored and health > 0 and not falls:
		return
	# Лицом боец поворачивается к атакующему.
	facing = -push_dir
	stop_attack()
	_on_hit_taken()
	var push_speed: float = push_dir * attack.knockback
	if health == 0:
		_start_fall(push_speed, Reaction.DEAD)
		died.emit()
	elif falls:
		_start_fall(push_speed, Reaction.KNOCKDOWN)
	else:
		_set_reaction(Reaction.HURT)
		_hurt_push_speed = push_speed
		velocity = Vector2(push_speed, 0.0)


## Удар принят щитом: урона нет, ударившего отталкивает назад.
func _block_hit(attack: AttackData, attacker: Actor) -> void:
	freeze(attack.hitstop)
	_start_flash(BLOCK_FLASH_COLOR, attack.hitstop)
	var away: int = 1 if attacker.global_position.x >= global_position.x else -1
	attacker.apply_push(away * _get_block_pushback())


func _start_flash(color: Color, duration: float) -> void:
	_flash_color = color
	_flash_time = maxf(duration, FLASH_MIN_TIME)


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
	_sync_attack_frame()


## Перейти на кадр атаки по таймлайну. Если у спрайта есть анимация атаки, кадр ставится
## на спрайт, и хитбокс переключает его сигнал frame_changed; иначе — напрямую.
func _sync_attack_frame() -> void:
	var index: int = current_attack.get_frame_at(_attack_time)
	if index == _attack_frame:
		return
	_attack_frame = index
	_frame_signal_seen = false
	var anim: StringName = current_attack.animation
	if index >= 0 and sprite.has_own(anim):
		sprite.show_frame(anim, index)
	if not _frame_signal_seen:
		_apply_attack_frame(index)


func _on_sprite_frame_changed() -> void:
	if current_attack == null or sprite.animation != current_attack.animation:
		return
	if not sprite.has_own(current_attack.animation):
		return
	_frame_signal_seen = true
	_apply_attack_frame(sprite.frame)


## Хитбокс включён ровно на активных кадрах атаки.
func _apply_attack_frame(index: int) -> void:
	var is_active_frame: bool = index >= 0 and current_attack != null and current_attack.is_active_frame(index)
	if is_active_frame and not hitbox.is_active():
		hitbox.activate(current_attack, facing)
	elif not is_active_frame and hitbox.is_active():
		hitbox.deactivate()


func _check_hits() -> void:
	if current_attack == null or not hitbox.is_active():
		return
	var targets: Array[Actor] = hitbox.collect_hits()
	if targets.is_empty():
		return
	var attack: AttackData = current_attack
	var connected: bool = false
	for target in targets:
		if target.take_hit(attack, self) != HitResult.IGNORED:
			connected = true
	if connected:
		attack_connected = true
		freeze(attack.hitstop)


# --- Движение и отрисовка ----------------------------------------------------

func _move_on_ground(delta: float) -> void:
	var motion: Vector2 = velocity + Vector2(_push_speed, 0.0)
	_push_speed = move_toward(_push_speed, 0.0, PUSH_FRICTION * delta)
	if motion == Vector2.ZERO:
		return
	position = _clamp_to_bounds(position + motion * delta)


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
	_sprite_shown = _update_animation()
	var drawn_by_sprite: bool = _sprite_shown != ActorSprite.Shown.NONE
	sprite.visible = drawn_by_sprite
	body.visible = not drawn_by_sprite
	facing_mark.visible = not drawn_by_sprite
	# Падение рисует своя анимация knockdown; без неё боец (прямоугольник или запасной кадр) поворачивается.
	visual.rotation = 0.0 if _sprite_shown == ActorSprite.Shown.FRAMES and reaction != Reaction.NONE else _get_fall_rotation()
	# Лёжа фигура поворачивается вокруг ног; приподнимаем её, чтобы лежала на земле.
	visual.position.y = -height - body.size.x * 0.5 * absf(sin(visual.rotation))
	hurtbox.position.y = -height
	hitbox.position.y = -height
	var flash: Color = _get_flash()
	_flash_material.set_shader_parameter(&"flash_color", Color(flash, 1.0))
	_flash_material.set_shader_parameter(&"flash_amount", flash.a)
	var hidden: bool = _is_blinking() and fmod(_blink_clock, BLINK_PERIOD * 2.0) >= BLINK_PERIOD
	_flash_material.set_shader_parameter(&"alpha", 0.0 if hidden else 1.0)
	_update_arm()
	var t: float = clampf(height / shadow_fade_height, 0.0, 1.0)
	shadow.scale = Vector2.ONE * lerpf(1.0, shadow_min_scale, t)
	shadow.color = Color(0.0, 0.0, 0.0, lerpf(shadow_alpha, shadow_min_alpha, t))


## Выбрать кадр спрайта: реакция → атака → поведение наследника.
func _update_animation() -> ActorSprite.Shown:
	if not sprite.is_ready():
		return ActorSprite.Shown.NONE
	match reaction:
		Reaction.HURT:
			return show_animation_progress(&"hurt", _reaction_time / maxf(stats.hurt_time, 0.001))
		Reaction.KNOCKDOWN:
			return show_animation_frame(&"knockdown", 0 if vertical_velocity > 0.0 else 1)
		Reaction.DOWN:
			return show_animation_frame(&"knockdown", 99)
		Reaction.GETUP:
			return show_animation_progress(&"getup", _reaction_time / maxf(stats.getup_time, 0.001))
		Reaction.DEAD:
			if _dead_on_ground:
				return show_animation_frame(&"knockdown", 99)
			return show_animation_frame(&"knockdown", 0 if vertical_velocity > 0.0 else 1)
	if current_attack != null and current_attack.animation != &"":
		# Кадр ставит _sync_attack_frame; кончилась атака — держим последний.
		var index: int = _attack_frame if _attack_frame >= 0 else current_attack.get_frame_count() - 1
		return show_animation_frame(current_attack.animation, index)
	return _animate_behavior()


## Прямоугольник хёртбокса (см. ActorStats.hurtbox_rect). Форма — своя у каждого бойца.
func _apply_hurtbox_rect(rect: Rect2) -> void:
	var shape_node := hurtbox.get_node("Shape") as CollisionShape2D
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	shape_node.shape = shape
	shape_node.position = rect.get_center()


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


## «Рука»-плейсхолдер (только если своей анимации атаки нет): растёт в замахе,
## вытянута в активное окно, убирается в восстановлении.
## Координаты Visual совпадают с системой hitbox_rect (бок взгляда вправо, с учётом height).
func _update_arm() -> void:
	if current_attack == null or (_sprite_shown == ActorSprite.Shown.FRAMES and reaction == Reaction.NONE):
		arm.visible = false
		return
	var attack: AttackData = current_attack
	var start: float = attack.get_active_start()
	var end: float = attack.get_active_end()
	var k: float = 1.0
	if _attack_time < start:
		k = _attack_time / maxf(start, 0.001)
	elif _attack_time >= end:
		k = 1.0 - (_attack_time - end) / maxf(attack.get_total_time() - end, 0.001)
	k = clampf(k, 0.0, 1.0)
	var rect: Rect2 = attack.hitbox_rect
	var base_x: float = stats.hurtbox_rect.end.x if is_sprite_shown() else body.position.x + body.size.x
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
