extends Node

@export var wind_strength := 0.08
@export var wind_speed := 1.2
@export var wind_direction := Vector2(1.0, 0.3)

func _process(_delta):
	RenderingServer.global_shader_parameter_set(
		"wind_strength",
		wind_strength
	)

	RenderingServer.global_shader_parameter_set(
		"wind_speed",
		wind_speed
	)

	RenderingServer.global_shader_parameter_set(
		"wind_direction",
		wind_direction
	)
