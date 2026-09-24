class_name CatalegCultius
## Tots els cultius que es poden plantar, en l'ordre de la roda de selecció.

const TOTS := [
	preload("res://Scenes/Cultiu.tscn"),                        # Planta llançadora (torre a distància)
	preload("res://Scenes/cultius/planta_mossegadora.tscn"),    # torre cos a cos
	preload("res://Scenes/cultius/cep.tscn"),                   # dona raïm
	preload("res://Scenes/cultius/calendula.tscn"),             # millora i protegeix els veïns
	preload("res://Scenes/cultius/carbassa_esquer.tscn"),       # atrau els enemics
	preload("res://Scenes/cultius/ortiga.tscn"),                # alenteix els enemics
]

## Llegeix de cada escena el nom, la descripció, la icona i el color per a la roda
static func opcions_roda() -> Array:
	var opcions := []
	for escena in TOTS:
		var c = escena.instantiate()
		opcions.append({
			"nom": c.nom_cultiu,
			"descripcio": c.descripcio,
			"textura": c.textures.back() if c.textures.size() > 0 else null,
			"color": c.tint,
			"radi": c.radi_efecte(),
		})
		c.free()
	return opcions
