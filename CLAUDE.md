# Miami Brawl (рабочее имя проекта «gta»)

Godot 4.7.2, GDScript, рендерер Compatibility (нужен веб-экспорт). Окно 1280x720,
stretch `canvas_items`, aspect `keep`, фильтр текстур Linear. Главная сцена —
`res://scenes/level/level.tscn` (строит текущий уровень из `Game`, с начала — тюремный корпус);
`scenes/level/test_street.tscn` — отладочная улица без замков
(запуск: `godot --path . res://scenes/level/test_street.tscn`);
`scenes/level/level_preview.tscn` — снимки фонов всех уровней (см. «Проверка»);
каркас `scenes/main/main.tscn` ждёт своего этапа. Бинарник: `/Applications/Godot.app/Contents/MacOS/Godot`.

## Игра
2D-битемап с прокруткой в духе классики жанра 90-х, Майами в комиксном стиле.
Сюжет: героиня в оранжевой робе бежит из тюрьмы Майами. По пути дерётся с волнами полицейских
(патрульные, велопатруль, ОМОН), в финале — с боссом, командиром спецназа.
Бойцы ходят вдоль улицы и вглубь неё. Все персонажи, названия и символика — оригинальные,
ничего из чужих игр.

Пять уровней по порядку (`Game.LEVELS`, файлы `data/levels/<код>.tres`):
1. `cellblock` — тюремный корпус, ночь (CELLBLOCK);
2. `yard` — двор и периметр, прожекторы (THE YARD);
3. `everglades` — дорога через болота (EVERGLADES);
4. `ocean_drive` — неоновая улица (OCEAN DRIVE);
5. `port` — порт на рассвете, финальный босс (THE PORT).
На уровнях 1–4 в конце арена с усиленной финальной волной копов («FINAL WAVE»), после неё
«STAGE CLEAR» и следующий уровень (очки и жизни сохраняются). Босс — только в порту (пока заглушка).

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
- Autoload'ы (`scripts/core/`): `Events` — шина сигналов (`player_died`, `enemy_defeated(score)`,
  `pickup_collected(data, collector)`, `segment_started(i)`, `wave_started(seg, wave)`,
  `segment_cleared(i)`, `boss_arena_reached`, `level_cleared`),
  `Game` — состояние игры (очки, жизни, текущий уровень `level_index`; копятся очки за врагов
  и бонусы-деньги; `get_current_level_data()`, `load_level(i)`, `next_level()`; аргумент `--level=N`),
  `Debug` — флаг отладочной отрисовки (F1, действие `debug_toggle`) и отладочные клавиши
  (работают только при включённом F1): R — `revive_requested` (героиня воскресает),
  G — `god_mode` (бессмертие героини), 1/2/3 — `spawn_requested(index)`,
  N — `kill_all_requested` (убить всех врагов на экране; слушает `LevelDirector`),
  F2–F6 — `level_requested(index)` (открыть уровень 1–5; слушает `Game`).

### Папки
- `scenes/{main,actors,player,enemies,boss,level,props,ui,fx}` — сцены (`props` — предметы и бонусы).
- `assets/shaders/` — шейдеры (`actor_flash.gdshader` — вспышка и мигание бойцов).
- `scripts/{core,actors,ai,ui,level,props}` — скрипты (`ai` — AttackDirector; `level` — уровень, данные
  уровня, улица, камеры, параллакс, спавнер, директор волн, отладочный оверлей; `props` — предметы и бонусы;
  `ui` — полоска здоровья, HUD уровня).
- `data/` — `.tres`: `player_stats`, `attacks/`, `enemies/`, `props/`, `pickups/`, `levels/`.
- `assets/{sprites,backgrounds,ui,fonts,audio/sfx,audio/music}` — то, что импортируется в игру
  (`assets/backgrounds/` — см. «Ассеты»).
- `art_source/` — исходные сгенерированные картинки; есть `.gdignore`, в игру не импортируются (см. «Ассеты»).
- `tools/` — Python-скрипты: `organize_inbox.py` (раскладка `_inbox`), `process_backgrounds.py` (фоны → assets),
  `slice_sheets.py` (листы персонажей → кадры и SpriteFrames, см. «Арт»), `imgutil.py` (общее: хромакей,
  поиск фигур), `build_sprite_frames.gd` (сборка SpriteFrames в Godot headless, зовёт slice_sheets),
  `make_levels.py` (генератор `data/levels/*.tres`), `floor_lines.json` (линии пола, пишет process_backgrounds).
  `tools/preview/` — временные превью и отчёты, в git не попадают (есть `.gdignore`).
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
| debug_kill_all | N (только при включённом Debug) | — |
| debug_level_1..5 | F2–F6 (только при включённом Debug) | — |

