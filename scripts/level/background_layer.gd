class_name BackgroundLayer
extends Parallax2D
## Слой параллакса из BackgroundLayerData. Если файл texture_path есть —
## показывает картинку (масштаб под высоту экрана, повтор по горизонтали),
## иначе рисует плейсхолдер в палитре закатного Майами по placeholder_style.
## Кусок плейсхолдера — CHUNK_WIDTH px, Parallax2D повторяет его по repeat_size.

const Style := BackgroundLayerData.PlaceholderStyle
## Ширина повторяемого куска плейсхолдера (не меньше ширины экрана), px.
const CHUNK_WIDTH: float = 1280.0
## Высота экрана — под неё масштабируется картинка, px.
const SCREEN_HEIGHT: float = 720.0
## Палитра закатного Майами.
const PURPLE_DEEP := Color("#2a1446")
const PURPLE := Color("#3b1f5c")
const VIOLET := Color("#6a2c8a")
const PINK := Color("#ff5fa2")
const SUNSET := Color("#ff9a5a")
const SUN := Color("#ffd166")
const TEAL := Color("#2ec4b6")
const TEAL_DARK := Color("#1b7f86")
const PASTELS: Array[Color] = [Color("#ffb3c7"), Color("#9be7e0"), Color("#ffd7a0"), Color("#c9b6ff")]

var data: BackgroundLayerData
## Полоса ходьбы (для плейсхолдера улицы).
var walk_top: float = 430.0
var walk_bottom: float = 680.0


## Настроить слой. Вызывать до добавления в дерево или сразу после.
func setup(layer_data: BackgroundLayerData, top: float, bottom: float) -> void:
	data = layer_data
	walk_top = top
	walk_bottom = bottom
	name = data.name
	scroll_scale = Vector2(data.scroll_scale, 1.0)
	repeat_times = 2
	var texture: Texture2D = null
	if not data.texture_path.is_empty() and ResourceLoader.exists(data.texture_path):
		texture = load(data.texture_path) as Texture2D
	if texture != null:
		_setup_texture(texture)
	else:
		repeat_size = Vector2(CHUNK_WIDTH, 0.0)
		queue_redraw()


## Картинка: масштаб под высоту экрана, кусок из целого числа повторов шириной не меньше экрана.
func _setup_texture(texture: Texture2D) -> void:
	var k: float = SCREEN_HEIGHT / float(texture.get_height())
	var width: float = texture.get_width() * k
	var copies: int = maxi(ceili(CHUNK_WIDTH / width), 1)
	var sprite := Sprite2D.new()
	sprite.name = "Texture"
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2(k, k)
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0.0, 0.0, texture.get_width() * copies, texture.get_height())
	add_child(sprite)
	repeat_size = Vector2(width * copies, 0.0)


func _draw() -> void:
	if data == null or get_child_count() > 0:
		return
	match data.placeholder_style:
		Style.SKY:
			_draw_sky()
		Style.FAR:
			_draw_far()
		Style.MID:
			_draw_mid()
		Style.STREET:
			_draw_street()
		Style.FRONT:
			_draw_front()


## Небо: полосы от фиолетового к закату и диск солнца. Непрозрачный.
func _draw_sky() -> void:
	var bands: Array[Color] = [PURPLE_DEEP, PURPLE, VIOLET, PINK.darkened(0.15), PINK, SUNSET]
	var band_height: float = 300.0 / bands.size()
	draw_rect(Rect2(0.0, 0.0, CHUNK_WIDTH, SCREEN_HEIGHT), data.placeholder_color)
	for i in bands.size():
		draw_rect(Rect2(0.0, i * band_height, CHUNK_WIDTH, band_height + 1.0), bands[i])
	draw_rect(Rect2(0.0, 300.0, CHUNK_WIDTH, SCREEN_HEIGHT - 300.0), SUNSET)
	draw_circle(Vector2(CHUNK_WIDTH * 0.62, 250.0), 90.0, SUN)
	# Полосы на солнце — ретро-закат.
	for i in 4:
		draw_rect(Rect2(CHUNK_WIDTH * 0.62 - 95.0, 260.0 + i * 18.0, 190.0, 5.0 + i * 2.0), SUNSET)


## Дальний план: силуэты небоскрёбов и бирюзовая полоса океана до горизонта улицы; верх прозрачный.
func _draw_far() -> void:
	var color: Color = data.placeholder_color
	var horizon: float = 330.0
	var x: float = 20.0
	var i: int = 0
	while x < CHUNK_WIDTH - 60.0:
		var w: float = 50.0 + float((i * 37) % 50)
		var h: float = 90.0 + float((i * 53) % 110)
		draw_rect(Rect2(x, horizon - h, w, h + 2.0), color if i % 2 == 0 else color.lightened(0.12))
		x += w + 12.0 + float((i * 19) % 40)
		i += 1
	draw_rect(Rect2(0.0, horizon, CHUNK_WIDTH, walk_top - horizon), TEAL_DARK)
	for j in 6:
		draw_rect(Rect2(40.0 + j * 210.0, horizon + 16.0 + (j % 3) * 22.0, 90.0, 3.0), TEAL)


