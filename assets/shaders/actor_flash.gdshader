// Общий шейдер бойцов (спрайт и плейсхолдер-прямоугольник; узел Visual, дети берут его через
// use_parent_material). Вспышка — подмешивание flash_color с силой flash_amount:
// белая при попадании, синяя при блоке щитом, жёлтая в замахе врага.
// alpha — мигание неуязвимости и смерти (0 — боец не виден).
shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	// COLOR на входе — цвет текстуры, умноженный на цвет вершины (у ColorRect — его color).
	vec4 c = COLOR;
	c.rgb = mix(c.rgb, flash_color.rgb, flash_amount);
	c.a *= alpha;
	COLOR = c;
}
