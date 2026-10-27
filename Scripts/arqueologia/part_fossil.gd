@tool
extends Resource
class_name PartFossil
## Una part fòssil d'una espècie extingida (crani, vèrtebra, urpa...).
## L'objecte de l'inventari és "fossil_<espècie>_<part>".

enum Raresa { COMUNA, RARA, LLEGENDARIA }

const NOMS_RARESA := ["comuna", "rara", "llegendària"]
const COLORS_RARESA := [Color(0.85, 0.82, 0.75), Color(0.45, 0.75, 1.0), Color(1.0, 0.7, 0.25)]

@export var id := ""
@export var nom := ""
@export var raresa: Raresa = Raresa.COMUNA
