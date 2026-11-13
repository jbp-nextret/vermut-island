shader_type spatial;
// Arbres 3D amb textures en escala de grisos (Models/arbre.glb).
//  - El color surt d'aquí: el gris de la textura es converteix en un degradat entre
//    `color_fosc` (on la textura és negra) i `color_clar` (on és blanca). Així les
//    branques negres de la textura de les fulles queden marrons i les fulles, verdes.
//  - Les fulles (`es_fulles`) es gronxen amb el vent (els globals del WeatherManager),
//    més com més amunt; el tronc no es mou.
//  - `variacio` (per arbre) fa cada arbre una mica diferent de to i de llum.
//  - `opacitat` (per arbre) el fa semitransparent amb un tramat de píxels quan tapa el
//    personatge (TransparenciaOcultadors). Així segueix sent un material opac.

render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D textura : source_color, filter_nearest;
uniform bool es_fulles = false;
uniform vec3 color_fosc : source_color = vec3(0.18, 0.11, 0.07);
uniform vec3 color_clar : source_color = vec3(0.55, 0.38, 0.24);
// Quant es mouen les fulles (multiplica la força del vent)
uniform float moviment = 0.8;
// Alçada (en coordenades del model) a partir de la qual les fulles es mouen
uniform float alcada_base = 2.3;

instance uniform float variacio = 0.0;   // de -1 a 1
instance uniform float opacitat = 1.0;

global uniform float wind_strength;
global uniform float wind_speed;
global uniform vec2 wind_direction;

void vertex() {
	if (es_fulles) {
		float h = max(VERTEX.y - alcada_base, 0.0);
		float fase = NODE_POSITION_WORLD.x * 0.7 + NODE_POSITION_WORLD.z * 0.5;
		float ona = sin(TIME * wind_speed + fase + VERTEX.x * 1.5)
			+ 0.4 * sin(TIME * wind_speed * 1.7 + fase * 1.3 + VERTEX.z * 2.0);
		vec3 direccio = vec3(wind_direction.x, 0.0, wind_direction.y);
		VERTEX += direccio * ona * wind_strength * moviment * h;
		VERTEX.y += 0.3 * ona * wind_strength * moviment * h * 0.3;
	}
}

// Tramat 4×4 (Bayer) per a la transparència
float llindar_tramat(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
		3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	vec4 t = texture(textura, UV);
	if (t.a < 0.5) {
		discard;
	}
	if (opacitat < 0.999 && opacitat < llindar_tramat(FRAGCOORD.xy)) {
		discard;
	}
	float gris = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(color_fosc, color_clar, gris);
	// Cada arbre una mica diferent: més o menys llum i, les fulles, més grogues o més blaves
	c *= 1.0 + variacio * 0.12;
	if (es_fulles) {
		c = mix(c, c * vec3(1.12, 1.04, 0.75), max(variacio, 0.0) * 0.6);
		c = mix(c, c * vec3(0.9, 1.0, 1.12), max(-variacio, 0.0) * 0.6);
	}
	ALBEDO = c;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
