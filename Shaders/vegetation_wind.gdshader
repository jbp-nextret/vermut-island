shader_type spatial;
// Vegetació amb vent.
//  - Herba (per defecte): tot el sprite es gronxa, més com més amunt.
//  - Arbres (`nomes_fulles = true`): el tronc es queda quiet i només es mouen les fulles.
//    Cada píxel de fulla agafa el color d'un píxel desplaçat uns texels cap al costat
//    (més com més amunt i com més vent), així el moviment és nítid, en pixel art.
//    Una fulla és un píxel prou verd (més verd que vermell). Si algun dia dibuixes
//    les fulles en una capa a part, això ja no caldrà.

render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform bool nomes_fulles = false;
// Quants texels es mouen les fulles com a màxim (amb vent normal)
uniform float texels_moviment = 2.0;

// Globals (Project Settings → Rendering → Global Shader Parameters)
global uniform float wind_strength;
global uniform float wind_speed;
global uniform vec2 wind_direction;

float aleatori(vec3 posicio) {
	return fract(sin(dot(posicio.xz, vec2(12.9898, 78.233))) * 43758.5453);
}

bool es_fulla(vec4 c) {
	return c.a > 0.5 && c.g > c.r * 1.1 && c.g >= c.b;
}

void vertex()
{
	// Il·luminació senzilla
	NORMAL = vec3(0.0, 1.0, 0.0);

	if (!nomes_fulles) {
		// La base no es mou
		float influence = 1.0 - UV.y;
		influence *= influence;
		float wave = sin(TIME * wind_speed + aleatori(NODE_POSITION_WORLD) * 6.28318
			+ NODE_POSITION_WORLD.x * 0.5 + NODE_POSITION_WORLD.z * 0.3);
		VERTEX.x += wave * wind_direction.x * wind_strength * influence;
		VERTEX.z += wave * wind_direction.y * wind_strength * influence;
	}
}

void fragment()
{
	vec4 tex = texture(texture_albedo, UV);

	if (nomes_fulles) {
		vec2 mida = vec2(textureSize(texture_albedo, 0));
		// Més moviment a dalt de la copa; una mica d'ona al llarg de l'alçada
		float alcada = clamp(1.0 - UV.y, 0.0, 1.0);
		float ona = sin(TIME * wind_speed + aleatori(NODE_POSITION_WORLD) * 6.28318 + UV.y * 4.0);
		float costat = wind_direction.x >= 0.0 ? 1.0 : -1.0;
		float texels = round(ona * costat * wind_strength * texels_moviment * 12.0 * alcada);
		vec4 desplacat = texture(texture_albedo, UV + vec2(texels / mida.x, 0.0));
		if (es_fulla(desplacat)) {
			tex = desplacat;          // una fulla s'hi ha mogut a sobre
		} else if (es_fulla(tex)) {
			tex = vec4(0.0);          // la fulla d'aquí s'ha mogut cap a un altre lloc
		}
		// (el tronc i la resta es queden on són)
	}

	ALBEDO = tex.rgb;
	ALPHA = tex.a;
	// Retallat: s'escriu a la profunditat i l'aigua ja no la tapa
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
