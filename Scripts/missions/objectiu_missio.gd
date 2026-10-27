@tool
extends Resource
class_name ObjectiuMissio
## Un objectiu d'una missió (s'edita a l'inspector de Godot).
##  - PARLAR: parlar amb un NPC (el seu `id`)
##  - PORTAR: tenir objectes a la motxilla; es lliuren (i es gasten) en acabar la missió
##  - ACCIO: fer una acció unes quantes vegades (matar enemics, collir, plantar...)
##  - ARRIBAR: arribar a una ZonaMissio (pel seu `id`)

enum Tipus { PARLAR, PORTAR, ACCIO, ARRIBAR }

## Accions que es poden comptar (són els mateixos noms que l'experiència de Progressio)
const ACCIONS := {
	"enemic": "Derrota enemics",
	"onada": "Supera onades",
	"collir": "Cull cultius",
	"plantar": "Planta cultius",
	"regar": "Rega cultius",
	"llaurar": "Llaura terra",
	"talar": "Tala arbres",
	"picar": "Pica roques",
	"herba": "Talla herba",
	"servir": "Serveix clients",
	"obrir_vermuteria": "Obre la vermuteria",
}

@export var tipus: Tipus = Tipus.PARLAR:
	set(v):
		tipus = v
		notify_property_list_changed()
## Text que surt al registre. Si és buit, se'n fa un automàticament.
@export var descripcio := ""
## PARLAR: l'id de l'NPC
@export var npc := ""
## PORTAR: l'id de l'objecte
@export var objecte := ""
## ACCIO: quina acció
@export_enum("enemic", "onada", "collir", "plantar", "regar", "llaurar", "talar", "picar", "herba", "servir", "obrir_vermuteria") var accio := "enemic"
## PORTAR i ACCIO: quantes
@export var quantitat := 1
## ARRIBAR: l'id de la ZonaMissio
@export var lloc := ""

func _validate_property(propietat: Dictionary):
	var visibles := {
		Tipus.PARLAR: ["npc"],
		Tipus.PORTAR: ["objecte", "quantitat"],
		Tipus.ACCIO: ["accio", "quantitat"],
		Tipus.ARRIBAR: ["lloc"],
	}
	if propietat.name in ["npc", "objecte", "accio", "quantitat", "lloc"] and not propietat.name in visibles[tipus]:
		propietat.usage = PROPERTY_USAGE_NO_EDITOR

## Quant fa falta per completar-lo (1 per a PARLAR i ARRIBAR)
func objectiu() -> int:
	return quantitat if tipus in [Tipus.PORTAR, Tipus.ACCIO] else 1

func text(progres: int) -> String:
	var t := descripcio
	if t.is_empty():
		match tipus:
			Tipus.PARLAR:
				t = "Parla amb %s" % npc.capitalize()
			Tipus.PORTAR:
				var info := CatalegObjectes.info(objecte)
				t = "Porta %s %s" % [info.icona, info.nom]
			Tipus.ACCIO:
				t = ACCIONS.get(accio, accio)
			Tipus.ARRIBAR:
				t = "Ves a %s" % lloc.capitalize()
	if objectiu() > 1:
		t += " (%d/%d)" % [mini(progres, objectiu()), objectiu()]
	return t
