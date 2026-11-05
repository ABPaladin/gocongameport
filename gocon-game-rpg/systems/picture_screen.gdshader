shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
void fragment() {
	// CanvasItem COLOR already includes the sampled texture and modulation.
	vec4 source = COLOR;
	vec3 destination = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(vec3(1.0) - (vec3(1.0) - source.rgb) * (vec3(1.0) - destination), source.a);
}
