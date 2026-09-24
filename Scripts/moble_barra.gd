extends Node3D
class_name MobleBarra

enum Tipus { SEIENT, BARRA, DECORACIO, BARRICA }

## Quin tipus de moble és. Decideix les regles de col·locació i els grups.
@export var tipus: Tipus = Tipus.SEIENT

## Només cal si l'arrel de l'escena NO és ja el model (.glb).
## Els mobles actuals ja són instàncies del .glb, així que es deixa buit.
@export var model_path: String
@export var escala_model: float = 1

func _ready():
	if model_path.is_empty():
		return
	var model = load(model_path)
	if model:
		var instance = model.instantiate()
		add_child(instance)
		instance.scale = Vector3.ONE * escala_model
	else:
		push_warning("Model no trobat: " + model_path)
