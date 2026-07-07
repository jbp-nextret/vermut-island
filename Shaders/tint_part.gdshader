shader_type spatial;
render_mode unshaded, cull_disabled;

uniform sampler2D textura : source_color, filter_nearest;
uniform vec4 color_tint : source_color = vec4(1.0);

void fragment() {
	vec4 tex = texture(textura, UV);
	ALBEDO = tex.rgb * color_tint.rgb;
	ALPHA = tex.a;
}