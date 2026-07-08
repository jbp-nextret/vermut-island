extends Node

signal cultiu_recollit(posicio)
signal player_spawn_requested(posicio)

var pending_spawn_position: Vector3 = Vector3.ZERO
var has_pending_spawn := false

func request_player_spawn(posicio: Vector3):
	pending_spawn_position = posicio
	has_pending_spawn = true
	player_spawn_requested.emit(posicio)

func consume_pending_spawn() -> Vector3:
	var posicio = pending_spawn_position
	pending_spawn_position = Vector3.ZERO
	has_pending_spawn = false
	return posicio
