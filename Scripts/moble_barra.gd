extends Node3D

@export var model_path: String
@export var escala_model: float = 1

func _ready():
	var model = load(model_path)
	if model:
		var instance = model.instantiate()
		add_child(instance)
		
		# Aplica escala
		scale = Vector3.ONE * escala_model
		
		print("Model carregat: ", model_path)
		print("Escala aplicada: ", scale)
	else:
		print("Error: Model no trobat - ", model_path)
