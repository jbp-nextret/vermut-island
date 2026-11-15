shader_type spatial;
// Columnes de les ruïnes (Models/Dungeons/Columna.glb). La textura és pedra grisa fosca
// amb una taca de molsa verda:
//  - el gris passa a un degradat entre `color_fosc` i `color_clar` (la pedra del bioma)
//  - la molsa (els píxels verds) agafa `color_molsa` (també del bioma)
//  - `variacio` (per columna) la fa una mica més clara o més fosca

render_mode cull_disabled;

// Sense source_color: es llegeixen els valors tal com són a la textura (sRGB), que és
// on hi ha els detalls (les esquerdes són només uns punts més fosques que la pedra)
uniform sampler2D textura : filter_nearest;
uniform vec3 color_fosc : source_color = vec3(0.24, 0.24, 0.27);
uniform vec3 color_clar : source_color = vec3(0.62, 0.62, 0.66);
uniform vec3 color_molsa : source_color = vec3(0.25, 0.45, 0.2);
// El gris de la pedra a la textura (uns 50/255) i quant s'amplifiquen les diferències
uniform float gris_mig = 0.196;
uniform float contrast = 8.0;

instance uniform float variacio = 0.0;

void fragment() {
	vec3 t = texture(textura, UV).rgb;
	float gris = dot(t, vec3(0.299, 0.587, 0.114));
	bool es_molsa = t.g > t.r * 1.25 && t.g > t.b * 1.25;
	// (les diferències d'1 punt són soroll de la textura: no es tenen en compte)
	float d = gris - gris_mig;
	d = sign(d) * max(abs(d) - 0.006, 0.0);
	vec3 pedra = mix(color_fosc, color_clar, clamp(0.55 + d * contrast, 0.0, 1.0));
	vec3 molsa = color_molsa * clamp(1.0 + (gris - 0.11) * 25.0, 0.6, 1.5);
	ALBEDO = (es_molsa ? molsa : pedra) * (1.0 + variacio * 0.1);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
