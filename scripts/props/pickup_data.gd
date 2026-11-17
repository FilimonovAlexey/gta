class_name PickupData
extends Resource
## Бонус, выпадающий из разрушаемого предмета. Файлы — data/pickups/*.tres.

enum Kind { HEAL, SCORE }

## Что даёт: здоровье или очки.
@export var kind: Kind = Kind.HEAL
## Сколько здоровья или очков.
@export var amount: int = 30
## Имя для логов и подписи отладки.
@export var display_name: String = "pickup"
## Цвет плейсхолдера.
@export var placeholder_color: Color = Color(0.95, 0.6, 0.2)
## Размер плейсхолдера, px.
@export var size: Vector2 = Vector2(44.0, 18.0)
## Картинка бонуса (assets/backgrounds/breakables/…). Пока файла нет — плейсхолдер.
@export_file("*.png", "*.webp") var texture_path: String = ""
## Высота картинки в игре, px (ширина — по пропорциям).
@export var sprite_height: float = 40.0
