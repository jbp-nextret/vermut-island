class_name Decoracio
## Nivells de decoració de la vermuteria: com més punts, més propina deixen els clients.

## Cada còpia repetida d'un mateix moble val aquesta fracció de l'anterior
## (1a: 100 %, 2a: 70 %, 3a: 49 %...). Així omplir-ho tot de cactus no surt a compte.
const REPETICIO := 0.7

const NIVELLS := [
	{"min": 0, "nom": "Desangelada", "propina": 0.5},
	{"min": 5, "nom": "Acollidora", "propina": 1.0},
	{"min": 15, "nom": "Encantadora", "propina": 1.5},
	{"min": 30, "nom": "Espectacular", "propina": 2.0},
]

static func nivell(punts: int) -> Dictionary:
	var resultat: Dictionary = NIVELLS[0]
	for n in NIVELLS:
		if punts >= n.min:
			resultat = n
	return resultat

## El nivell següent, o {} si ja és el màxim
static func seguent_nivell(punts: int) -> Dictionary:
	for n in NIVELLS:
		if punts < n.min:
			return n
	return {}