## Плейсхолдеры
Бойцы рисуются спрайтами (этап 7). Цветной прямоугольник ростом ~180 px остаётся запасным видом —
на состояние, для которого нет ни анимации, ни замены (см. «Арт в игре»):
героиня — розовая, патрульный — синий, велопатруль — голубой, ОМОН — тёмно-серый, босс — чёрный.
Когда включён Debug, на каждом бойце — подпись с текущим состоянием автомата и HP,
хёртбокс (зелёный), хитбокс в активное окно (красный) и полоса допуска по глубине под ногами.
Над врагом — ромб: залитый жёлтый — у него токен атаки, контур — ждёт токена; у бессмертной героини — GOD.
Если у атаки нет своей анимации, из бойца вытягивается «рука» (`Visual/Arm`) к краю хитбокса.
Вспышки — общий шейдер (см. «Арт в игре»): белая при попадании, синяя при блоке щитом, замах врага мигает жёлтым.

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
  Visual (смещение `-height`, `scale.x = facing`) → Body (ColorRect, опора внизу по центру) + Sprite (ActorSprite) + FacingMark + Arm;
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
- `AttackData` (`scripts/actors/attack_data.gd`): `name`, `damage`, `animation`, `frame_durations` (с на кадр),
  `active_frames` (номера кадров с 0, на которых включён хитбокс), `hitbox_rect`, `knockback` (скорость отброса, px/с),
  `knockdown`, `hitstop`. Фазы STARTUP/ACTIVE/RECOVERY считаются по кадрам (`get_active_start/end()`, `get_total_time()`).
  `hitbox_rect` — в координатах бойца, смотрящего вправо: (0,0) — точка на земле, y вверх отрицательный,
  уже с учётом `height` (в прыжке поднимается вместе с бойцом), при `facing = -1` отражается по x.
- `Hitbox` / `Hurtbox` (`scripts/actors/`, узлы в `actor.tscn`, у каждого дочерний `Shape`).
  Hitbox включается только на активных кадрах (по `frame_changed` спрайта); проверку `collect_hits()` вызывает сам Actor в конце
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
    база ведёт кадры атаки, хитбокс, урон и «руку». Хуки: `_read_controls()` (каждый кадр, даже в хитстопе),
    `_on_hit_taken()`, `_on_death_finished()`. Подпись отладки — `get_display_state()`.
  - Сигналы Actor: `health_changed(current, maximum)`, `died`, `landed`.
- `Player`: IDLE / WALK / JUMP / JUMP_ATTACK / LAND / ATTACK / PICKUP / VICTORY. `combo` — массив `AttackData`
  (джеб → кросс → нога → апперкот), `jump_attack` — удар ногой в прыжке (один за прыжок).
  Серия продолжается, только если удар попал; буфер `attack_buffer_time`, следующий удар — с конца
  активного окна; `combo_reset_time` без нажатий сбрасывает серию. Разворот — только в начале удара.
- `AttackData` для щита и врагов: `guard_break` (пробивает щит спереди — апперкот и удар в прыжке),
  `lunge_speed` (рывок вперёд в активное окно, px/с).
- Героиня получает урон от врагов; здоровье и смерть пока только в выводе (`print`), без Game Over.
- `ActorHealthBar` (`scripts/ui/`) — временная полоска здоровья над врагом.

### Как добавить атаку
1. Создать `data/attacks/<боец>/<имя>.tres` с `script = attack_data.gd` (проще всего скопировать
   соседний файл) и задать числа: `animation` — имя анимации в SpriteFrames бойца, `frame_durations` —
   по числу на кадр (замах длиннее, удар короткий), `active_frames` — кадры удара (обычно `PackedInt32Array(1)`).
   `hitbox_rect` подбирать с включённым F1 по кулаку/стопе на активном кадре (красный прямоугольник
   рисуется, пока хитбокс включён; замеры кадров — по альфе png в `assets/sprites/<персонаж>/`, ×0.5 от опоры).
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

