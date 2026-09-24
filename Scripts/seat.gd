extends Marker3D
class_name Seat

## Una barra a una cel·la de distància (no en diagonal) fa de taula
const DISTANCIA_TAULA := 1.05

var occupant: Node = null
var indicador: Label3D = null

func _ready():
	# Només compta com a seient si el moble està col·locat de veritat.
	# La preview del mode construcció no és a "mobles_base".
	if get_parent().is_in_group("mobles_base"):
		add_to_group("seats")

func is_free() -> bool:
	return occupant == null

func get_sit_position() -> Vector3:
	return global_position

## La barra que fa de taula d'aquest seient, o null si no n'hi ha cap al costat.
func taula() -> Node3D:
	var millor: Node3D = null
	var millor_distancia := DISTANCIA_TAULA
	for barra in get_tree().get_nodes_in_group("barres"):
		if barra.is_queued_for_deletion():
			continue
		var d := Vector2(barra.global_position.x - global_position.x, barra.global_position.z - global_position.z).length()
		if d <= millor_distancia:
			millor = barra
			millor_distancia = d
	return millor

## Sense taula no s'hi pot servir, així que cap client s'hi asseurà.
func es_utilitzable() -> bool:
	return taula() != null

## Avís "Sense taula" a sobre del seient (es fa servir en mode construcció).
func mostrar_avis(mostrar: bool) -> void:
	if mostrar and indicador == null:
		indicador = Label3D.new()
		indicador.text = "Sense taula"
		indicador.modulate = Color(1.0, 0.35, 0.3)
		indicador.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		indicador.no_depth_test = true
		indicador.font_size = 40
		indicador.outline_size = 10
		indicador.pixel_size = 0.004
		indicador.position = Vector3.UP * 0.8
		add_child(indicador)
	if indicador:
		indicador.visible = mostrar
