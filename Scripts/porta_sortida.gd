extends Area3D

signal salir_casa

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.name == "Personatge":
		if Input.is_action_just_pressed("accio_secundaria"):
			salir_casa.emit()
