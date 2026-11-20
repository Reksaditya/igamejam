shader_type canvas_item;
render_mode unshaded;

uniform float pixel_columns : hint_range(0.0, 512.0, 1.0) = 500.0;
uniform float color_levels : hint_range(0.0, 256.0, 1.0) = 0.0;

void fragment() {
	vec2 sample_uv = UV;
	if (pixel_columns > 0.0) {
		float rows = max(1.0, round(pixel_columns * TEXTURE_PIXEL_SIZE.x / TEXTURE_PIXEL_SIZE.y));
		vec2 grid = vec2(pixel_columns, rows);
		sample_uv = (floor(UV * grid) + vec2(0.5)) / grid;
	}
	vec4 sample_color = texture(TEXTURE, sample_uv);
	if (color_levels > 1.0) {
		float intervals = color_levels - 1.0;
		sample_color.rgb = round(sample_color.rgb * intervals) / intervals;
	}
	COLOR = sample_color;
}
