extends Node
## Criatures domesticades (autoload): la col·lecció i quina et segueix (només una alhora).
## Les espècies es carreguen de Resources/criatures/*.tres.
##
##   Criatures.capturar(especie)   la domestica (i si no en tens cap fora, et segueix)
##   Criatures.activar(uid)        que et segueixi aquesta ("" = cap)
##   Criatures.bonus("velocitat")  el que suma la que et segueix (VELOCITAT, DEFENSA)

signal col_leccio_canviada
signal activa_canviada
signal criatura_capturada(dades: Dictionary)
signal nivell_pujat(uid: String, nivell: int)
signal assignacions_canviades
## Una criatura del corral (o d'una tasca) ha produït alguna cosa
signal produccio(uid: String, objecte: String)
## Primera vegada que veus una espècie (per al bestiari)
signal especie_vista(especie: EspecieCriatura)

const FITXER := "user://criatures.save"
const CARPETA := "res://Resources/criatures/"

var especies := {}       # id -> EspecieCriatura
## [{uid, especie, nom, dia}]
var col_leccio: Array = []
var activa := ""         # uid de la que et segueix
## Bestiari: espècies que has vist alguna vegada i quantes n'has domesticat en total
var vistes := {}         # id -> dia que la vas veure per primer cop
var domesticades := {}   # id -> quantes (encara que ja no les tinguis)
var companya: Node3D = null
var _escena_actual: Node = null

func _ready():
	for fitxer in ResourceLoader.list_directory(CARPETA):
		if fitxer.ends_with(".tres") or fitxer.ends_with(".res"):
			var e = load(CARPETA + fitxer)
			if e is EspecieCriatura and not e.id.is_empty():
				especies[e.id] = e
	carregar()

func especie(id: String) -> EspecieCriatura:
	return especies.get(id)

func dades(uid: String) -> Dictionary:
	for d in col_leccio:
		if d.uid == uid:
			return d
	return {}

func especie_activa() -> EspecieCriatura:
	var d := dades(activa)
	return especie(d.especie) if not d.is_empty() else null

## Quantes n'has domesticat d'aquesta espècie
func quantes(especie_id: String) -> int:
	return col_leccio.filter(func(d): return d.especie == especie_id).size()

# ─────────────── Corral i tasques

## Què fa cada criatura domesticada ("seguint" és la que va amb tu)
const ASSIGNACIONS := {"": "😴 Descansa", "seguint": "🐾 Et segueix", "corral": "🏡 Al corral",
	"talar": "🪓 Talar arbres", "picar": "⛏️ Picar roques", "herba": "🌾 Tallar herba"}
## Tasques a l'aire lliure: què treuen i cada quants minuts de joc (a nivell 1)
const TASQUES := {"talar": {"objecte": "fusta", "minuts": 60}, "picar": {"objecte": "pedra", "minuts": 60}, "herba": {"objecte": "fibra", "minuts": 45}}
## Quantes criatures hi caben en total als corrals que has construït (amb tanques).
## Es recorda encara que no siguis al món (p. ex. a dins de casa), per a la producció.
var capacitat_corrals := 0
const XP_PRODUCCIO := 5

## El que han produït les criatures i encara no has recollit (a la cistella del corral)
var magatzem := {}
var ultim_minut := -1.0

func assignacio(uid: String) -> String:
	if uid == activa:
		return "seguint"
	return str(dades(uid).get("assignacio", ""))

func amb_assignacio(a: String) -> Array:
	return col_leccio.filter(func(d): return assignacio(d.uid) == a).map(func(d): return d.uid)

func assignar(uid: String, a: String) -> bool:
	var d := dades(uid)
	if d.is_empty() or not ASSIGNACIONS.has(a):
		return false
	if a in ["corral", "talar", "picar", "herba"] and capacitat_corrals <= 0:
		EventBus.avis.emit("Primer construeix un corral: tanca una zona amb tanques de fusta")
		return false
	if a == "corral" and assignacio(uid) != "corral" and amb_assignacio("corral").size() >= capacitat_corrals:
		EventBus.avis.emit("Els corrals són plens (%d criatures). Fes-los més grans!" % capacitat_corrals)
		return false
	if a == "seguint":
		d.assignacio = ""
		activar(uid)
	else:
		if uid == activa:
			activar("")
		d.assignacio = a
	d.progres_feina = 0.0
	assignacions_canviades.emit()
	col_leccio_canviada.emit()
	guardar()
	return true

## Cada quants minuts produeix (més ràpid com més nivell)
func minuts_produccio(uid: String) -> float:
	var d := dades(uid)
	var e := especie(d.get("especie", ""))
	var a := assignacio(uid)
	var base: float = e.minuts_produccio if a == "corral" and e else TASQUES.get(a, {}).get("minuts", 60)
	return base / mult_habilitat(nivell(uid))

func objecte_produccio(uid: String) -> String:
	var a := assignacio(uid)
	if a == "corral":
		var e := especie(dades(uid).especie)
		return e.produccio if e else ""
	return TASQUES.get(a, {}).get("objecte", "")

