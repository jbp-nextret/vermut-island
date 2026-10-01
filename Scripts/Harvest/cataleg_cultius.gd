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

# Mateixos números que l'enum TipusCultiu de cultiu.gd
const NORMAL := 0
const DEFENSA_RANGED := 1
const DEFENSA_MELEE := 2
const VINYEDO := 3
const FLOR := 4
const ESQUER := 5
const ORTIGA := 6

## Nom del tipus i una icona curta per a la roda i el HUD
const TIPUS := {
	NORMAL: {"nom": "Collita", "insignia": "🌾"},
	DEFENSA_RANGED: {"nom": "Torre a distància", "insignia": "🏹"},
	DEFENSA_MELEE: {"nom": "Torre cos a cos", "insignia": "🦷"},
	VINYEDO: {"nom": "Collita", "insignia": "🍇"},
	FLOR: {"nom": "Suport", "insignia": "🌼"},
	ESQUER: {"nom": "Esquer", "insignia": "🎃"},
	ORTIGA: {"nom": "Trampa", "insignia": "🌿"},
}

## Llegeix de cada escena tot el que cal per a la roda, el HUD i la vista prèvia
## Cultius que cal desbloquejar amb l'habilitat "Botànica": índex a TOTS -> rang necessari
const BOTANICA := {3: 1, 5: 2, 4: 3}   # Calèndula, Ortiga, Carbassa esquer

static func desbloquejat(index: int) -> bool:
	return Progressio.rang("botanica") >= BOTANICA.get(index, 0)

static func text_bloqueig(index: int) -> String:
	return "🔒 Desbloqueja-ho a Mundà → Botànica (rang %d)" % BOTANICA.get(index, 0)

static func opcions_roda() -> Array:
	var opcions := []
	for escena in TOTS:
		var c = escena.instantiate()
		var tipus: int = c.tipus_cultiu
		opcions.append({
			"nom": c.nom_cultiu,
			"descripcio": c.descripcio,
			"textura": c.textures.back() if c.textures.size() > 0 else null,
			"color": c.tint,
			"radi": c.radi_efecte(),
			"tipus": tipus,
			"tipus_nom": TIPUS[tipus].nom,
			"insignia": TIPUS[tipus].insignia,
			"es_distancia": tipus == DEFENSA_RANGED,
			"estadistiques": _estadistiques(c),
		})
		c.free()
	return opcions

static func _estadistiques(c) -> String:
	var parts := ["❤ %d" % c.vida_maxima]
	match int(c.tipus_cultiu):
		DEFENSA_RANGED, DEFENSA_MELEE:
			parts.append("⚔ %d" % c.defensa_dany_base)
			parts.append("abast %s" % str(snappedf(c.defensa_range, 0.1)))
		FLOR:
			parts.append("+%d%% dany · −%d%% mal rebut" % [roundi(c.modificador_dany * 100), roundi(c.proteccio * 100)])
		ORTIGA:
			parts.append("enemics al %d%% de velocitat" % roundi(c.alentiment * 100))
		VINYEDO, NORMAL:
			parts.append("🍇 %d-%d" % [c.raim_min, c.raim_max])
	return "   ".join(parts)
