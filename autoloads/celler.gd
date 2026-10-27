extends Node
## Celler (autoload): què hi ha a cada barrica de la vermuteria.
## Cada barrica fa UNA sola cosa: hi poses una recepta a fermentar, triga unes hores (de
## joc, només passen quan ets fora de casa) i després hi queda guardada com en un cofre.
## Mentre serveixes, els gots s'omplen d'aquí.
##   Celler.estat(clau)            {} si és buida; si no {producte, quantitat, fi}
##   Celler.fermentar(clau, r, n)  posa una recepta a fermentar
##   Celler.treure / guardar       com un cofre (de la barrica a la motxilla i al revés)
##   Celler.estoc(producte)        quants n'hi ha a punt entre totes les barriques

signal canviat(clau: String)

const FITXER := "user://celler.save"
const CAPACITAT := 24

## Les begudes que es poden servir als clients (preu base i color del got)
const SERVIBLES := {
	"vermut": {"preu": 10, "color": Color(1, 1, 1)},
	"vermut_blanc": {"preu": 14, "color": Color(1.0, 0.95, 0.6)},
	"vermut_reserva": {"preu": 22, "color": Color(0.75, 0.45, 0.45)},
}

var barriques := {}   # clau ("x,z") -> {producte, quantitat, fi (hora absoluta), recepta}

func _ready():
	_carregar()

## La clau d'una barrica: la cel·la on és el moble
static func clau(posicio: Vector3) -> String:
	return "%d,%d" % [roundi(posicio.x), roundi(posicio.z)]

## Hora absoluta del joc (dia × 24 + hora)
static func ara() -> float:
	return GestorTemps.dia_actual * 24.0 + GestorTemps.hora_actual

func estat(c: String) -> Dictionary:
	return barriques.get(c, {})

func buida(c: String) -> bool:
	return estat(c).is_empty()

func fermentant(c: String) -> bool:
	var e := estat(c)
	return not e.is_empty() and ara() < float(e.fi)

## El que hi ha a punt per treure o servir (0 si és buida o encara fermenta)
func a_punt(c: String) -> int:
	var e := estat(c)
	if e.is_empty() or ara() < float(e.fi):
		return 0
	return int(e.quantitat)

func hores_que_queden(c: String) -> float:
	var e := estat(c)
	return 0.0 if e.is_empty() else maxf(0.0, float(e.fi) - ara())

## De 0 a 1
func progres(c: String) -> float:
	var e := estat(c)
	if e.is_empty():
		return 0.0
	var durada := float(e.get("durada", 1.0))
	return clampf(1.0 - hores_que_queden(c) / maxf(0.01, durada), 0.0, 1.0)

# ─────────────── Fermentar

## Quantes unitats surten (el "Mestre vermuter" en fa sortir més de les begudes amb raïm)
static func quantitat_resultat(r: Recepta, vegades: int) -> int:
	var extra := 0
	if r.categoria == "Begudes" and r.ingredients.has("raim"):
		extra = roundi(Progressio.valor("vermuter")) * vegades
	return r.quantitat * vegades + extra

## Com a màxim, quantes vegades hi caben a la barrica
static func vegades_maximes(r: Recepta) -> int:
	return maxi(1, CAPACITAT / maxi(1, quantitat_resultat(r, 1)))

func pot_fermentar(c: String, r: Recepta, vegades: int) -> String:
	if not buida(c):
		return "La barrica no és buida"
	if not Fabricacio.coneguda(r):
		return "No saps fer-ho"
	if vegades > vegades_maximes(r):
		return "No hi cap"
	if Fabricacio.vegades_possibles(r) < vegades:
		return "Falta material"
	return ""

func fermentar(c: String, r: Recepta, vegades: int) -> bool:
	if not pot_fermentar(c, r, vegades).is_empty():
		return false
	Fabricacio.gastar_ingredients(r, vegades)
	barriques[c] = {
		"producte": r.resultat,
		"quantitat": quantitat_resultat(r, vegades),
		"fi": ara() + r.hores,
		"durada": r.hores,
		"recepta": r.id,
	}
	Progressio.guanyar_xp("fabricar", vegades)
	Fabricacio.fet.emit(r, vegades)
	_canvi(c)
	return true

# ─────────────── Com un cofre

## De la barrica a la motxilla. Retorna quants n'ha tret.
func treure(c: String, n: int) -> int:
	var hi_ha := a_punt(c)
	n = mini(n, hi_ha)
	if n <= 0:
		return 0
	var producte: String = estat(c).producte
	if Inventari.tenir(producte) <= 0 and Inventari.espais_ocupats() >= Inventari.max_espais:
		Inventari.motxilla_plena.emit(producte)
		return 0
	Inventari.afegir(producte, n)
	_restar(c, n)
	return n

## De la motxilla a la barrica (si és buida o ja té el mateix). Retorna quants n'ha posat.
func guardar(c: String, producte: String, n: int) -> int:
	if fermentant(c):
		return 0
	var e := estat(c)
	if not e.is_empty() and e.producte != producte:
		return 0
	var hi_ha := 0 if e.is_empty() else int(e.quantitat)
	n = mini(mini(n, Inventari.tenir(producte)), CAPACITAT - hi_ha)
	if n <= 0:
		return 0
	Inventari.treure(producte, n)
	posar(c, producte, n)
	return n

## Hi afegeix `n` unitats ja fetes (guardar, o un got que es torna)
func posar(c: String, producte: String, n: int):
	var e := estat(c)
	if e.is_empty():
		barriques[c] = {"producte": producte, "quantitat": n, "fi": ara(), "durada": 0.0, "recepta": ""}
	else:
		e.quantitat = int(e.quantitat) + n
	_canvi(c)

## En treu una per omplir un got
func servir_un(c: String) -> String:
	if a_punt(c) <= 0:
		return ""
	var producte: String = estat(c).producte
	_restar(c, 1)
	return producte

func _restar(c: String, n: int):
	var e := estat(c)
	e.quantitat = int(e.quantitat) - n
	if e.quantitat <= 0:
		barriques.erase(c)
	_canvi(c)

# ─────────────── Per al servei

## Quantes n'hi ha a punt de `producte`, sumant totes les barriques
func estoc(producte: String) -> int:
	var total := 0
	for c in barriques:
		if barriques[c].producte == producte:
			total += a_punt(c)
	return total

static func preu(producte: String) -> int:
	return SERVIBLES.get(producte, {"preu": 10}).preu

static func color(producte: String) -> Color:
	return SERVIBLES.get(producte, {"color": Color.WHITE}).color

# ─────────────── Desat

func _canvi(c: String):
	canviat.emit(c)
	_guardar()

func _guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"barriques": barriques}))

func _carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and d.get("barriques") is Dictionary:
		barriques = d.barriques
