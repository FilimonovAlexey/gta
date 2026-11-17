# Miami Brawl (рабочее имя проекта «gta»)

Godot 4.7.2, GDScript, рендерер Compatibility (нужен веб-экспорт). Окно 1280x720,
stretch `canvas_items`, aspect `keep`, фильтр текстур Linear. Главная сцена на время
разработки — `res://scenes/level/test_street.tscn` (каркас `scenes/main/main.tscn` ждёт своего этапа). Бинарник: `/Applications/Godot.app/Contents/MacOS/Godot`.

## Игра
2D-битемап с прокруткой в духе классики жанра 90-х. Солнечный Майами в комиксном стиле.
Героиня идёт по улице, дерётся с волнами полицейских (патрульные, велопатруль, ОМОН)
и в конце уровня побеждает босса — командира спецназа. Бойцы ходят вдоль улицы и вглубь неё.
Все персонажи, названия и символика — оригинальные, ничего из чужих игр.

## Координаты и глубина
- Позиция бойца (`Node2D.position`) — точка на земле под ногами: `x` — вдоль улицы, `y` — глубина.
- Высота прыжка — отдельное поле `height: float` (>= 0), а не `position.y`.
- Спрайт — дочерний узел со смещением `-height` по y; тень остаётся на земле в `position`.
- Родитель всех бойцов — узел `World` с `y_sort_enabled = true`: кто ниже на экране, тот рисуется поверх.
- Ходить можно только в полосе улицы между `walk_top` и `walk_bottom` (по y).

## Удары
- `Hitbox` — Area2D атаки, `Hurtbox` — Area2D тела.
- Попадание засчитывается, только если области пересеклись **И** разница глубины
  `|dy| <= depth_tolerance` (по умолчанию 24 px).
- Один удар бьёт каждую цель не больше одного раза (хитбокс помнит, кого уже задел).
- Слои 2D-физики: 1 `player_hurtbox`, 2 `enemy_hurtbox`. Hurtbox лежит на слое своей команды,
  Hitbox смотрит маской на слой чужой (выставляет `Actor` по `team`) — атаки героини бьют только врагов,
  атаки врагов — только героиню.

## Архитектура
- Общий базовый класс `Actor` для героини, врагов и босса.
- Поведение — конечный автомат на `enum` внутри скрипта.
- Числа (здоровье, скорость, урон, тайминги) живут в Resource-файлах `data/*.tres`, не в коде.
- Системы общаются через сигналы и шину `Events`.
- Autoload'ы (`scripts/core/`): `Events` — шина сигналов (`player_died`, `enemy_defeated(score)`),
  `Game` — состояние игры (очки, жизни; очки за врагов уже копятся),
  `Debug` — флаг отладочной отрисовки (F1, действие `debug_toggle`) и отладочные клавиши
  (работают только при включённом F1): R — `revive_requested` (героиня воскресает),
  G — `god_mode` (бессмертие героини), 1/2/3 — `spawn_requested(index)`.

### Папки
- `scenes/{main,actors,player,enemies,boss,level,ui,fx}` — сцены.
- `scripts/{core,actors,ai,ui,level}` — скрипты (`ai` — AttackDirector; `level` — улица, камера,
  спавнер врагов, отладочный оверлей).
- `data/` — `.tres` с параметрами бойцов и уровней.
- `assets/{sprites,backgrounds,ui,fonts,audio/sfx,audio/music}` — то, что импортируется в игру.
- `art_source/` — исходные сгенерированные листы; есть `.gdignore`, в игру не импортируются.
- `tools/` — Python-скрипты (нарезка листов и т. п.).
- `builds/` — экспорт, в git не попадает.

### Input Map
| Действие | Клавиатура | Геймпад |
|---|---|---|
| move_left/right/up/down | WASD, стрелки | левый стик |
| attack | J | левая кнопка (X / квадрат) |
| jump | K | нижняя кнопка (A / крест) |
| special | L | верхняя кнопка (Y / треугольник) |
| pause | Esc | Start |
| debug_toggle | F1 | — |
| debug_revive | R (только при включённом Debug) | — |
| debug_god_mode | G (только при включённом Debug) | — |
| debug_spawn_1/2/3 | 1 / 2 / 3 (только при включённом Debug) | — |

