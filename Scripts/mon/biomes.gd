extends RefCounted
class_name Biomes
## Els biomes de les illes. Cada illa en té un, i els recursos que hi surten en fan servir
## els colors (així les roques d'una mateixa illa no es barregen).
##   - La illa principal és un prat.
##   - Les illetes es reparteixen la resta segons el seu ordre.
## Més endavant: el color de les fulles dels arbres i les peces del terra per bioma.

const BIOMES := {
	"prat":    {"nom": "Prat",          "pedra": 0, "molsa": 0.6},    # pedra grisa
	"costa":   {"nom": "Costa",         "pedra": 1, "molsa": 0.15},   # sorrenca
	"bosc":    {"nom": "Bosc humit",    "pedra": 2, "molsa": 0.9},    # blavosa i molsosa
	"argila":  {"nom": "Terres roges",  "pedra": 3, "molsa": 0.3},    # rogenca
	"volca":   {"nom": "Volcà",         "pedra": 4, "molsa": 0.0},    # basalt
}
## L'ordre en què es reparteixen a les illetes (la primera és la més propera al moll)
const ORDRE_ILLETES := ["costa", "bosc", "argila", "volca"]

## Les illetes: [{centre: Vector3, radi: float, bioma: String}]
static var illes: Array = []

static func registrar(illetes: Array, propera: int):
	illes.clear()
	var n := 0
	# La més propera primer (és la de la missió), després la resta per ordre
	var ordre := range(illetes.size())
	if propera >= 0:
		ordre.erase(propera)
		ordre.push_front(propera)
	for i in ordre:
		illes.append({"centre": illetes[i].centre, "radi": float(illetes[i].radi), "bioma": ORDRE_ILLETES[n % ORDRE_ILLETES.size()]})
		n += 1

## El bioma d'un punt del món
static func a(posicio: Vector3) -> String:
	for illa in illes:
		if Vector2(posicio.x - illa.centre.x, posicio.z - illa.centre.z).length() <= illa.radi + 4.0:
			return illa.bioma
	return "prat"

static func dades(posicio: Vector3) -> Dictionary:
	return BIOMES[a(posicio)]
