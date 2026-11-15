shader_type spatial;
// Les plantes enfiladisses de les columnes: la textura és la silueta (verd fosc); el color
// el posa el bioma (`color`). Retallades per l'alfa.

render_mode cull_disabled;

uniform sampler2D textura : source_color, filter_nearest;
uniform vec3 color : source_color = vec3(0.25, 0.5, 0.2);

void fragment() {
	vec4 t = texture(textura, UV);
	float gris = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = color * clamp(gris / 0.12, 0.7, 1.4);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