func _minut_ara() -> float:
	return (GestorTemps.dia_actual * 24.0 + GestorTemps.hora_actual) * 60.0

## El temps de joc passa (també quan no hi ets): les criatures produeixen
func _produir():
	var ara := _minut_ara()
	if ultim_minut < 0.0:
		ultim_minut = ara
		return
	var passat := minf(ara - ultim_minut, 3.0 * 24.0 * 60.0)
	if passat < 1.0:
		return
	ultim_minut = ara
	var al_corral := amb_assignacio("corral")
	for d in col_leccio:
		var objecte := objecte_produccio(d.uid)
		if objecte.is_empty() or capacitat_corrals <= 0:
			continue
		# Si has fet els corrals més petits, les que no hi caben no produeixen
		if assignacio(d.uid) == "corral" and al_corral.find(d.uid) >= capacitat_corrals:
			continue
		d.progres_feina = float(d.get("progres_feina", 0.0)) + passat
		var interval := minuts_produccio(d.uid)
		while d.progres_feina >= interval:
			d.progres_feina -= interval
			magatzem[objecte] = int(magatzem.get(objecte, 0)) + 1
			guanyar_xp(d.uid, XP_PRODUCCIO)
			produccio.emit(d.uid, objecte)

## Passa el que hi ha a la cistella a la motxilla. Retorna quants objectes.
func recollir() -> int:
	var total := 0
	for objecte in magatzem.keys():
		var q := int(magatzem[objecte])
		if q <= 0:
			continue
		if Inventari.afegir(objecte, q):
			total += q
			magatzem.erase(objecte)
	guardar()
	return total

func objectes_magatzem() -> int:
	var total := 0
	for q in magatzem.values():
		total += int(q)
	return total

## Reparteix les criatures entre els corrals (les de tasques surten del primer)
func repartir_corrals(corrals: Array):
	var al_corral := amb_assignacio("corral")
	var i := 0
	for n in corrals.size():
		var c = corrals[n]
		if not is_instance_valid(c):
			continue
		var volem := {}
		for k in c.capacitat():
			if i < al_corral.size():
				volem[al_corral[i]] = "corral"
				i += 1
		if n == 0:
			for a in ["talar", "picar", "herba"]:
				for uid in amb_assignacio(a):
					volem[uid] = a
		c.posar_criatures(volem)

# ─────────────── Nivells

const NIVELL_MAXIM := 20

## Experiència per passar del nivell `n` al següent
static func xp_per_nivell(n: int) -> int:
	return 20 + 15 * (n - 1)

func nivell(uid: String) -> int:
	return int(dades(uid).get("nivell", 1))

func xp(uid: String) -> int:
	return int(dades(uid).get("xp", 0))

## Multiplicadors per nivell (vida, mal, velocitat d'atac, habilitat)
static func mult_vida(n: int) -> float:
	return 1.0 + 0.1 * (n - 1)

static func mult_dany(n: int) -> float:
	return 1.0 + 0.08 * (n - 1)

static func mult_recarrega(n: int) -> float:
	return maxf(0.6, 1.0 - 0.02 * (n - 1))

static func mult_habilitat(n: int) -> float:
	return 1.0 + 0.05 * (n - 1)

## Guanya experiència (en combatre, regar, trobar coses, treballar al corral...)
func guanyar_xp(uid: String, quantitat: int):
	var d := dades(uid)
	if d.is_empty() or quantitat <= 0:
		return
	var n := int(d.get("nivell", 1))
	if n >= NIVELL_MAXIM:
		return
	var total := int(d.get("xp", 0)) + quantitat
	while n < NIVELL_MAXIM and total >= xp_per_nivell(n):
		total -= xp_per_nivell(n)
		n += 1
		nivell_pujat.emit(uid, n)
		EventBus.avis.emit("⭐ %s puja a nivell %d!" % [d.nom, n])
	d.nivell = n
	d.xp = total
	if uid == activa:
		Progressio._aplicar_efectes()
		if is_instance_valid(companya):
			companya.aplicar_nivell()
	_desar_aviat()

var _desat_pendent := false
func _desar_aviat():
	if not _desat_pendent:
		_desat_pendent = true
		call_deferred("_desar_ara")

func _desar_ara():
	_desat_pendent = false
	guardar()

func capturar(e: EspecieCriatura, nivell_inicial := 1) -> Dictionary:
	var d := {
		"uid": "%s_%d_%d" % [e.id, int(Time.get_unix_time_from_system()) % 100000000, randi() % 10000],
		"especie": e.id,
		"nom": e.nom if quantes(e.id) == 0 else "%s %d" % [e.nom, quantes(e.id) + 1],
		"dia": GestorTemps.dia_actual,
		"comportament": "neutral",
		"nivell": clampi(nivell_inicial, 1, NIVELL_MAXIM),
		"xp": 0,
	}
	col_leccio.append(d)
	veure(e.id)
	domesticades[e.id] = int(domesticades.get(e.id, 0)) + 1
	Progressio.guanyar_xp("domesticar", 1.0 + (e.forca - 1) * 0.5)
	criatura_capturada.emit(d)
	col_leccio_canviada.emit()
	if activa.is_empty():
		activar(d.uid)
	guardar()
	return d

