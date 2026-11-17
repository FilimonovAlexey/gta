class_name Breakable
extends Actor
## Разрушаемый предмет улицы (газетный автомат, мусорный бак). Тип целиком
## задаётся PropData (data/props/*.tres); сцена общая — scenes/props/breakable.tscn.
##
## Наследует Actor, чтобы стоять в World с y-сортировкой, иметь тень, хёртбокс
## на слое врагов (бьёт только героиня), хитстоп, вспышку и подпись отладки.
## Каждый удар снимает одну единицу прочности (урон атаки не важен) и считается
## попаданием — серия героини продолжается. На последнем ударе на месте предмета
## появляется случайный бонус из data.drops, а сам предмет отлетает (реакция DEAD),
## мигает и исчезает.
## Если у PropData есть картинка (texture_path) — вместо прямоугольника спрайт; при разрушении
## он меняется на broken_texture_path. Вспышка удара — пересвет спрайта (modulate > 1).

const GROUP: StringName = &"breakables"
## Тряска при ударе: длительность, с, и размах, px.
const SHAKE_TIME: float = 0.18
const SHAKE_AMPLITUDE: float = 5.0
## Пересвет спрайта во время вспышки.
const SPRITE_FLASH := Color(2.5, 2.5, 2.5)

## Тип предмета. Задаётся до добавления в дерево.
@export var data: PropData
## Сцена бонуса (scenes/props/pickup.tscn).
@export var pickup_scene: PackedScene

## Оставшаяся прочность (ударов до разрушения).
var durability: int = 0

var _shake_time: float = 0.0
## Спрайт предмета (null — плейсхолдер-прямоугольник).
var _sprite: Sprite2D


func _ready() -> void:
	if data == null:
		push_error("%s: не задан data (PropData)" % name)
		data = PropData.new()
	stats = data
	placeholder_color = data.placeholder_color
	team = Team.ENEMY
	shadow_radius = Vector2(data.body_size.x * 0.6, 10.0)
	super._ready()
	add_to_group(GROUP)
	durability = data.hits_to_break
	health = durability
	_apply_size()
	_setup_sprite()


func get_state_name() -> String:
	return "%s %d/%d" % [data.prop_type, durability, data.hits_to_break]


## Удар по предмету: минус единица прочности, на последнем — разрушение.
func take_hit(attack: AttackData, attacker: Actor) -> HitResult:
	if not can_be_hit():
		return HitResult.IGNORED
	durability -= 1
	health = maxi(durability, 0)
	health_changed.emit(health, data.hits_to_break)
	freeze(attack.hitstop)
	_start_flash(FLASH_COLOR, attack.hitstop)
	_shake_time = SHAKE_TIME
	if durability <= 0:
		_break_apart(attacker)
	return HitResult.HIT


func _physics_process(delta: float) -> void:
	_shake_time = maxf(_shake_time - delta, 0.0)
	super._physics_process(delta)


func _update_visual() -> void:
	super._update_visual()
	var k: float = _shake_time / SHAKE_TIME
	visual.position.x = sin(_shake_time * 90.0) * SHAKE_AMPLITUDE * k
	if _sprite != null:
		_sprite.self_modulate = SPRITE_FLASH if _flash_time > 0.0 else Color.WHITE


func _break_apart(attacker: Actor) -> void:
	_spawn_drop()
	if _sprite != null and ResourceLoader.exists(data.broken_texture_path):
		_set_sprite_texture(load(data.broken_texture_path) as Texture2D)
	var away: float = 1.0 if global_position.x >= attacker.global_position.x else -1.0
	facing = -int(away)
	_start_fall(away * 120.0, Reaction.DEAD)
	died.emit()
	print("Разбит предмет: %s" % data.prop_type)


func _spawn_drop() -> void:
	if data.drops.is_empty() or pickup_scene == null:
		return
	var pickup := pickup_scene.instantiate() as Pickup
	pickup.data = data.drops.pick_random()
	pickup.position = position
	get_parent().add_child(pickup)


## Плейсхолдер и хёртбокс под размер предмета (хёртбокс — в рост бойца, см. hurtbox_height). Форма хёртбокса — своя:
## sub_resource в actor.tscn общий для всех экземпляров.
func _apply_size() -> void:
	var size: Vector2 = data.body_size
	body.position = Vector2(-size.x * 0.5, -size.y)
	body.size = size
	var mark := get_node_or_null("Visual/FacingMark") as CanvasItem
	if mark != null:
		mark.visible = false
	var shape_node := hurtbox.get_node("Shape") as CollisionShape2D
	var rect := RectangleShape2D.new()
	var hurt_height: float = maxf(data.hurtbox_height, size.y)
	rect.size = Vector2(size.x, hurt_height)
	shape_node.shape = rect
	shape_node.position = Vector2(0.0, -hurt_height * 0.5)


## Спрайт вместо прямоугольника, если картинка предмета есть.
func _setup_sprite() -> void:
	if data.texture_path.is_empty() or not ResourceLoader.exists(data.texture_path):
		return
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	visual.add_child(_sprite)
	_set_sprite_texture(load(data.texture_path) as Texture2D)
	body.visible = false


## Картинка по высоте body_size.y, опора — низ по центру.
func _set_sprite_texture(texture: Texture2D) -> void:
	if texture == null:
		return
	_sprite.texture = texture
	var k: float = data.body_size.y / float(texture.get_height())
	_sprite.scale = Vector2(k, k)
	_sprite.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
