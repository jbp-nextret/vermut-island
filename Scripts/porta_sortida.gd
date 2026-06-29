extends Area3D

signal salir_casa

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Personatge":
		salir_casa.emit()