## Средний план: набережная с парапетом и пальмы; верх прозрачный.
func _draw_mid() -> void:
	var color: Color = data.placeholder_color
	var deck: float = walk_top - 36.0
	draw_rect(Rect2(0.0, deck, CHUNK_WIDTH, walk_top - deck), color)
	draw_rect(Rect2(0.0, deck - 8.0, CHUNK_WIDTH, 8.0), color.lightened(0.25))
	for k in 16:
		draw_rect(Rect2(k * 80.0 + 30.0, deck, 8.0, walk_top - deck), color.darkened(0.2))
	for p in 4:
		_draw_palm(Vector2(120.0 + p * 320.0, deck), 190.0, color.darkened(0.35))


## Улица: пастельные отели с просветами (в них видно набережную и океан),
## тротуар с плиткой, бордюр и дорога.
func _draw_street() -> void:
	var tops: Array[float] = [170.0, 210.0, 150.0]
	var hotel_width: float = 320.0
	var gap: float = CHUNK_WIDTH / tops.size() - hotel_width
	for i in tops.size():
		var x: float = gap * 0.5 + i * (hotel_width + gap)
		var color: Color = PASTELS[i % PASTELS.size()]
		var top: float = tops[i]
		draw_rect(Rect2(x, top, hotel_width, walk_top - top), color)
		draw_rect(Rect2(x - 6.0, top - 10.0, hotel_width + 12.0, 12.0), color.darkened(0.15))
		# Окна и козырёк.
		var rows: int = int((walk_top - 60.0 - top - 40.0) / 50.0)
		for row in rows:
			for col in 4:
				draw_rect(Rect2(x + 30.0 + col * 70.0, top + 30.0 + row * 50.0, 36.0, 26.0), TEAL_DARK.lerp(color, 0.3))
		draw_rect(Rect2(x + 30.0, walk_top - 44.0, hotel_width - 60.0, 12.0), PINK if i % 2 == 0 else TEAL)
	# Тротуар.
	draw_rect(Rect2(0.0, walk_top, CHUNK_WIDTH, walk_bottom - walk_top), data.placeholder_color)
	var seam: Color = data.placeholder_color.darkened(0.12)
	var tile: float = 128.0
	var sx: float = 0.0
	while sx < CHUNK_WIDTH:
		draw_line(Vector2(sx, walk_top), Vector2(sx, walk_bottom), seam, 2.0)
		sx += tile
	draw_line(Vector2(0.0, (walk_top + walk_bottom) * 0.5), Vector2(CHUNK_WIDTH, (walk_top + walk_bottom) * 0.5), seam, 2.0)
	# Бордюр и дорога.
	draw_rect(Rect2(0.0, walk_bottom, CHUNK_WIDTH, 8.0), Color("#f2e9e4"))
	draw_rect(Rect2(0.0, walk_bottom + 8.0, CHUNK_WIDTH, SCREEN_HEIGHT - walk_bottom - 8.0), PURPLE)


## Передний план: тёмные стволы пальм и фонари; всё остальное прозрачное.
func _draw_front() -> void:
	var color: Color = data.placeholder_color
	# Ствол пальмы — от низа экрана вверх за кадр, слегка изогнутый.
	var base := Vector2(260.0, SCREEN_HEIGHT)
	for s in 12:
		var t: float = s / 12.0
		var offset: float = sin(t * PI) * 30.0
		draw_rect(Rect2(base.x + offset - 22.0, SCREEN_HEIGHT - (s + 1) * 60.0, 44.0, 62.0), color if s % 2 == 0 else color.lightened(0.08))
	# Фонарь.
	var lamp_x: float = 900.0
	draw_rect(Rect2(lamp_x - 7.0, 150.0, 14.0, SCREEN_HEIGHT - 150.0), color)
	draw_rect(Rect2(lamp_x - 7.0, 150.0, 70.0, 10.0), color)
	draw_circle(Vector2(lamp_x + 60.0, 170.0), 14.0, SUN)


func _draw_palm(foot: Vector2, height: float, color: Color) -> void:
	draw_line(foot, foot + Vector2(14.0, -height), color, 8.0)
	var top: Vector2 = foot + Vector2(14.0, -height)
	for a in 6:
		var angle: float = -PI + a * PI / 5.0
		draw_line(top, top + Vector2(cos(angle) * 60.0, sin(angle) * 22.0 + 18.0), color, 6.0)
