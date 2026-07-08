shader_type spatial;

render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_nearest;

// Globals (Project Settings → Rendering → Global Shader Parameters)
global uniform float wind_strength;
global uniform float wind_speed;
global uniform vec2 wind_direction;

void vertex()
{
	// Il·luminació senzilla
	NORMAL = vec3(0.0, 1.0, 0.0);

	// Fase diferent per a cada planta
	float random = fract(
		sin(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233)))
		* 43758.5453
	);

	// La base no es mou
	float influence = 1.0 - UV.y;
	influence *= influence;

	// Ona principal
	float wave =
		sin(
			TIME * wind_speed
			+ random * 6.28318
			+ NODE_POSITION_WORLD.x * 0.5
			+ NODE_POSITION_WORLD.z * 0.3
		);

	VERTEX.x += wave * wind_direction.x * wind_strength * influence;
	VERTEX.z += wave * wind_direction.y * wind_strength * influence;
}

void fragment()
{
	vec4 tex = texture(texture_albedo, UV);

	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}