shader_type spatial;
// Postprocessat de pantalla completa (va en un quad fill de la càmera):
//  - vora blanca al voltant de les siluetes (objectes, personatges i desnivells del terreny)
//  - gradació de color suau i una vinyeta als costats
//  - posterització amb dithering ordenat, per donar-li un aire més de pixel art
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_nearest;

uniform vec4 color_vora : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensitat_vora : hint_range(0.0, 1.0) = 0.8;
// Quanta diferència de profunditat (en unitats del món) fa falta perquè hi hagi vora
uniform float llindar_profunditat = 0.1;
uniform float saturacio : hint_range(0.0, 2.0) = 0.95;
uniform float contrast : hint_range(0.5, 1.5) = 1.04;
uniform vec3 tint : source_color = vec3(1.0, 0.98, 0.94);   // un pèl càlid
uniform float vinyeta : hint_range(0.0, 1.0) = 0.3;
// Nivells de color per canal (0 = sense posterització)
uniform float nivells_color = 32.0;
uniform float dithering : hint_range(0.0, 1.0) = 0.5;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
                                3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

float profunditat(vec2 uv, mat4 inv_projeccio) {
	float d = texture(DEPTH_TEXTURE, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 vista = inv_projeccio * vec4(ndc, 1.0);
	vista.xyz /= vista.w;
	return -vista.z;
}

void fragment() {
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	float d = profunditat(SCREEN_UV, INV_PROJECTION_MATRIX);

	// Vora: algun veí és clarament més a prop -> som just fora d'una silueta
	float vora = 0.0;
	vec2 veins[4] = vec2[](vec2(1.0, 0.0), vec2(-1.0, 0.0), vec2(0.0, 1.0), vec2(0.0, -1.0));
	for (int i = 0; i < 4; i++) {
		float dv = profunditat(SCREEN_UV + veins[i] * pixel, INV_PROJECTION_MATRIX);
		if (d - dv > llindar_profunditat) {
			vora = 1.0;
		}
	}

	vec3 c = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	float lluminancia = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(lluminancia), c, saturacio);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;
	// Vinyeta: els costats una mica més foscos
	vec2 centrat = SCREEN_UV - 0.5;
	c *= 1.0 - vinyeta * smoothstep(0.35, 0.75, length(centrat * vec2(1.3, 1.0)));

	if (nivells_color > 1.0) {
		ivec2 p = ivec2(FRAGCOORD.xy) % 4;
		float soroll = BAYER[p.y * 4 + p.x] / 16.0 - 0.5;
		c = floor(c * nivells_color + 0.5 + soroll * dithering) / nivells_color;
	}

	ALBEDO = mix(clamp(c, 0.0, 1.0), color_vora.rgb, vora * intensitat_vora);
}
