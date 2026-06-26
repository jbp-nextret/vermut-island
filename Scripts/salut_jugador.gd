extends Node

signal vida_canviat(vida_actual, vida_maxima)
signal mort

var vida_maxima = 100
var vida_actual = 100

func _ready():
	vida_actual = vida_maxima

func prendre_dany(quantitat: int):
	vida_actual -= quantitat
	emit_signal("vida_canviat", vida_actual, vida_maxima)
	print("Jugador pren ", quantitat, " dany. Vida: ", vida_actual)
	
	if vida_actual <= 0:
		vida_actual = 0
		emit_signal("mort")
		print("El jugador ha mort!")

func curar(quantitat: int):
	vida_actual = mini(vida_actual + quantitat, vida_maxima)
	emit_signal("vida_canviat", vida_actual, vida_maxima)
	print("Jugador curat +", quantitat, " . Vida: ", vida_actual)

func restaurar_salut():
	vida_actual = vida_maxima
	emit_signal("vida_canviat", vida_actual, vida_maxima)
