shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D textura : source_color, filter_nearest;
uniform vec4 color_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void vertex() {
	// Extraiem l'escala real del node abans de descartar el MODEL_MATRIX original
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
	ALBEDO = tex.rgb * color_tint.rgb;
	ALPHA = tex.a;
}