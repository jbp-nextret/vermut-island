@tool
extends Resource
class_name EspecieExtinta
## Una espècie extingida de l'illa (s'edita a l'inspector). Els fòssils de les seves
## parts es desenterren amb l'aixada. Més endavant, al laboratori, amb totes les parts
## i l'ADN barrejat amb objectes es podrà tornar a la vida.

@export var id := ""
@export var nom := ""
@export_multiline var descripcio := ""
## Època o curiositat (surt al bestiari)
@export var epoca := ""
@export var parts: Array[PartFossil] = []
## Probabilitat relativa de trobar-ne fòssils
@export var frequencia := 1.0
## Per al futur laboratori: què farà quan torni a la vida
@export_multiline var habilitat_reviscuda := ""

@export_group("Aspecte")
@export var color := Color(0.85, 0.8, 0.68)

func part(id_part: String) -> PartFossil:
	for p in parts:
		if p.id == id_part:
			return p
	return null

func id_objecte(p: PartFossil) -> String:
	return "fossil_%s_%s" % [id, p.id]
