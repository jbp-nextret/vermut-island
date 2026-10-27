extends Node3D
class_name MobleBarra

enum Tipus { SEIENT, BARRA, DECORACIO, BARRICA, OBJECTE_PARET }

## Quin tipus de moble és. Decideix les regles de col·locació i els grups.
## OBJECTE_PARET es penja a les parets (finestres, prestatges...) en lloc d'anar a terra.
@export var tipus: Tipus = Tipus.SEIENT

## Quant suma a la decoració de la vermuteria (i, per tant, a les propines).
## Les còpies repetides d'un mateix moble sumen cada cop menys.
@export var punts_decoracio := 0

## Només per als objectes de paret: a quina alçada es pengen (el centre de l'objecte).
## Convenció dels models: l'origen a la cara que toca la paret, i el davant mirant a +Z.
@export var alcada_paret := 1.2

## Només cal si l'arrel de l'escena NO és ja el model (.glb).
## Els mobles actuals ja són instàncies del .glb, així que es deixa buit.
@export var model_path: String
@export var escala_model: float = 1

func _ready():
	MaterialsRetallats.aplicar(self)
	if model_path.is_empty():
		return
	var model = load(model_path)
	if model:
		var instance = model.instantiate()
		add_child(instance)
		instance.scale = Vector3.ONE * escala_model
	else:
		push_warning("Model no trobat: " + model_path)
