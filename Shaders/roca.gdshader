shader_type spatial;
// Roques (Models/roca_*.glb) amb textura en gris i taques de molsa verda.
//  - El gris es converteix en un degradat entre `color_fosc` i `color_clar` (cada material
//    és una "pedra": grisa, sorrenca, blavosa, rogenca...)
//  - La molsa (les parts verdes de la textura) es manté, més o menys segons `molsa`
//  - `variacio` (per roca) la fa una mica més clara o més fosca

render_mode cull_disabled;

uniform sampler2D textura : source_color, filter_nearest;
uniform vec3 color_fosc : source_color = vec3(0.24, 0.24, 0.27);
uniform vec3 color_clar : source_color = vec3(0.62, 0.62, 0.66);

instance uniform float variacio = 0.0;   // de -1 a 1
instance uniform float molsa = 1.0;      // 0 = sense molsa

void fragment() {
	vec3 t = texture(textura, UV).rgb;
	float gris = dot(t, vec3(0.299, 0.587, 0.114));
	float saturacio = max(t.r, max(t.g, t.b)) - min(t.r, min(t.g, t.b));
	// El gris de la textura (0,52 al mig) passat al degradat de la pedra
	vec3 pedra = mix(color_fosc, color_clar, clamp(gris / 0.52 * 0.6, 0.0, 1.0));
	vec3 c = mix(pedra, t, smoothstep(0.08, 0.3, saturacio) * molsa);
	ALBEDO = c * (1.0 + variacio * 0.1);
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