## Плейсхолдеры
Пока нет арта, бойцы — цветные прямоугольники ростом ~180 px:
героиня — розовая, патрульный — синий, велопатруль — голубой, ОМОН — тёмно-серый, босс — чёрный.
Когда включён Debug, на каждом бойце — подпись с текущим состоянием автомата и HP,
хёртбокс (зелёный), хитбокс в активное окно (красный) и полоса допуска по глубине под ногами.
Над врагом — ромб: залитый жёлтый — у него токен атаки, контур — ждёт токена; у бессмертной героини — GOD.
Пока нет анимаций, во время атаки из прямоугольника вытягивается «рука» (`Visual/Arm`) к краю хитбокса.
Вспышка при попадании — подмена `body.color` на белый, при блоке щитом — на синий, замах врага —
мигание жёлтым (хук `Actor._get_body_color()`; со спрайтами заменить шейдером).

## Правила кода
- GDScript со статической типизацией, snake_case, комментарии на русском.
- `class_name` у каждого класса. Исключение — autoload-скрипты: их `class_name` конфликтовал бы
  с именем синглтона.
- Сторонние плагины — только по просьбе пользователя.
- `art_source/` не изменять. `.godot/` не редактировать.
- После добавления/переименования `class_name`: `godot --headless --import --path .`.
- Игра должна поддерживать пользовательский аргумент `--autoplay` (бот играет); autoplay не пишет сохранения.

### Бойцы и уровень (этап 2)
- `Actor` (`scripts/actors/actor.gd`, сцена `scenes/actors/actor.tscn`): Shadow (Polygon2D-эллипс) +
  Visual (смещение `-height`, `scale.x = facing`) → Body (ColorRect, опора внизу по центру) + FacingMark + Arm;
  Hurtbox и Hitbox (Area2D, смещение `-height`).
  Наследник переопределяет `_update_behavior()` и задаёт `velocity` (скорость по земле);
  база двигает с ограничением `walk_bounds`, считает гравитацию, вызывает `_on_landed()` / сигнал `landed`.
  Все бойцы в группе `actors`; `get_state_name()` — для отладочной подписи.
- `ActorStats` (`scripts/actors/actor_stats.gd`): `max_health`, `walk_speed_x/y`, `jump_velocity`, `gravity`, `land_time`;
  группы «Реакции на урон» и «Атаки» — см. этап 3.
  Прыжок героини: v = 600, g = 2000 → 0.6 с в воздухе, ~90 px вверх.
- `Player` (`scripts/actors/player.gd`, `scenes/player/player.tscn`, наследует actor.tscn) — см. этап 3.
- `Street` (`scripts/level/street.gd`, @tool): рисует фон, хранит `street_width`, `walk_top`, `walk_bottom`,
  раздаёт границы бойцам в дочернем `World`; `spawn_actor(actor, at)` — добавить бойца на ходу.
  `StreetCamera` — слежение только по x; `StreetCamera.get_visible_world_rect(viewport)` — видимая часть мира.
  `StreetDebugOverlay` — отрисовка по F1.
### Боёвка (этап 3)
- `AttackData` (`scripts/actors/attack_data.gd`): `name`, `damage`, `startup`/`active`/`recovery` (с),
  `hitbox_rect`, `knockback` (скорость отброса, px/с), `knockdown`, `hitstop`.
  `hitbox_rect` — в координатах бойца, смотрящего вправо: (0,0) — точка на земле, y вверх отрицательный,
  уже с учётом `height` (в прыжке поднимается вместе с бойцом), при `facing = -1` отражается по x.
- `Hitbox` / `Hurtbox` (`scripts/actors/`, узлы в `actor.tscn`, у каждого дочерний `Shape`).
  Hitbox включается только в активное окно; проверку `collect_hits()` вызывает сам Actor в конце
  `_physics_process` (попадание видно со следующего физического кадра после включения).
