@tool
extends Resource
class_name Missio
## Una missió (s'edita a l'inspector de Godot). Les missions són a Resources/missions/.

@export var id := ""
@export var titol := ""
@export_multiline var descripcio := ""
## L'id de l'NPC que la dona (i a qui es lliura)
@export var donant := ""
@export var objectius: Array[ObjectiuMissio] = []

@export_group("Quan està disponible")
## Missions que s'han d'haver completat abans
@export var missions_previes: PackedStringArray = []
## Altres condicions: nivell, objectes, diners, habilitats (els mateixos de les habilitats)
@export var requisits: Array[Requisit] = []

@export_group("Recompenses")
@export var diners := 0
@export var xp := 0
## { id de l'objecte: quantitat }
@export var objectes := {}

func text_recompenses() -> String:
	var parts := []
	if diners > 0:
		parts.append("🪙 %d" % diners)
	if xp > 0:
		parts.append("%d XP" % xp)
	for o in objectes:
		var info := CatalegObjectes.info(o)
		parts.append("%s %d" % [info.icona, objectes[o]])
	return " · ".join(parts)
