extends Node
## Arqueologia (autoload): què hi ha enterrat i què has trobat.
##   - Les espècies extingides són a Resources/extintes/*.tres (amb les seves parts)
##   - Els tresors, a TRESORS
##   - botí(zona): sorteja què hi ha en un punt d'excavació
##   - Les troballes importants (rares o llegendàries) es desenterren amb el minijoc

signal troballa(info: Dictionary)

const FITXER := "user://arqueologia.save"
const CARPETA := "res://Resources/extintes/"

## Probabilitat de fòssil (si no, tresor)
const PROB_FOSSIL := 0.55
## Pesos de raresa: [comuna, rara, llegendària]
const PESOS_RARESA := {"principal": [72.0, 24.0, 4.0], "illetes": [55.0, 33.0, 12.0]}

## Tresors: raresa 0 comú, 1 rar, 2 llegendari. "diners" es dona directament.
const TRESORS := [
	{"id": "diners", "raresa": 0, "min": 25, "max": 60, "pes": 3.0},
	{"id": "llavor_raim", "raresa": 0, "min": 2, "max": 4, "pes": 2.0},
	{"id": "olives", "raresa": 0, "min": 2, "max": 4, "pes": 1.5},
	{"id": "ampolla_antiga", "raresa": 1, "min": 1, "max": 1, "pes": 2.0},
	{"id": "amfora_romana", "raresa": 1, "min": 1, "max": 1, "pes": 1.5},
	{"id": "moneda_or", "raresa": 1, "min": 1, "max": 2, "pes": 1.5},
	{"id": "planol", "raresa": 1, "min": 1, "max": 1, "pes": 2.0},
	{"id": "planol", "raresa": 2, "min": 1, "max": 1, "pes": 1.5},
	{"id": "reliquia_antiga", "raresa": 2, "min": 1, "max": 1, "pes": 1.0},
]

const OBJECTES_TRESOR := {
	"ampolla_antiga": {"nom": "Ampolla antiga", "icona": "🍾", "descripcio": "Una ampolla de vermut de fa més de cent anys, encara tapada. Algú la voldrà..."},
	"amfora_romana": {"nom": "Àmfora romana", "icona": "🏺", "descripcio": "Una àmfora sencera. Quedaria preciosa a la vermuteria."},
	"moneda_or": {"nom": "Moneda d'or", "icona": "🪙", "descripcio": "Una moneda antiga d'or. Val molt més que les d'ara."},
	"reliquia_antiga": {"nom": "Relíquia antiga", "icona": "🔱", "descripcio": "Un objecte estrany, tebi al tacte. Potser té a veure amb els santuaris de les illetes."},
	"fragments_fossil": {"nom": "Fragments de fòssil", "icona": "🦴", "descripcio": "Trossos d'os que s'han esmicolat en desenterrar-los. Al laboratori potser serviran."},
}

var especies := {}      # id -> EspecieExtinta
var trobats := {}       # id d'objecte -> quantes vegades l'has trobat
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	for fitxer in ResourceLoader.list_directory(CARPETA):
		if fitxer.ends_with(".tres") or fitxer.ends_with(".res"):
			var e = load(CARPETA + fitxer)
			if e is EspecieExtinta and not e.id.is_empty():
				especies[e.id] = e
	carregar()

# ─────────────── Informació dels objectes (per al CatalegObjectes)

func info_objecte(id: String) -> Dictionary:
	if OBJECTES_TRESOR.has(id):
		return OBJECTES_TRESOR[id]
	if id.begins_with("fossil_"):
		var r := part_de(id)
		if not r.is_empty():
			var e: EspecieExtinta = r.especie
			var p: PartFossil = r.part
			return {"nom": "%s de %s" % [p.nom, e.nom], "icona": "🦴",
				"descripcio": "Fòssil %s d'un %s, una espècie extingida. Amb totes les parts, al laboratori la podràs tornar a la vida." % [PartFossil.NOMS_RARESA[p.raresa], e.nom]}
	return {}

## {especie, part} a partir d'un id "fossil_<especie>_<part>"
func part_de(id_objecte: String) -> Dictionary:
	for e in especies.values():
		for p in e.parts:
			if e.id_objecte(p) == id_objecte:
				return {"especie": e, "part": p}
	return {}

func trobada(id_objecte: String) -> bool:
	return int(trobats.get(id_objecte, 0)) > 0

