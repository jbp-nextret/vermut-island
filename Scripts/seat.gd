extends Marker3D
class_name Seat

var occupant: Node = null
## La barra que fa de taula d'aquest seient. La reparteix CasaInterior
## (cada barra només serveix un seient); null si no n'hi toca cap.
var taula_assignada: Node3D = null
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

func taula() -> Node3D:
	if is_instance_valid(taula_assignada) and not taula_assignada.is_queued_for_deletion():
		return taula_assignada
	return null

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
