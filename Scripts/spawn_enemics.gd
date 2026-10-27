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
	var angle = randf() * TAU
	var distancia = randf_range(rango_spawn * 0.5, rango_spawn)
	enemic.global_position = global_position + Vector3(cos(angle) * distancia, 0, sin(angle) * distancia)
	return enemic
