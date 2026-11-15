shader_type spatial;
// Columnes de les ruïnes (Models/Dungeons/Columna.glb). La textura és pedra grisa fosca
// amb una taca de molsa verda:
//  - el gris passa a un degradat entre `color_fosc` i `color_clar` (la pedra del bioma)
//  - la molsa (els píxels verds) agafa `color_molsa` (també del bioma)
//  - `variacio` (per columna) la fa una mica més clara o més fosca

render_mode cull_disabled;

uniform sampler2D textura : source_color, filter_nearest;
uniform vec3 color_fosc : source_color = vec3(0.24, 0.24, 0.27);
uniform vec3 color_clar : source_color = vec3(0.62, 0.62, 0.66);
uniform vec3 color_molsa : source_color = vec3(0.25, 0.45, 0.2);
// El gris "del mig" de la textura (és fosca: uns 0,2)
uniform float gris_mig = 0.2;

instance uniform float variacio = 0.0;

void fragment() {
	vec3 t = texture(textura, UV).rgb;
	float gris = dot(t, vec3(0.299, 0.587, 0.114));
	bool es_molsa = t.g > t.r * 1.25 && t.g > t.b * 1.25;
	vec3 pedra = mix(color_fosc, color_clar, clamp(gris / gris_mig * 0.55, 0.0, 1.0));
	vec3 molsa = color_molsa * clamp(gris / 0.12, 0.7, 1.3);
	ALBEDO = (es_molsa ? molsa : pedra) * (1.0 + variacio * 0.1);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
