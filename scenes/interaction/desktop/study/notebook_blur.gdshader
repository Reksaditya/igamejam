shader_type canvas_item;
render_mode unshaded;

uniform sampler2D quiz_screen : hint_screen_texture, repeat_disable, filter_linear;
varying float fade;

void vertex() {
	fade = COLOR.a;
}

void fragment() {
	vec2 step_size = SCREEN_PIXEL_SIZE * 3.0;
	vec3 blur = texture(quiz_screen, SCREEN_UV).rgb * 4.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x != 0 || y != 0) {
				float weight = (x == 0 || y == 0) ? 2.0 : 1.0;
				blur += texture(quiz_screen, SCREEN_UV + vec2(float(x), float(y)) * step_size).rgb * weight;
			}
		}
	}
	COLOR = vec4(blur * (0.76 / 16.0), fade);
}