## Уровень (этап 5)
- `LevelData` (`scripts/level/level_data.gd`, файлы `data/levels/<код>.tres`): `level_id`, `display_name`,
  `level_length`, `walk_top`/`walk_bottom`, `player_start`, `segments`, `layers` (параллакс),
  `arena_texture_path` (фон арены), `props` (предметы).
  Вложенные ресурсы (по классу на файл в `scripts/level/`): `LevelSegment` (`lock_x` — x **центра камеры**
  в замке, экран = `lock_x ± 640`; `waves`; `is_boss_arena` + `banner_text`), `WaveData` (`spawns`),
  `WaveSpawn` (`enemy`, `side` LEFT/RIGHT, `depth` 0..1 — 0 дальний край полосы, `delay` от начала волны),
  `PropPlacement` (`prop`, `x`, `depth`), `BackgroundLayerData` (см. «Фоны»).
  Волны/спавны — sub_resource'ы внутри `.tres`. Все пять файлов генерирует `tools/make_levels.py`
  (таблицы волн, предметов, слоёв и плейсхолдеров — там; править их и перезапускать скрипт).
- `Level` (`scripts/level/level.gd`, `scenes/level/level.tscn`): в `_enter_tree` берёт LevelData у `Game`
  (экспортное `level_data` — запасное), отдаёт его `LevelDirector` и делает `Street.configure()`
  (длина и полоса; `Street.draw_background = false`, фон рисуют слои). `Level.build_backdrop(data, back, front)`
  (статическая, ей же пользуется предпросмотр) строит слои в `Background` (за бойцами) и `Foreground`
  (перед ними: идёт в дереве после `Street`) и фон арены; дальше — героиня и предметы.
- `BeatCamera` (`scripts/level/beat_camera.gd`): центр = героиня + `look_ahead`, едет только вправо;
  не дальше `stop_x`; доехав — `locked`, сигнал `stop_reached`; `release(next_stop_x)` снимает замок.
  Каждый кадр выдаёт героине `set_walk_bounds` = полоса улицы ∩ экран (отступ `screen_margin`) —
  уйти за левый край нельзя никогда, в замке она заперта в экране. Враги ходят в границах всей улицы.
- `LevelDirector` (`scripts/level/level_director.gd`): сегменты по очереди. Замок → волна 1 сразу;
  следующая волна — когда все спавны текущей вышли и живых врагов ≤ `next_wave_threshold` (1);
  сегмент пройден — все волны вышли и живых 0 → `release`, «GO →» (гаснет через 300 px езды или в новом замке).
  Последний сегмент без босса — арена с баннером «FINAL WAVE»; зачищена → «STAGE CLEAR»,
  `Events.level_cleared`, через 2.5 с `Game.next_level()`. Арена босса (только порт) — замок
  с баннером «BOSS — TODO», не снимается. В начале уровня на 2 с — баннер «STAGE N — <название>».
- `EnemySpawner.spawn(data, side, depth)`: side 1/-1/0 (0 — случайно), depth 0..1 (< 0 — случайно);
  `autoplay_spawning = false` в уровне (волнами управляет директор).
- Враги выбирают сторону ожидания так, чтобы место было на экране (`Enemy._is_wait_x_ok`).
- `LevelHud` (`scripts/ui/level_hud.gd`, CanvasLayer): `show_go()/hide_go()`, `show_banner(text)/hide_banner()`,
  `flash_banner(text, time)`.
- `Actor.heal(amount)`, `Actor.kill()` (смерть в обход щита — для клавиши N).
- Раскладка всех уровней пока одна (длина 8000): замки 1500 / 2900 / 4300 / 5800, арена 7360
  (последний замок = длина − 640); 8 предметов (ящик и бак, на Ошен-драйв — газетный автомат и бак).

### Предметы и бонусы
- `PropData` (`scripts/props/prop_data.gd`, расширяет `ActorStats`; `data/props/crate.tres`, `trash_bin.tres`,
  `newspaper_box.tres`): `prop_type`, `placeholder_color`, `texture_path` / `broken_texture_path` (картинка
  целого и разбитого; подгоняется по высоте под `body_size.y`, опора — низ по центру; нет файла — прямоугольник),
  `body_size`, `hurtbox_height` (хёртбокс в рост бойца, чтобы по низкому предмету попадали джеб и кросс),
  `hits_to_break` (2), `drops` (одно случайное).
