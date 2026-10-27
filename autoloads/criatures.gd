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

const FITXER := "user://criatures.save"
const CARPETA := "res://Resources/criatures/"

var especies := {}       # id -> EspecieCriatura
## [{uid, especie, nom, dia}]
var col_leccio: Array = []
var activa := ""         # uid de la que et segueix
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

func capturar(e: EspecieCriatura) -> Dictionary:
	var d := {
		"uid": "%s_%d_%d" % [e.id, int(Time.get_unix_time_from_system()) % 100000000, randi() % 10000],
		"especie": e.id,
		"nom": e.nom if quantes(e.id) == 0 else "%s %d" % [e.nom, quantes(e.id) + 1],
		"dia": GestorTemps.dia_actual,
	}
	col_leccio.append(d)
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
			return e.valor_habilitat if e.habilitat == EspecieCriatura.Ajuda.VELOCITAT else 0.0
		"defensa":
			return e.valor_habilitat if e.habilitat == EspecieCriatura.Ajuda.DEFENSA else 0.0
	return 0.0

# ─────────────── La companya al món

## Quan es carrega el món (o canvia d'escena) torna a aparèixer al teu costat
func _process(_delta):
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
		f.store_string(JSON.stringify({"col_leccio": col_leccio, "activa": activa}))

func carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		col_leccio = (d.get("col_leccio", []) as Array).filter(func(x): return x is Dictionary and especies.has(x.get("especie", "")))
		activa = str(d.get("activa", ""))
		if dades(activa).is_empty():
			activa = ""
