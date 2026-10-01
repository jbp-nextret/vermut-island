class_name ArbreHabilitats
## Els tres arbres d'habilitats. Les dades són a Resources/habilitats/*.tres i s'editen
## des de l'inspector de Godot: nom, icona, rangs, valor per rang, posició al menú i
## requisits (una altra habilitat, un nivell, objectes o diners).

const ARBRES := [
	preload("res://Resources/habilitats/atac.tres"),
	preload("res://Resources/habilitats/util.tres"),
	preload("res://Resources/habilitats/munda.tres"),
]

static func habilitat(id: String) -> Habilitat:
	for arbre in ARBRES:
		for h in arbre.habilitats:
			if h.id == id:
				return h
	return null

## Compatibilitat: text de l'efecte amb un nombre de rangs concret
static func text_efecte(h: Habilitat, rangs: int) -> String:
	return h.text_efecte(rangs)
