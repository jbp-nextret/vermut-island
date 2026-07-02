extends Node

signal dia_nou

# Durada d'un dia complet en segons reals
@export var durada_dia: float = 8.0

var dia_actual = 1
var hora_actual: float = 8.0  # comença a les 8 del matí (0-24)

func _process(delta):
	hora_actual += (24.0 / durada_dia) * delta
	if hora_actual >= 24.0:
		hora_actual -= 24.0
		passar_dia()

func passar_dia():
	dia_actual += 1
	emit_signal("dia_nou")
	# Avisa tots els cultius
	get_tree().call_group("cultius", "passar_dia")
	GestorPartida.guardar_mundo()  # Guarda després de cada dia
