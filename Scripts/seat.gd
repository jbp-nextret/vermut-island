extends Marker3D
class_name Seat

var occupant: Node = null

func _ready():
	add_to_group("seats")

func is_free() -> bool:
	return occupant == null

func get_sit_position() -> Vector3:
	return global_position
