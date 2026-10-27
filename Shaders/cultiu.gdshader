shader_type spatial;
// Sprite de cultiu: sempre de cara a la càmera (només gira en vertical), retallat per
// l'alfa i gronxant-se amb el vent. Els paràmetres del vent són els globals que posa el
// WeatherManager (els mateixos que la vegetació).
render_mode unshaded, cull_disabled;

uniform sampler2D textura : source_color, filter_nearest;
uniform vec4 tint : source_color = vec4(1.0);
// Quant es gronxa (els cultius més grans es poden fer moure més)
uniform float gronxament = 1.0;

global uniform float wind_strength;
global uniform float wind_speed;
global uniform vec2 wind_direction;

void vertex() {
	// Billboard només en l'eix Y (com el BILLBOARD_FIXED_Y del material estàndard)
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);

	// Vent: la base no es mou, la punta sí; cada planta amb la seva fase
	float influencia = pow(1.0 - UV.y, 2.0);
	float fase = fract(sin(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233))) * 43758.5453) * 6.2832;
	float ona = sin(TIME * wind_speed * 1.6 + fase) + 0.35 * sin(TIME * wind_speed * 4.1 + fase * 2.0);
	// Cap a on bufa el vent, vist des de la càmera
	float costat = sign(dot(vec3(wind_direction.x, 0.0, wind_direction.y), INV_VIEW_MATRIX[0].xyz) + 0.001);
	VERTEX.x += (ona * 0.6 + 0.4 * costat) * wind_strength * influencia * gronxament * 1.8;
}

void fragment() {
	vec4 color = texture(textura, UV);
	ALBEDO = color.rgb * tint.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