- `Actor`: двухуровневый автомат. Верхний уровень — реакции `Reaction` (NONE / HURT / KNOCKDOWN /
  DOWN / GETUP / DEAD), живут в базе; пока реакция не NONE, `_update_behavior()` наследника не вызывается.
  - `take_hit(attack, attacker) -> HitResult`: наследник решает в `_get_hit_response()`:
    HIT — разворот к атакующему, урон, хитстоп обоим (`freeze`), белая вспышка, реакция;
    BLOCKED — урона нет, синяя вспышка, ударившего толкает `apply_push(±_get_block_pushback())`;
    ARMORED — урон проходит, но боец не прерывается и не разворачивается (если удар его не сбивает).
    BLOCKED тоже считается контактом (`attack_connected`) — серия героини продолжается.
  - `immortal` — здоровье не опускается ниже 1 (героиня в режиме G).
  - С ног сбивают: `attack.knockdown`, попадание в воздухе, `stats.hits_to_knockdown` попаданий подряд
    (подряд = не реже `hit_chain_window`). Героиня — 3, манекены/враги — 4, чтобы серия из 4 ударов доходила до апперкота.
  - KNOCKDOWN (полёт по дуге, `knockdown_launch_velocity`) → DOWN (`down_time`) → GETUP (`getup_time`) →
    неуязвимость с миганием `getup_invuln_time`. В полёте, лёжа и при подъёме — неуязвим (без жонглирования).
  - DEAD: падение, мигание `death_blink_time`, затем `_on_death_finished()`: по умолчанию `queue_free()`,
    `Player` испускает `Events.player_died` и остаётся лежать.
  - Атаки: `start_attack(attack)` / `stop_attack()` / `get_attack_phase()` / `attack_connected`;
    база ведёт фазы, хитбокс, урон и «руку». Хуки: `_read_controls()` (каждый кадр, даже в хитстопе),
    `_on_hit_taken()`, `_on_death_finished()`. Подпись отладки — `get_display_state()`.
  - Сигналы Actor: `health_changed(current, maximum)`, `died`, `landed`.
- `Player`: IDLE / WALK / JUMP / JUMP_ATTACK / LAND / ATTACK. `combo` — массив `AttackData`
  (джеб → кросс → нога → апперкот), `jump_attack` — удар ногой в прыжке (один за прыжок).
  Серия продолжается, только если удар попал; буфер `attack_buffer_time`, следующий удар — с конца
  активного окна; `combo_reset_time` без нажатий сбрасывает серию. Разворот — только в начале удара.
- `AttackData` для щита и врагов: `guard_break` (пробивает щит спереди — апперкот и удар в прыжке),
  `lunge_speed` (рывок вперёд в активное окно, px/с).
- Героиня получает урон от врагов; здоровье и смерть пока только в выводе (`print`), без Game Over.
- `ActorHealthBar` (`scripts/ui/`) — временная полоска здоровья над врагом.

### Как добавить атаку
1. Создать `data/attacks/<боец>/<имя>.tres` с `script = attack_data.gd` (проще всего скопировать
   соседний файл) и задать числа. `hitbox_rect` подбирать с включённым F1: красный прямоугольник
   рисуется в активное окно.
2. Подключить в сцене бойца: для героини — добавить в массив `combo` или поставить в `jump_attack`
   в `scenes/player/player.tscn` (ext_resource + элемент `Array[ExtResource(...)]`).
   Для нового бойца — экспортное поле со ссылкой на `AttackData` и вызов `start_attack(attack)`
   из его автомата; конец атаки — `get_attack_phase() == AttackPhase.FINISHED` → `stop_attack()`.
3. Проверить: `-- --autoplay --debug-draw` и headless-проверка без ошибок.

## Враги (этап 4)
- `EnemyData` (`scripts/actors/enemy_data.gd`, расширяет `ActorStats`): `enemy_type`, `placeholder_color`,
  `attacks` (проводятся подряд за один заход), `attack_range`, `preferred_distance`, `aggression` (0..1),
  `score`; группа «ИИ»: `decision_interval_min/max`, `turn_delay`, `retreat_after_attack_chance`,
  `retreat_after_hit_chance`, `retreat_distance`; группа «Щит»: `has_shield`, `shield_pushback`.
- `Enemy` (`scripts/actors/enemy.gd`, общая сцена `scenes/enemies/enemy.tscn`): тип задаётся полем `data`
  до добавления в дерево. Автомат ENTER → APPROACH → WAIT → ATTACK → RETREAT:
  ENTER — выход из-за края экрана к точке `set_enter_point()`; APPROACH — к месту слева/справа от героини
  (сторона с меньшим числом врагов, ряды через `SLOT_SPACING`, обход героини по глубине);
  WAIT — держит дистанцию, переступает, просит токен; с токеном подходит на `attack_range`
  и встаёт на линию героини; ATTACK — замах мигает жёлтым, рывок `lunge_speed`;
  RETREAT — отход после атаки/удара. Решения — раз в 0.2–0.4 с со случайным разбросом;
  враги отталкиваются друг от друга; к героине разворачиваются через `turn_delay`.
  Группа `enemies`; при смерти — `Events.enemy_defeated(score)`.
