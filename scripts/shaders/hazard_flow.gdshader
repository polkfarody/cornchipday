shader_type canvas_item;

uniform vec2 scroll_speed = vec2(0.12, 0.09);
uniform float wobble_amount = 0.015;
uniform float wobble_speed = 1.5;

void fragment() {
	vec2 uv = UV;
	uv.x += sin(TIME * wobble_speed + UV.y * 12.0) * wobble_amount;
	uv += scroll_speed * TIME;
	uv = fract(uv);
	COLOR = texture(TEXTURE, uv);
}