- `Breakable` (`scripts/props/breakable.gd`, `scenes/props/breakable.tscn`, наследует `actor.tscn`): команда
  ENEMY (бьёт только героиня), группа `breakables`; `take_hit` — минус единица прочности, вспышка, тряска,
  засчитывается попаданием; на последнем — бонус на месте предмета, предмет отлетает (DEAD) и исчезает.
- `PickupData` (`scripts/props/pickup_data.gd`; `data/pickups/hot_dog.tres` — HEAL +30, `cash.tres` — SCORE +500):
  `texture_path`, `sprite_height` — картинка бонуса (нет файла — прямоугольник).
- `Pickup` (`scripts/props/pickup.gd`, `scenes/props/pickup.tscn`): Node2D в World (y-сортировка), группа
  `pickups`; `collect(actor)` — лечит или шлёт `Events.pickup_collected` (очки начисляет `Game`).
- Подбор: `Player` в IDLE/WALK по attack сначала ищет бонус (`|dx| ≤ pickup_range_x`,
  `|dy| ≤ pickup_depth_tolerance`) → состояние PICKUP (`pickup_time`, плейсхолдер приседает) вместо удара.
  Поля — группа «Подбор» в `ActorStats`.
- Бот (`--autoplay`) замечает только цели на экране (враги и предметы); без врагов идёт к бонусам;
  без целей бредёт вправо — так проходит уровень до арены босса (~16 000 физкадров).

## Фоны
Слои параллакса задаются в `LevelData.layers` (`BackgroundLayerData`: `name`, `scroll_scale`, `texture_paths`,
`in_front`, `placeholder_style`, `placeholder_color`; группа «Декор»: `scatter`, `scatter_step_min/max`,
`scatter_baseline`, `scatter_seed`) и строятся `BackgroundLayer` (`scripts/level/background_layer.gd`,
наследует `Parallax2D`). Из `texture_paths` берутся только существующие файлы; нет ни одного — плейсхолдер
(`NONE` — ничего, `SOLID` — заливка, `PLAIN` — простая стена и пол, `SKY/FAR/MID/STREET/FRONT` — закатный Майами).

| Слой | Файлы в `assets/backgrounds/<уровень>/` | scroll | Как строится |
|---|---|---|---|
| Sky | `sky.png` | 0.05 | непрозрачная панорама неба / задней стены, повтор |
| Far | `far.png` | 0.2 | дальний план с прозрачностью, повтор |
| Mid | `mid.png` | 0.5 | средний план с прозрачностью, повтор |
| Main | `main_a.png`, `main_b.png`, `main_c.png` | 1.0 | идут подряд a → b → c, полоса повторяется по длине уровня |
| Props | `props_01.png` … `props_06.png` | 1.25, перед бойцами | декор по одному с шагом 500–900 px, низ на y 720 |
| Arena | `arena.png` | 1.0 | кадр 1280x720 на месте последнего замка (lock_x ± 640), поверх Main |

- Все слои — **720 px в высоту** (их готовит `tools/process_backgrounds.py`), бесшовные по горизонтали.
  Верх картинки = верх экрана (y 0), камера по y не двигается.
- `walk_top` уровня = линия пола на `main_a` + 15 px (линию находит process_backgrounds, пишет в
  `tools/floor_lines.json`, берёт make_levels); `walk_bottom` = 695. Для уровней без арта — 430 / 680.
  cellblock: пол с y 419 → полоса 434–695.
- Разрушаемые предметы и бонусы — `assets/backgrounds/breakables/{trash_can,trash_can_broken,crate,crate_broken,hotdog,cash}.png`;
  титульник — `assets/backgrounds/title.png` (титульного экрана пока нет).

