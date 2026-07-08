shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, blend_mix;

uniform sampler2D textura : source_color, filter_nearest;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float llindar_blanc : hint_range(0.0, 1.0) = 0.9;
uniform float amplada_transicio : hint_range(0.0, 0.3) = 0.05;

void vertex() {
	vec3 escala = vec3(
		length(MODEL_MATRIX[0].xyz),
		length(MODEL_MATRIX[1].xyz),
		length(MODEL_MATRIX[2].xyz)
	);

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)) * escala.x, 0.0),
		vec4(0.0, 1.0, 0.0, 0.0) * escala.y,
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))) * escala.z, 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec4 tex = texture(textura, UV);
	float lluminositat = tex.r;

	float factor_tint = 1.0 - smoothstep(
		llindar_blanc - amplada_transicio,
		llindar_blanc + amplada_transicio,
		lluminositat
	);

	vec3 color_final = mix(tex.rgb, tex.rgb * color_tint.rgb, factor_tint);

	ALBEDO = color_final;
	ALPHA = tex.a;
}