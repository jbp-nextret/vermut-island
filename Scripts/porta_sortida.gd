extends Area3D

signal salir_casa

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("player"):
		salir_casa.emit()
