@tool
extends Resource
class_name ArbreDef
## Un arbre d'habilitats (s'edita a l'inspector de Godot).

@export var id := ""
@export var nom := ""
@export var icona := "✨"
@export var color := Color.WHITE
@export var habilitats: Array[Habilitat] = []
