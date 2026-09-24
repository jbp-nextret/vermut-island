extends Node3D
class_name InteraccioJugador
## Fa que el jugador pugui interactuar amb coses properes (barrica, clients...)
## i portar un objecte a la mà.
##
## Qualsevol node del grup "interactuables" pot ser-ho si té aquests mètodes:
##   pot_interactuar(jugador) -> bool
##   text_interaccio(jugador) -> String
##   punt_interaccio() -> Vector3
##   interactuar(jugador)

@export var radi := 1.6
@export var posicio_ma := Vector3(0.35, 0.9, 0.0)
@export var alcada_indicador := 1.1

var objecte_portat: Node3D = null
var objectiu: Node = null
var indicador: Label3D

func _ready():
	indicador = Label3D.new()
	indicador.top_level = true   # es posiciona al món, no relatiu al jugador
	indicador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	indicador.no_depth_test = true
	indicador.font_size = 44
	indicador.outline_size = 12
	indicador.pixel_size = 0.004
	indicador.visible = false
	add_child(indicador)

func _process(_delta):
	objectiu = _buscar_objectiu()
	if objectiu:
		indicador.text = "[%s] %s" % [_tecla(), objectiu.text_interaccio(self)]
		indicador.global_position = objectiu.punt_interaccio() + Vector3.UP * alcada_indicador
		indicador.visible = true
	else:
		indicador.visible = false

func _unhandled_input(event):
	if event.is_action_pressed("interactuar") and objectiu:
		objectiu.interactuar(self)
		get_viewport().set_input_as_handled()

func _buscar_objectiu() -> Node:
	if GameState.mode == GameState.Mode.CONSTRUIR:
		return null
	var millor: Node = null
	var millor_distancia := radi
	for node in get_tree().get_nodes_in_group("interactuables"):
		if not node.has_method("pot_interactuar") or not node.pot_interactuar(self):
			continue
		var p: Vector3 = node.punt_interaccio()
		var distancia := Vector2(p.x - global_position.x, p.z - global_position.z).length()
		if distancia < millor_distancia:
			millor = node
			millor_distancia = distancia
	return millor

func _tecla() -> String:
	for ev in InputMap.action_get_events("interactuar"):
		if ev is InputEventKey:
			return ev.as_text_physical_keycode()
	return "?"

# ─────────────── Objecte a la mà

func porta_objecte() -> bool:
	return is_instance_valid(objecte_portat)

func agafar(objecte: Node3D) -> void:
	if porta_objecte():
		return
	objecte_portat = objecte
	if objecte.get_parent():
		objecte.reparent(self, false)
	else:
		add_child(objecte)
	objecte.position = posicio_ma
	objecte.rotation = Vector3.ZERO

func deixar_objecte() -> Node3D:
	var objecte := objecte_portat
	objecte_portat = null
	if is_instance_valid(objecte) and objecte.get_parent() == self:
		remove_child(objecte)
	return objecte