## Quantes parts diferents d'aquesta espècie has trobat
func parts_trobades(e: EspecieExtinta) -> int:
	return e.parts.filter(func(p): return trobada(e.id_objecte(p))).size()

# ─────────────── Sorteig

## Què hi ha enterrat en un punt (el botí): {tipus: "fossil"/"tresor", id, quantitat, raresa}
func boti(zona: String, generador: RandomNumberGenerator = null) -> Dictionary:
	var r := generador if generador else rng
	if r.randf() < PROB_FOSSIL and not especies.is_empty():
		var e: EspecieExtinta = _triar(especies.values(), func(x): return x.frequencia, r)
		var pesos: Array = PESOS_RARESA.get(zona, PESOS_RARESA.principal)
		var raresa := _index_pes(pesos, r)
		# La part d'aquesta raresa (o la més propera que tingui l'espècie)
		var candidates := e.parts.filter(func(p): return p.raresa == raresa)
		while candidates.is_empty() and raresa > 0:
			raresa -= 1
			candidates = e.parts.filter(func(p): return p.raresa == raresa)
		if candidates.is_empty():
			candidates = e.parts
		var p: PartFossil = candidates[r.randi() % candidates.size()]
		return {"tipus": "fossil", "id": e.id_objecte(p), "quantitat": 1, "raresa": p.raresa}
	var pesos_t: Array = PESOS_RARESA.get(zona, PESOS_RARESA.principal)
	var t: Dictionary = _triar(TRESORS, func(x): return x.pes * pesos_t[x.raresa], r)
	return {"tipus": "tresor", "id": t.id, "quantitat": r.randi_range(t.min, t.max), "raresa": t.raresa}

func _triar(llista: Array, pes: Callable, r: RandomNumberGenerator):
	var total := 0.0
	for x in llista:
		total += pes.call(x)
	var v := r.randf() * total
	for x in llista:
		v -= pes.call(x)
		if v <= 0.0:
			return x
	return llista.back()

func _index_pes(pesos: Array, r: RandomNumberGenerator) -> int:
	var total := 0.0
	for p in pesos:
		total += p
	var v := r.randf() * total
	for i in pesos.size():
		v -= pesos[i]
		if v <= 0.0:
			return i
	return pesos.size() - 1

# ─────────────── Donar el que s'ha trobat

## Posa la troballa a l'inventari (o els diners a la cartera) i avisa
func donar(b: Dictionary, posicio: Vector3 = Vector3.INF):
	var text := ""
	if b.id == "planol":
		# Un plànol: aprens una recepta nova (si ja els tens tots, val una moneda d'or)
		var r: Recepta = Fabricacio.aprendre_planol_nou()
		if r == null:
			b = {"tipus": "tresor", "id": "moneda_or", "quantitat": 1, "raresa": b.raresa}
		else:
			if posicio.is_finite():
				TextFlotant.mostrar(get_tree().current_scene, posicio + Vector3.UP * 1.0, "📜 %s" % CatalegObjectes.info(r.resultat).nom, PartFossil.COLORS_RARESA[clampi(b.raresa, 0, 2)])
			Progressio.guanyar_xp("excavar", 1.0 + b.raresa)
			troballa.emit(b)
			return
	if b.id == "diners":
		Inventari.afegir_diners(b.quantitat)
		text = "+%d 🪙" % b.quantitat
	else:
		Inventari.afegir(b.id, b.quantitat)
		var info := CatalegObjectes.info(b.id)
		text = "+%d %s" % [b.quantitat, info.icona]
		var nova := not trobada(b.id)
		trobats[b.id] = int(trobats.get(b.id, 0)) + b.quantitat
		var nom: String = info.nom
		if b.raresa > 0:
			nom += " (%s)" % PartFossil.NOMS_RARESA[b.raresa]
		EventBus.avis.emit(("📖 Nou fòssil: %s" if nova and b.tipus == "fossil" else "Has trobat: %s") % nom)
	if posicio.is_finite():
		var color: Color = PartFossil.COLORS_RARESA[clampi(b.raresa, 0, 2)]
		TextFlotant.mostrar(get_tree().current_scene, posicio + Vector3.UP * 1.0, text, color)
	Progressio.guanyar_xp("excavar", 1.0 + b.raresa)
	troballa.emit(b)
	guardar()

# ─────────────── Desat

func guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"trobats": trobats}))

func carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		trobats = d.get("trobats", {})
