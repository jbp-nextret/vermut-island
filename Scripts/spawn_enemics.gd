extends Node3D

@export var escena_enemic: PackedScene
@export var max_enemics: int = 5
@export var temps_spawn: float = 3.0
@export var rango_spawn: float = 20.0

var temps_darrer_spawn: float = 0.0

func _ready():
	if not escena_enemic:
		print("Falta assignar escena_enemic!")

func _process(delta):
	temps_darrer_spawn += delta
	
	if temps_darrer_spawn >= temps_spawn:
		if get_tree().get_nodes_in_group("enemics").size() < max_enemics:
			spawnejar_enemic()
			temps_darrer_spawn = 0.0

func spawnejar_enemic():
	if not escena_enemic: return
	
	var enemic = escena_enemic.instantiate()
	add_child(enemic)
	
	# Posició aleatòria al voltant del spawner
	var angle = randf() * TAU
	var distancia = randi_range(int(rango_spawn * 0.5), int(rango_spawn))
	enemic.global_position = global_position + Vector3(cos(angle) * distancia, 0, sin(angle) * distancia)
	
	print("Enemic spawnrejat!")
