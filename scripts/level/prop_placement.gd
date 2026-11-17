class_name PropPlacement
extends Resource
## Разрушаемый предмет на уровне: тип и место.

## Тип предмета (data/props/*.tres).
@export var prop: PropData
## Положение вдоль улицы, px.
@export var x: float = 0.0
## Глубина в полосе ходьбы: 0 — дальний край, 1 — ближний.
@export_range(0.0, 1.0) var depth: float = 0.5
