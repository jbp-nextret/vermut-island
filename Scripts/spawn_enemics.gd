extends Node3D
## Punt d'on surten els enemics. Quins i quan ho decideix GestorOnades.

@export var escena_enemic: PackedScene   # ja no s'usa: ara les escenes les tria GestorOnades
@export var rango_spawn: float = 20.0

func _ready():
	GestorOnades.registrar_spawner(self)

func _exit_tree():
	GestorOnades.desregistrar_spawner(self)

func spawnejar(escena: PackedScene, multiplicador_vida: float) -> Node3D:
	var enemic = escena.instantiate()
	enemic.vida_maxima = int(round(enemic.vida_maxima * multiplicador_vida))
	add_child(enemic)
	enemic.global_position = _punt_spawn(enemic)
	return enemic

## On surt: un punt de l'illa (no a l'aigua ni dins d'una paret), si pot ser fora de la
## pantalla i no a sobre del jugador. Els voladors, una mica enlaire.
func _punt_spawn(enemic: Node3D) -> Vector3:
	var camera := get_viewport().get_camera_3d()
	var mon := get_tree().current_scene
	var aigua: float = mon.nivell_aigua() if mon and mon.has_method("nivell_aigua") else -INF
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	var espai := get_world_3d().direct_space_state
	var millor := Vector3.INF
	for intent in 24:
		var angle := randf() * TAU
		var distancia := randf_range(rango_spawn * 0.5, rango_spawn)
		var p := global_position + Vector3(cos(angle) * distancia, 0, sin(angle) * distancia)
		var raig := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 12.0, p + Vector3.DOWN * 12.0, 1)
		var cop := espai.intersect_ray(raig)
		if cop.is_empty() or cop.normal.y < 0.7 or cop.position.y < aigua:
			continue
		var punt: Vector3 = cop.position + Vector3.UP * (float(enemic.altura_vol) if enemic.es_volador else 0.3)
		if jugador and Vector2(punt.x - jugador.global_position.x, punt.z - jugador.global_position.z).length() < 6.0:
			continue
		millor = punt
		# Millor si no es veu (així no apareixen del no-res davant teu)
		if camera == null or not camera.is_position_in_frustum(punt):
			break
	if millor == Vector3.INF:
		var angle := randf() * TAU
		millor = global_position + Vector3(cos(angle), 0, sin(angle)) * rango_spawn * 0.75
	return millor
