class_name PropData
extends ActorStats
## Тип разрушаемого предмета (газетный автомат, мусорный бак…): всё из ActorStats
## (нужны реакции — подлёт при разрушении, мигание) плюс вид, прочность и бонусы.
## Файлы — data/props/*.tres; сцена общая — scenes/props/breakable.tscn.

@export_group("Предмет")
## Тип (для подписи отладки и логов).
@export var prop_type: String = "prop"
## Цвет плейсхолдера.
@export var placeholder_color: Color = Color(0.3, 0.6, 0.9)
## Картинка целого предмета и разбитого (assets/backgrounds/breakables/…). Пока файла нет — плейсхолдер.
## Картинка подгоняется по высоте под body_size.y, опора — низ по центру.
@export_file("*.png", "*.webp") var texture_path: String = ""
@export_file("*.png", "*.webp") var broken_texture_path: String = ""
## Размер плейсхолдера (опора — внизу по центру), px.
@export var body_size: Vector2 = Vector2(60.0, 100.0)
## Высота хёртбокса, px. Выше самого предмета — в рост бойца, чтобы по низкому
## предмету попадали и удары на уровне головы (джеб, кросс).
@export var hurtbox_height: float = 170.0
## Сколько ударов выдерживает: разрушается на последнем.
@export var hits_to_break: int = 2
## Что может выпасть (одно случайное). Пусто — ничего.
@export var drops: Array[PickupData] = []
