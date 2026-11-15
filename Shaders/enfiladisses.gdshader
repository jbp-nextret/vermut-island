shader_type spatial;
// Les plantes enfiladisses de les columnes: la textura és la silueta (verd fosc); el color
// el posa el bioma (`color`). Retallades per l'alfa.

render_mode cull_disabled;

// Sense source_color (valors sRGB tal qual): els detalls de les fulles són només 2-5
// punts de diferència (26, 28, 30, 33 sobre 255), i s'amplifiquen amb `contrast`
uniform sampler2D textura : filter_nearest;
uniform vec3 color : source_color = vec3(0.25, 0.5, 0.2);
uniform float gris_mig = 0.11;
uniform float contrast = 30.0;

void fragment() {
	vec4 t = texture(textura, UV);
	float gris = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	ALBEDO = color * clamp(1.0 + (gris - gris_mig) * contrast, 0.55, 1.6);
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
