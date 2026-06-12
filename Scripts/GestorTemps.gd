extends Node

signal dia_nou

var dia_actual = 1

func passar_dia():
	dia_actual += 1
	emit_signal("dia_nou")
	# Avisa tots els cultius
	get_tree().call_group("cultius", "passar_dia")