## Ассеты (этап 6.0)
- `art_source/` — оригиналы из нейросети (в игру не импортируются, не изменять):
  - `<персонаж>/` — `heroine`, `patrol`, `bike`, `riot`, `boss`: `anchor.png` (одна фигура на зелёном; у героини
    `anchor.jpg`) и листы 3x2 на зелёном, имя = код листа. Героиня: H1 стойка, H2 ходьба, H3 джеб + кросс,
    H4 апперкот + удар ногой, H5 прыжок + удар в прыжке, H6 урон + падение, H7 подъём + победа.
    Копы и босс: E1 ходьба, E2 стойка + атака, E3 урон + падение; босс ещё B1 рывок + удар по земле, B2 ярость + поражение.
  - `backgrounds/<уровень>/` — `sky`, `far`, `mid`, `main_a/b/c`, `props` (лист 3x2 декора), `arena`;
    `backgrounds/title.png`, `backgrounds/breakables.png` (лист: бак, бак разбитый, ящик, ящик разбитый, хот-дог, деньги).
    Варианты main по уровням: cellblock — камеры / будка охраны и шкафчики / столовая; yard — баскетбольное кольцо /
    мастерская с воротами / КПП со шлагбаумом; everglades — дорога с отбойником / прокат глиссеров / блокпост;
    ocean_drive — отели и кафе / ночной клуб / угол с кабриолетом; port — контейнеры и погрузчик / склад / край пирса.
    Ключ у слоёв без альфы — пурпурный #FF00FF (у ocean_drive — зелёный #00FF00).
  - `_inbox/` — сюда кладутся новые картинки со случайными именами; `_alternates/` — запасные варианты (`_v2`, `_v3`);
    `_unsorted/` — неопознанное; `manifest.csv` — журнал переименований (исходное имя → новый путь, размер, заметки).
- Как добавить картинку: положить в `art_source/_inbox/` → опознать (превью 512 px в `tools/preview/inbox/`,
  проверки: 6 фигур, все смотрят вправо, один персонаж, однотонный фон, без текста; у фонов — без людей и текста,
  пустой пол, прозрачность или чистый ключ) → вписать в `PLAN` в `tools/organize_inbox.py` и запустить его
  (только перемещает; занятое имя уходит в `_alternates`; дописывает `manifest.csv`) →
  для фонов `python3 tools/process_backgrounds.py [уровень]` → `godot --headless --import --path .`.
  Если поменялась линия пола main_a — `python3 tools/make_levels.py`. `.tres` править не нужно: пути уже прописаны.
- Спрайты персонажей нарезаны (этап 6.1, см. «Арт») и подключены к бойцам (этап 7, см. «Арт в игре»).

