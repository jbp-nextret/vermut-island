extends Node
## Única font de veritat sobre què està fent el jugador.
## Els altres sistemes pregunten aquí abans d'actuar.

signal mode_canviat(mode: Mode)

enum Mode { EXPLORAR, CONSTRUIR, SERVEI }

var mode: Mode = Mode.EXPLORAR:
	set(valor):
		if mode == valor:
			return
		mode = valor
		mode_canviat.emit(valor)

var dins_casa := false

func pot_atacar() -> bool:
	return mode == Mode.EXPLORAR and not dins_casa

func pot_moure() -> bool:
	return mode != Mode.CONSTRUIR

func pot_construir() -> bool:
	return dins_casa and mode == Mode.EXPLORAR

func pot_obrir_vermuteria() -> bool:
	return dins_casa and mode == Mode.EXPLORAR
