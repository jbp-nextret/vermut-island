extends Area3D
class_name Hurtbox

@onready var health: Health = get_parent().get_node("Health")

func rebre_dany(quantitat: int):
	health.rebre_dany(quantitat)
