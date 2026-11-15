extends RefCounted
class_name Biomes
## Els biomes de les illes. Cada illa en té un, i els recursos que hi surten en fan servir
## els colors (així les roques d'una mateixa illa no es barregen).
##   - La illa principal és un prat.
##   - Les illetes es reparteixen la resta segons el seu ordre.
## Més endavant: el color de les fulles dels arbres i les peces del terra per bioma.

## pedra: índex de Roca3D.PEDRES · molsa: quantes roques en tenen
## enfiladisses: de quin color són les plantes de les columnes de les ruïnes i quantes
## n'hi ha (probabilitat de cada tros de planta del model)
const BIOMES := {
	"prat":    {"nom": "Prat",          "pedra": 0, "molsa": 0.6,  "enfiladisses": [Color(0.27, 0.5, 0.22), 0.6]},    # pedra grisa
	"costa":   {"nom": "Costa",         "pedra": 1, "molsa": 0.15, "enfiladisses": [Color(0.62, 0.58, 0.28), 0.35]},  # sorrenca, plantes seques
	"bosc":    {"nom": "Bosc humit",    "pedra": 2, "molsa": 0.9,  "enfiladisses": [Color(0.16, 0.4, 0.17), 1.0]},    # blavosa i molsosa
	"argila":  {"nom": "Terres roges",  "pedra": 3, "molsa": 0.3,  "enfiladisses": [Color(0.72, 0.4, 0.16), 0.5]},    # rogenca, de tardor
	"volca":   {"nom": "Volcà",         "pedra": 4, "molsa": 0.0,  "enfiladisses": [Color(0.3, 0.27, 0.25), 0.0]},    # basalt, sense plantes
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
