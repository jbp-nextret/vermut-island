@tool
extends Resource
class_name Requisit
## Una condició per desbloquejar una habilitat (s'edita a l'inspector de Godot).
##  - HABILITAT: tenir una altra habilitat a cert rang
##  - NIVELL: el jugador ha de ser almenys d'aquest nivell
##  - OBJECTE: tenir cert objecte a la motxilla (i, si `consumir`, es gasta en desbloquejar)
##  - DINERS: tenir prou diners (i, si `consumir`, es gasten en desbloquejar)

enum Tipus { HABILITAT, NIVELL, OBJECTE, DINERS }

@export var tipus: Tipus = Tipus.HABILITAT:
	set(v):
		tipus = v
		notify_property_list_changed()
## Per a HABILITAT: l'id de l'habilitat (p. ex. "dany_espasa")
@export var habilitat := ""
## Per a HABILITAT: el rang mínim
@export var rang := 1
## Per a NIVELL: el nivell mínim
@export var nivell := 1
## Per a OBJECTE: l'id de l'objecte (p. ex. "raim")
@export var objecte := ""
## Per a OBJECTE i DINERS: quantitat necessària
@export var quantitat := 1
## Per a OBJECTE i DINERS: si es gasten en desbloquejar l'habilitat
@export var consumir := true

## Només mostra a l'inspector els camps del tipus triat
func _validate_property(propietat: Dictionary):
	var visibles := {
		Tipus.HABILITAT: ["habilitat", "rang"],
		Tipus.NIVELL: ["nivell"],
		Tipus.OBJECTE: ["objecte", "quantitat", "consumir"],
		Tipus.DINERS: ["quantitat", "consumir"],
	}
	var tots := ["habilitat", "rang", "nivell", "objecte", "quantitat", "consumir"]
	if propietat.name in tots and not propietat.name in visibles[tipus]:
		propietat.usage = PROPERTY_USAGE_NO_EDITOR

## Els autoloads es busquen en el moment (és un script @tool: a l'editor no hi són)
static func _autoload(nom: String) -> Node:
	var arbre := Engine.get_main_loop() as SceneTree
	return arbre.root.get_node_or_null(nom) if arbre else null

func complert() -> bool:
	var progressio := _autoload("Progressio")
	var inventari := _autoload("Inventari")
	if progressio == null or inventari == null:
		return false
	match tipus:
		Tipus.HABILITAT:
			return progressio.rang(habilitat) >= rang
		Tipus.NIVELL:
			return progressio.nivell >= nivell
		Tipus.OBJECTE:
			return inventari.tenir(objecte) >= quantitat
		Tipus.DINERS:
			return inventari.diners >= quantitat
	return true

## Gasta el que calgui en desbloquejar (només objectes i diners amb `consumir`)
func pagar() -> void:
	var inventari := _autoload("Inventari")
	if not consumir or inventari == null:
		return
	match tipus:
		Tipus.OBJECTE:
			inventari.treure(objecte, quantitat)
		Tipus.DINERS:
			inventari.gastar_diners(quantitat)

func text() -> String:
	match tipus:
		Tipus.HABILITAT:
			var h = ArbreHabilitats.habilitat(habilitat)
			return "%s al rang %d" % [h.nom if h else habilitat, rang]
		Tipus.NIVELL:
			return "Nivell %d" % nivell
		Tipus.OBJECTE:
			var info := CatalegObjectes.info(objecte)
			return "%s %d %s%s" % [info.icona, quantitat, info.nom, " (es gasten)" if consumir else ""]
		Tipus.DINERS:
			return "🪙 %d%s" % [quantitat, " (es gasten)" if consumir else ""]
	return ""