func activar(uid: String):
	if uid == activa:
		return
	activa = uid
	_treure_companya()
	_apareixer_companya()
	Progressio._aplicar_efectes()
	activa_canviada.emit()
	guardar()

## Com es comporta quan et segueix: "pacific" (no ataca mai), "neutral" (defensa: ataca
## els enemics que se t'acosten) o "agressiu" (ataca tots els enemics del voltant)
const COMPORTAMENTS := {"pacific": "🕊️ Pacífic", "neutral": "🛡️ Neutral", "agressiu": "⚔️ Agressiu"}

func comportament(uid: String) -> String:
	return str(dades(uid).get("comportament", "neutral"))

func canviar_comportament(uid: String, valor: String):
	var d := dades(uid)
	if d.is_empty() or not COMPORTAMENTS.has(valor):
		return
	d.comportament = valor
	col_leccio_canviada.emit()
	guardar()

func reanomenar(uid: String, nom: String):
	var d := dades(uid)
	if d.is_empty() or nom.strip_edges().is_empty():
		return
	d.nom = nom.strip_edges().left(18)
	if is_instance_valid(companya) and companya.uid == uid:
		companya.actualitzar_nom()
	col_leccio_canviada.emit()
	guardar()

## Deixar-la anar: torna a la natura (desapareix de la col·lecció)
func alliberar(uid: String):
	col_leccio = col_leccio.filter(func(d): return d.uid != uid)
	if activa == uid:
		activar("")
	col_leccio_canviada.emit()
	guardar()

func bonus(clau: String) -> float:
	var e := especie_activa()
	if e == null:
		return 0.0
	match clau:
		"velocitat":
			return e.valor_habilitat * mult_habilitat(nivell(activa)) if e.habilitat == EspecieCriatura.Ajuda.VELOCITAT else 0.0
		"defensa":
			return minf(0.5, e.valor_habilitat * mult_habilitat(nivell(activa))) if e.habilitat == EspecieCriatura.Ajuda.DEFENSA else 0.0
	return 0.0

# ─────────────── Bestiari

func vista(especie_id: String) -> bool:
	return vistes.has(especie_id)

func domesticada(especie_id: String) -> bool:
	return int(domesticades.get(especie_id, 0)) > 0

func veure(especie_id: String):
	if vistes.has(especie_id) or not especies.has(especie_id):
		return
	vistes[especie_id] = GestorTemps.dia_actual
	especie_vista.emit(especies[especie_id])
	EventBus.avis.emit("📖 Nova criatura al bestiari: %s" % especies[especie_id].nom)
	guardar()

# ─────────────── La companya al món

## Quan es carrega el món (o canvia d'escena) torna a aparèixer al teu costat
var _temps_produccio := 0.0

func _process(delta):
	_temps_produccio += delta
	if _temps_produccio > 1.0:
		_temps_produccio = 0.0
		_produir()
	var escena := get_tree().current_scene
	if escena == _escena_actual:
		return
	_escena_actual = escena
	companya = null
	_apareixer_companya()

func _apareixer_companya():
	if activa.is_empty() or dades(activa).is_empty():
		return
	var mon := get_tree().current_scene
	if mon == null or mon.get_node_or_null("GridMap") == null:
		return   # a dins de casa no hi entra
	var d := dades(activa)
	var e := especie(d.especie)
	if e == null:
		return
	var c: Criatura = Criatura.crear(e)
	c.domesticada = true
	c.uid = d.uid
	c.nivell = nivell(d.uid)
	mon.add_child(c)
	companya = c
	c.apareixer_al_costat_del_jugador()

func _treure_companya():
	if is_instance_valid(companya):
		companya.queue_free()
	companya = null

# ─────────────── Desat

func guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"col_leccio": col_leccio, "activa": activa, "vistes": vistes, "domesticades": domesticades,
			"magatzem": magatzem, "ultim_minut": ultim_minut, "capacitat_corrals": capacitat_corrals}))

func carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		col_leccio = (d.get("col_leccio", []) as Array).filter(func(x): return x is Dictionary and especies.has(x.get("especie", "")))
		activa = str(d.get("activa", ""))
		vistes = d.get("vistes", {})
		magatzem = d.get("magatzem", {})
		ultim_minut = float(d.get("ultim_minut", -1.0))
		capacitat_corrals = int(d.get("capacitat_corrals", 0))
		domesticades = d.get("domesticades", {})
		# Partides d'abans del bestiari: el que ja tens compta com a vist i domesticat
		for c in col_leccio:
			vistes[c.especie] = vistes.get(c.especie, c.get("dia", 1))
			if not domesticades.has(c.especie):
				domesticades[c.especie] = col_leccio.filter(func(x): return x.especie == c.especie).size()
		if dades(activa).is_empty():
			activa = ""
