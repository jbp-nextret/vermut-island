extends Marker3D
class_name Seat

var occupant: Node = null

func _ready():
	# Només compta com a seient si el moble està col·locat de veritat.
	# La preview del mode construcció no és a "mobles_base".
	if get_parent().is_in_group("mobles_base"):
		add_to_group("seats")

func is_free() -> bool:
	return occupant == null

func get_sit_position() -> Vector3:
	return global_position