## Арт (этап 6.1): нарезка спрайтов
`python3 tools/slice_sheets.py [персонаж ...] [--no-godot]` — листы `art_source/<персонаж>/<лист>.png`
(1536x1024, сетка 3x2, кадры 1..6 слева направо и сверху вниз, фон #00FF00, персонаж смотрит вправо) →
`assets/sprites/<персонаж>/<анимация>_<NN>.png` + `assets/sprites/<персонаж>/<персонаж>.tres` (SpriteFrames).
Нужны Pillow и numpy. Перезапуск безопасен: старые png персонажа удаляются, `.tres` пересобирается.
- Конфиг `art_source/animations.json`: `defaults` (fps 12, loop false, `display_scale` 0.5, `baseline_margin`,
  `torso_band`, `height_tolerance`, `key`) и `characters.<персонаж>`: `target_height` (высота фигуры стойки в px кадра:
  героиня и копы 360, ОМОН 400, босс 440), `frame_size`, `scale_sheet` (+ `scale_fallback`), `offsets`
  (`"<лист>:<номер>": [dx, dy]` — ручной сдвиг кадра), `animations` (`name`, `sheet`, `frames` — номера на листе,
  можно в обратном порядке, `fps`, `loop`, `free_height` — высота законно меняется: присед, падение).
  У врагов `getup` = кадры E3 6,5,4 (отдельного листа подъёма нет).
- Шаги: хромакей `imgutil.chroma_key` (фон по HSV с допуском → жёсткая маска; в полосе 1–2 px у контура альфа
  восстанавливается по примеси ключа, там же despill) → `imgutil.find_figures` по связным областям альфы
  (мелкие куски — волосы, кепка — приклеиваются к ближайшей фигуре; порядок по строкам, затем по x;
  не 6 фигур — ошибка с именем файла, лист пропускается, код выхода 1) → один масштаб на персонажа
  (`target_height` / средняя высота фигур листа стойки; нет листа стойки — по `scale_fallback` с предупреждением)
  → низ фигуры на базовой линии, по x опора — центр торса (медиана центров масс строк в полосе 35–65% высоты,
  а не центр рамки: вытянутая рука или нога не сдвигают корпус) → `offsets`.
- Опора в кадре — `(frame_w / 2, frame_h − baseline_margin)`. В `.tres` метаданные: `frame_size`, `pivot`,
  `display_scale`, `sprite_offset` — offset для `AnimatedSprite2D` (`centered = true`), чтобы опора совпала с точкой
  на земле бойца; спрайт показывать со `scale = display_scale` (0.5 → героиня 180 px, как плейсхолдер).
- SpriteFrames собирает Godot: `godot --headless --import`, затем `--script res://tools/build_sprite_frames.gd -- --spec=…`
  (путь к Godot — переменная `GODOT`; без Godot — `--no-godot`, только png).
- Контроль (в `tools/preview/`): `<персонаж>_sheet.png` — все кадры по анимациям, красная базовая линия, синяя ось опоры,
  подозрительные в оранжевой рамке; `<персонаж>_<анимация>.gif`; отчёт `slice_report.txt` (он же в консоли):
  листы, число фигур и высоты, масштаб, пропущенные листы и анимации, подозрительные кадры (высота отличается
  от стойки больше чем на 25% без `free_height`, фигура касается края холста, не влезает в кадр).
- Отсутствующий лист — предупреждение, его анимации не попадают в `.tres`. Сейчас есть: героиня H1–H7 (все 12 анимаций),
  у копов и босса только E1 (`walk`); масштаб врагов пока по ходьбе — после появления E2 перезапустить скрипт.
- Новый лист: положить через `_inbox` (см. «Ассеты») → `python3 tools/slice_sheets.py <персонаж>` → посмотреть превью
  и отчёт → при необходимости `offsets` / `frame_size` в конфиге и перезапуск.

## Арт в игре (этап 7)
- `ActorStats` (группа «Спрайт»): `sprite_frames_path` (SpriteFrames из slice_sheets), `animation_fallbacks`
  (`"анимация": "другая:кадр"` — стоп-кадр вместо недостающей), `walk_stride` (px пути за цикл walk);
  группа «Тело»: `hurtbox_rect` (в координатах бойца, смотрящего вправо), `shadow_radius`; «Победа»: `victory_time`.
- `ActorSprite` (`scripts/actors/actor_sprite.gd`, узел `Visual/Sprite`): грузит SpriteFrames, масштаб и смещение — из
  метаданных `.tres` (`display_scale`, `sprite_offset`). **Масштаб всех персонажей — одно место:** `display_scale`
  в `art_source/animations.json` → `python3 tools/slice_sheets.py`. `show_frame()` / `play_loop()` возвращают
  `Shown`: FRAMES (своя анимация), FALLBACK (стоп-кадр замены), NONE (рисуется прямоугольник Body).
  О каждой недостающей анимации — одно предупреждение `Спрайт <персонаж>: нет анимации …` за запуск.
- Состояния → анимации (имена как в `animations.json`). База (`Actor._update_animation`): HURT — `hurt` на `hurt_time`;
  KNOCKDOWN — `knockdown` кадр 0 на взлёте, 1 на спуске; DOWN и мёртвый на земле — последний кадр; GETUP — `getup`
  на `getup_time` (у копов — E3 6,5,4, обратная knockdown); атака — кадры `AttackData`. Поворот Visual при падении —
  только без своей анимации knockdown. Поведение — `_animate_behavior()` наследника: Player — idle, walk, jump
  (0 — отталкивание `JUMP_TAKEOFF_TIME`, 1 — весь полёт, 2 — LAND), pickup (замена `uppercut:0`), victory;
  Enemy — walk на ходу, idle стоя. Помощники: `play_animation`, `play_walk_animation` (скорость = движение /
  `walk_stride`, пятясь — задом наперёд, не меньше 0.4), `show_animation_frame/progress/once`.
- Атаки: `Actor._sync_attack_frame()` ведёт кадр по времени атаки и ставит его на спрайт → `frame_changed` →
  `_apply_attack_frame()` включает/выключает Hitbox. Нет своей анимации — тот же обработчик вызывается напрямую.
  Хитстоп: время атаки не идёт, зацикленные анимации на паузе.
- Шейдер `assets/shaders/actor_flash.gdshader` (`flash_color`, `flash_amount`, `alpha`): свой ShaderMaterial на `Visual`,
  дети берут его через `use_parent_material` (`Actor.add_to_flash_material(node)` для узлов, добавленных кодом —
  щит, картинка предмета). Хук `Actor._get_flash() -> Color` (rgb — цвет, a — сила): попадание белое 0.85, блок синий
  0.75 (на ОМОНе), замах врага жёлтый 0.6 (Enemy). Неуязвимость и смерть мигают через `alpha`.
- `Player` VICTORY: по `Events.segment_cleared` (снят замок, в т.ч. финальная арена); если героиня бьёт или в воздухе —
  ждёт до 1.5 с, пока освободится; движение/удар/прыжок прерывают после 0.3 с.
- Тела по спрайтам (×0.5 от опоры): героиня хёртбокс 52x182, тень 42x12; patrol 52x180; bike 44x180; riot 112x200
  (вместе со щитом), тень 60x16. Полоска здоровья врага и подпись F1 — над верхом хёртбокса.
- Пока у копов только `walk`: в `data/enemies/*.tres` замены idle/attack/hurt/knockdown/getup → `walk:0`
  (атака — с «рукой» и жёлтым замахом, падение — повёрнутым кадром). Появятся листы E2/E3 → `slice_sheets.py` —
  анимации подхватятся сами, замены можно удалить; `hitbox_rect` атак копов подогнать по кадру удара.

## Проверка
Аргументы для тестов: `-- --autoplay` (бот подходит к ближайшей цели на экране, бьёт серией
и ногой в прыжке, подбирает бонусы; в test_street спавнер сам выпускает врагов, в уровне — волны директора),
`-- --debug-draw` (отладочная отрисовка сразу включена), `-- --god-mode` (бессмертие сразу),
`-- --level=N` (начать с уровня N = 1..5).
Headless-итерации не равны физическим кадрам: для проверки поведения во времени добавлять `--fixed-fps 60`
(`--headless --path . --fixed-fps 60 --quit-after 3600 -- --autoplay`).
Полный проход уровня ботом (в логе «Сегмент N пройден», «Уровень пройден» и «Загрузка уровня 2»;
в порту — «Арена босса»):
`--headless --path . --fixed-fps 60 --quit-after 24000 -- --autoplay --god-mode [--level=N]`.
Снимки фонов всех уровней (только с окном; жёлтые линии — полоса ходьбы, розовые — боец 180 px):
`godot --path . res://scenes/level/level_preview.tscn -- --shots=<папка> [--levels=1,3]`.
Movie Maker на этой машине пишет кадры, только пока окно реально рисуется (при заснувшем
или перекрытом экране кадры «замерзают») — для картинок хватает коротких записей.

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
- [x] Этап 5 — уровень «Ошен-драйв»: LevelData (сегменты, волны, слои, предметы), камера битемапа
  (только вправо, замки, «GO →»), LevelDirector с волнами, параллакс из 5 слоёв на Parallax2D
  (плейсхолдеры, готовность к картинкам), разрушаемые предметы с бонусами (хот-дог, деньги), подбор,
  арена босса-заглушка, level.tscn — главная сцена, отладка: N — убить всех врагов на экране.
- [x] Этап 6.0 — разбор ассетов: сюжет и пять уровней, раскладка `_inbox` по `art_source` с `manifest.csv`,
  `process_backgrounds.py` (ключ, масштаб, швы, выравнивание пола, нарезка листов), `make_levels.py`,
  фоны тюремного корпуса в игре, цепочка уровней с финальной волной и переходом, F2–F6,
  картинки для предметов и бонусов (ждут арта), сцена снимков фонов.
- [x] Этап 7 — арт в игре: ActorSprite (SpriteFrames, масштаб из метаданных, замены недостающих анимаций
  стоп-кадром, предупреждение один раз), анимации реакций и поведения, ходьба по скорости, прыжок по кадрам,
  удары по кадрам (`frame_durations` / `active_frames`, хитбокс по `frame_changed`, тайминги прежние),
  хёртбоксы/хитбоксы/тени по спрайтам, общий шейдер вспышки и мигания, VICTORY героини при снятии замка.
  Не хватает: копам и боссу — E2 (idle, attack), E3 (hurt, knockdown, getup); боссу — B1, B2; героине — pickup;
  босса-бойца в игре ещё нет. Фоны есть только у cellblock.
- [x] Этап 6.1 — конвейер нарезки спрайтов: `slice_sheets.py` + `imgutil.py` (общий хромакей и поиск фигур с
  `process_backgrounds.py`), `art_source/animations.json`, кадры и SpriteFrames героини (12 анимаций) и ходьба копов
  и босса, превью-сетки, GIF и отчёт.
