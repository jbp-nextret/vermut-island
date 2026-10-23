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
## Mentre es parla amb un NPC: el jugador no es mou ni ataca i el temps s'atura
var en_dialeg := false
## Mentre condueix la barca: no ataca ni fa servir eines (les tecles mouen la barca)
var a_barca := false

# Preferències: ara les porta el SettingsManager (aquí queden com a dreceres)
var postprocessat_actiu: bool:
	get: return SettingsManager.valor("postprocessat")
	set(valor): SettingsManager.canviar("postprocessat", valor)
var pantalla_completa: bool:
	get: return SettingsManager.valor("pantalla_completa")
	set(valor): SettingsManager.canviar("pantalla_completa", valor)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pantalla_completa"):
		pantalla_completa = not pantalla_completa

func pot_atacar() -> bool:
	return mode == Mode.EXPLORAR and not dins_casa and not en_dialeg and not a_barca

func pot_moure() -> bool:
	return mode != Mode.CONSTRUIR and not en_dialeg

func pot_construir() -> bool:
	return dins_casa and mode == Mode.EXPLORAR

func pot_obrir_vermuteria() -> bool:
	return dins_casa and mode == Mode.EXPLORAR and GestorTemps.es_hora_de_servei()
