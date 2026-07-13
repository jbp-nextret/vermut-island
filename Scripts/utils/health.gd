extends Node
class_name Health

signal mort
signal dany_rebut(quantitat: int, vida_actual: int)
signal vida_canviada(vida_actual: int, vida_maxima: int)

@export var vida_maxima: int = 100
var vida_actual: int

func _ready():
	vida_actual = vida_maxima

func rebre_dany(quantitat: int):
	if vida_actual <= 0:
		return
	vida_actual = max(0, vida_actual - quantitat)
	dany_rebut.emit(quantitat, vida_actual)
	vida_canviada.emit(vida_actual, vida_maxima)
	if vida_actual <= 0:
		mort.emit()

func curar(quantitat: int):
	vida_actual = min(vida_maxima, vida_actual + quantitat)
	vida_canviada.emit(vida_actual, vida_maxima)