- Щит (`has_shield`): спереди без `guard_break` → BLOCKED; сзади: сбивающий удар → HIT, остальные → ARMORED.
  У ОМОНа `turn_delay = 0.6` — его можно обойти и бить со спины.
- `AttackDirector` (`scripts/ai/attack_director.gd`, узел уровня, группа `attack_director`):
  одновременно атакуют не больше `max_attackers` (2). Токен получает просящий, кто дольше всех
  на экране без атаки; враг возвращает токен по концу атаки, при ударе, смерти и уходе из WAIT.
- `EnemySpawner` (`scripts/level/enemy_spawner.gd`, узел уровня): `spawn(data)` ставит врага за край экрана;
  `enemy_types` — список для клавиш 1/2/3; с `--autoplay` держит до 3 врагов, чередуя типы.
- Типы: `data/enemies/patrol.tres` (синий, дубинка: замах 0.35 с, дальность 140 > джеба, долгое восстановление),
  `bike.tres` (голубой, два удара с замахом 0.2 с, слабый, почти всегда отскакивает),
  `riot.tres` (тёмно-серый, щит, толчок щитом: замах 0.5 с, рывок, сбивает). Атаки — `data/attacks/<тип>/`.

### Как создать новый тип врага
1. Создать атаки `data/attacks/<тип>/<имя>.tres` (см. «Как добавить атаку»); для рывка задать `lunge_speed`.
2. Скопировать `data/enemies/patrol.tres` в `data/enemies/<тип>.tres`, поменять `enemy_type`,
   `placeholder_color`, здоровье/скорости, `attacks` (ext_resource + `Array[ExtResource(...)]`),
   дистанции, `aggression`, вероятности отхода, при необходимости `has_shield`.
   Новая сцена и новый скрипт не нужны.
3. Чтобы спавнить в тестовой улице — добавить `.tres` в `enemy_types` узла `EnemySpawner`
   в `scenes/level/test_street.tscn` (клавиши есть для первых трёх; больше — новое действие
   в Input Map и в `Debug.SPAWN_ACTIONS`). В коде — `spawner.spawn(load("res://data/enemies/<тип>.tres"))`.
4. Проверить с F1: подпись состояния, ромб токена, хитбоксы; `-- --autoplay --god-mode --debug-draw`.
  Особое поведение, которого нет в данных, — наследник `Enemy` с переопределением хуков
  (`_get_hit_response`, `_update_attack` и т. п.) и своей сценой, унаследованной от `enemy.tscn`.

- Экспорт-ссылки на узлы в `.tscn` требуют `node_paths=PackedStringArray(...)` в заголовке узла,
  иначе остаются null.

## Проверка
Аргументы для тестов: `-- --autoplay` (спавнер выпускает врагов, бот подходит к ближайшему, бьёт серией
и ногой в прыжке), `-- --debug-draw` (отладочная отрисовка сразу включена), `-- --god-mode` (бессмертие сразу).
Headless-итерации не равны физическим кадрам: для проверки поведения во времени добавлять `--fixed-fps 60`
(`--headless --path . --fixed-fps 60 --quit-after 3600 -- --autoplay`).

После любых изменений запускать:
```
godot --headless --path . --quit-after 300
```
(`godot` = `/Applications/Godot.app/Contents/MacOS/Godot`) и добиваться вывода без ошибок
и предупреждений скриптов.

## Статус
- [x] Этап 0 — инициализация проекта: настройки, структура папок, Input Map, заготовки autoload
  (Events, Game, Debug), пустая main.tscn, git.
- [x] Этап 2 — движение героини: Actor + ActorStats, Player (IDLE/WALK/JUMP/LAND, 8 направлений,
  прыжок без управления в воздухе), тестовая улица с манекенами, камера по x, debug-отрисовка по F1.
- [x] Этап 3 — боёвка: AttackData, Hitbox/Hurtbox с проверкой глубины и слоями команд, реакции
  HURT / KNOCKDOWN / DOWN / GETUP / DEAD, хитстоп и вспышка, серия героини из 4 ударов с буфером,
  удар ногой в прыжке, манекены со здоровьем (R — воскресить), отладочная отрисовка хит/хёртбоксов.
- [x] Этап 4 — враги: EnemyData, Enemy с ИИ (ENTER/APPROACH/WAIT/ATTACK/RETREAT), AttackDirector
  (не больше двух атакующих), патрульный, велопатруль, ОМОН со щитом (BLOCKED/ARMORED), урон героине,
  отладка: 1/2/3 — спавн, G — бессмертие, R — воскрешение героини; манекены убраны.
