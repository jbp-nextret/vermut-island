extends Node

signal vida_canviat(vida_actual, vida_maxima)
signal mort

var vida_maxima = 100
var vida_actual = 100

## Després d'un cop, uns instants sense rebre'n més (si no, 3 ratpenats et fonen)
const INVULNERABILITAT := 0.6
var invulnerable_fins := 0.0

func _ready():
	vida_actual = vida_maxima

func prendre_dany(quantitat: int):
	var ara := Time.get_ticks_msec() / 1000.0
	if ara < invulnerable_fins:
		return
	invulnerable_fins = ara + INVULNERABILITAT
	vida_actual -= quantitat
	if vida_actual <= 0:
		vida_actual = 0
	emit_signal("vida_canviat", vida_actual, vida_maxima)
	if vida_actual <= 0:
		emit_signal("mort")

func curar(quantitat: int):
	vida_actual = mini(vida_actual + quantitat, vida_maxima)
	emit_signal("vida_canviat", vida_actual, vida_maxima)

func restaurar_salut():
	vida_actual = vida_maxima
	emit_signal("vida_canviat", vida_actual, vida_maxima)
