extends Node
## Fabricació (autoload): les receptes (Resources/receptes/*.tres) i els plànols apresos.
##   Fabricacio.receptes("taula")      les receptes d'un lloc, ordenades
##   Fabricacio.coneguda(r)            si ja la saps fer (no cal plànol o ja l'has trobat)
##   Fabricacio.fer(r, vegades)        gasta els ingredients i dona el resultat
##   Fabricacio.aprendre_planol_nou()  per a l'arqueologia: aprèn un plànol que no tenies

signal fet(recepta: Recepta, vegades: int)
signal planol_apres(recepta: Recepta)

const FITXER := "user://fabricacio.save"
const CARPETA := "res://Resources/receptes/"
const ORDRE_CATEGORIES := ["Construcció", "Eines", "Criatures", "Arqueologia", "Begudes"]

var receptes_totes := {}   # id -> Recepta
var planols := {}          # id de la recepta -> dia que el vas trobar

func _ready():
	for fitxer in ResourceLoader.list_directory(CARPETA):
		if fitxer.ends_with(".tres") or fitxer.ends_with(".res"):
			var r = load(CARPETA + fitxer)
			if r is Recepta and not r.id.is_empty():
				receptes_totes[r.id] = r
	_carregar()

func receptes(lloc: String) -> Array:
	var llista: Array = receptes_totes.values().filter(func(r): return r.lloc == lloc)
	llista.sort_custom(func(a, b):
		var ca := ORDRE_CATEGORIES.find(a.categoria)
		var cb := ORDRE_CATEGORIES.find(b.categoria)
		return ca < cb if ca != cb else a.ordre < b.ordre)
	return llista

func coneguda(r: Recepta) -> bool:
	return not r.planol or planols.has(r.id)

## Quants en tens d'un ingredient ("vermut" compta el preparat i el raïm per trepitjar)
func tinc(ingredient: String) -> int:
	if ingredient == "vermut":
		return Barrica.vermuts_disponibles()
	return Inventari.tenir(ingredient)

## Quantes vegades la pots fer amb el que portes
func vegades_possibles(r: Recepta) -> int:
	if not coneguda(r):
		return 0
	var maxim := 999
	for ing in r.ingredients:
		maxim = mini(maxim, tinc(ing) / maxi(1, r.ingredients[ing]))
	return maxim

func fer(r: Recepta, vegades := 1) -> bool:
	if vegades <= 0 or vegades_possibles(r) < vegades:
		return false
	# Que hi càpiga (si és un objecte nou i la motxilla és plena, no es fa)
	if Inventari.tenir(r.resultat) <= 0 and Inventari.espais_ocupats() >= Inventari.max_espais:
		Inventari.motxilla_plena.emit(r.resultat)
		return false
	for ing in r.ingredients:
		var cal: int = r.ingredients[ing] * vegades
		if ing == "vermut":
			Barrica.gastar_vermuts(cal)
		else:
			Inventari.treure(ing, cal)
	Inventari.afegir(r.resultat, r.quantitat * vegades)
	Progressio.guanyar_xp("fabricar", vegades)
	fet.emit(r, vegades)
	return true

# ─────────────── Plànols

## Aprèn un plànol a l'atzar dels que encara no tens. Retorna la recepta (o null si ja els
## tens tots).
func aprendre_planol_nou() -> Recepta:
	var pendents: Array = receptes_totes.values().filter(func(r): return r.planol and not planols.has(r.id))
	if pendents.is_empty():
		return null
	var r: Recepta = pendents[randi() % pendents.size()]
	planols[r.id] = GestorTemps.dia_actual
	planol_apres.emit(r)
	EventBus.avis.emit("📜 Plànol nou: %s (taula de fabricació)" % CatalegObjectes.info(r.resultat).nom)
	_guardar()
	return r

func planols_pendents() -> int:
	return receptes_totes.values().filter(func(r): return r.planol and not planols.has(r.id)).size()

# ─────────────── Desat

func _guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"planols": planols}))

func _carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		planols = d.get("planols", {})
