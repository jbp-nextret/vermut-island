extends Node3D
class_name Tanques
## Tanques de fusta que el jugador construeix (mode construir tanques, des de la barra
## ràpida amb l'objecte "tanca_fusta" o "porta_tanca"):
##   - Clic: posa una tanca a la casella (arrossegant, en posa en línia)
##   - Clic dret: treu la tanca de sota el ratolí (te la torna)
##   - Esc: sortir del mode
## Les tanques s'enganxen soles amb les veïnes. Quan una zona queda tancada del tot
## (les portes també tanquen), es detecta com a corral i hi apareix un Corral.
## Es desa a user://tanques.save.

signal mode_canviat(actiu: bool)
signal avis(text: String)

const FITXER := "user://tanques.save"
const ABAST := 8.0
const ALCADA := 0.9
const MAX_CORRAL := 160        # cel·les; més gran ja no compta com a tancat
const VEINS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## Objecte de la motxilla <-> tipus de tanca
const TIPUS := {"tanca_fusta": "tanca", "porta_tanca": "porta", "tanca_pedra": "pedra"}

static func objecte_de(tipus: String) -> String:
	for o in TIPUS:
		if TIPUS[o] == tipus:
			return o
	return "tanca_fusta"

var mon: Node3D
var gridmap: GridMap
var plantador: Plantador
var jugador: Node3D

## Vector2i(x, z) -> {tipus: "tanca"/"porta", y: int (la cel·la de terra), node: Node3D}
var tanques := {}
var corrals: Array[Corral] = []

var actiu := false
var objecte := "tanca_fusta"
var arrossegant := false
var cella_cursor = null        # Vector2i o null
var superficie_cursor := Vector3.ZERO
var y_cursor := 0
var fantasma: Node3D

func configurar(p_mon: Node3D, p_gridmap: GridMap, p_plantador: Plantador, p_jugador: Node3D):
	mon = p_mon
	gridmap = p_gridmap
	plantador = p_plantador
	jugador = p_jugador

func _ready():
	fantasma = Node3D.new()
	fantasma.top_level = true
	fantasma.visible = false
	add_child(fantasma)
	_carregar()
	Criatures.assignacions_canviades.connect(func(): Criatures.repartir_corrals(corrals))
	await get_tree().physics_frame
	await get_tree().physics_frame
	_detectar_corrals()

# ─────────────── Mode construir

func entrar_amb(id: String):
	objecte = id
	actiu = true
	mode_canviat.emit(true)
	_refer_fantasma()

func sortir():
	actiu = false
	arrossegant = false
	fantasma.visible = false
	mode_canviat.emit(false)

func sortir_si_actiu():
	if actiu:
		sortir()

func _unhandled_input(event: InputEvent):
	if not actiu:
		return
	if event.is_action_pressed("ui_cancel"):
		sortir()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accio_primaria"):
		arrossegant = true
		_posar_aqui()
		get_viewport().set_input_as_handled()
	elif event.is_action_released("accio_primaria"):
		arrossegant = false
	elif event.is_action_pressed("accio_secundaria"):
		_treure_aqui()
		get_viewport().set_input_as_handled()

func _process(_delta):
	if not actiu:
		return
	if not GameState.pot_atacar():
		sortir()
		return
	var info := plantador._cella_sota_ratoli()
	if info.is_empty():
		cella_cursor = null
		fantasma.visible = false
		return
	var c: Vector3i = info.cella
	cella_cursor = Vector2i(c.x, c.z)
	y_cursor = c.y
	superficie_cursor = info.superficie
	fantasma.visible = true
	fantasma.global_position = superficie_cursor
	var motiu := _motiu_no(cella_cursor)
	for m in fantasma.get_children():
		if m is MeshInstance3D:
			(m.material_override as StandardMaterial3D).albedo_color = Color(0.6, 1.0, 0.6, 0.45) if motiu.is_empty() else Color(1.0, 0.35, 0.3, 0.45)
	if arrossegant:
		_posar_aqui(false)

## Per què no s'hi pot posar una tanca ("" si sí)
func _motiu_no(c: Vector2i) -> String:
	if tanques.has(c):
		return "Ja hi ha una tanca"
	if Vector2(superficie_cursor.x - jugador.global_position.x, superficie_cursor.z - jugador.global_position.z).length() > ABAST:
		return "Massa lluny"
	if superficie_cursor.y < (mon.nivell_aigua() if mon.has_method("nivell_aigua") else -INF):
		return "No es pot posar a l'aigua"
	var pos := superficie_cursor + Vector3.UP * 0.4
	if mon.has_method("recurs_a") and mon.recurs_a(pos):
		return "Hi ha alguna cosa"
	if mon.cultiu_a_prop(pos) or mon.llaurades.has(Vector3i(c.x, y_cursor, c.y)):
		return "No es pot posar sobre l'hort"
	var casa := mon.get_node_or_null("Casa") as Node3D
	if casa and Vector2(casa.global_position.x - pos.x, casa.global_position.z - pos.z).length() < 3.5:
		return "Massa a prop de casa"
	for taula in get_tree().get_nodes_in_group("taula_fabricacio"):
		if taula.ocupa(pos, -0.5):
			return "Hi ha la taula de fabricació"
	if Vector2(jugador.global_position.x - pos.x, jugador.global_position.z - pos.z).length() < 0.6:
		return "Hi ets a sobre"
	return ""

func _posar_aqui(avisar := true):
	if cella_cursor == null:
		return
	var motiu := _motiu_no(cella_cursor)
	if not motiu.is_empty():
		if avisar:
			avis.emit(motiu)
		return
	if not Inventari.treure(objecte):
		if avisar:
			avis.emit("No et queden %s" % CatalegObjectes.info(objecte).nom.to_lower())
		return
	posar(cella_cursor, y_cursor, TIPUS.get(objecte, "tanca"))
	if jugador.has_method("encarar"):
		jugador.encarar(superficie_cursor, true, 0.6)

func _treure_aqui():
	if cella_cursor == null or not tanques.has(cella_cursor):
		return
	var t: Dictionary = tanques[cella_cursor]
	treure(cella_cursor)
	Inventari.afegir(objecte_de(t.tipus), 1, true)

# ─────────────── Posar i treure

func posar(c: Vector2i, y: int, tipus: String, desar := true):
	tanques[c] = {"tipus": tipus, "y": y, "node": null}
	_refer(c)
	for v in VEINS:
		if tanques.has(c + v):
			_refer(c + v)
	if desar:
		_detectar_corrals()
		_guardar()

func treure(c: Vector2i):
	var t: Dictionary = tanques[c]
	if is_instance_valid(t.node):
		t.node.queue_free()
	tanques.erase(c)
	for v in VEINS:
		if tanques.has(c + v):
			_refer(c + v)
	_detectar_corrals()
	_guardar()

func es_tanca(posicio: Vector3) -> bool:
	return tanques.has(Vector2i(floori(posicio.x), floori(posicio.z)))

func _superficie(c: Vector2i, y: int) -> Vector3:
	var local := gridmap.map_to_local(Vector3i(c.x, y, c.y))
	local.y = y + 1.0
	return gridmap.to_global(local)

# ─────────────── Aspecte (provisional: pal i travessers cap a les veïnes)

func _refer(c: Vector2i):
	var t: Dictionary = tanques[c]
	if is_instance_valid(t.node):
		t.node.queue_free()
	var n := _model(t.tipus, _connexions(c), false)
	add_child(n)
	n.global_position = _superficie(c, t.y)
	t.node = n

func _connexions(c: Vector2i) -> Array:
	return VEINS.filter(func(v): return tanques.has(c + v))

func _refer_fantasma():
	for f in fantasma.get_children():
		f.queue_free()
	var model := _model(TIPUS.get(objecte, "tanca"), [Vector2i(1, 0), Vector2i(-1, 0)], true)
	for f in model.get_children():
		model.remove_child(f)
		fantasma.add_child(f)
	model.free()

static var _mat_fusta: StandardMaterial3D
static var _mat_fosca: StandardMaterial3D
static var _mat_pedra: StandardMaterial3D
static var _mat_pedra_fosca: StandardMaterial3D

func _model(tipus: String, connexions: Array, transparent: bool) -> Node3D:
	if _mat_fusta == null:
		_mat_fusta = StandardMaterial3D.new()
		_mat_fusta.albedo_color = Color(0.58, 0.4, 0.24)
		_mat_fusta.roughness = 1.0
		_mat_fosca = StandardMaterial3D.new()
		_mat_fosca.albedo_color = Color(0.42, 0.28, 0.16)
		_mat_fosca.roughness = 1.0
	if _mat_pedra == null:
		_mat_pedra = StandardMaterial3D.new()
		_mat_pedra.albedo_color = Color(0.62, 0.62, 0.6)
		_mat_pedra.roughness = 1.0
		_mat_pedra_fosca = StandardMaterial3D.new()
		_mat_pedra_fosca.albedo_color = Color(0.48, 0.48, 0.47)
		_mat_pedra_fosca.roughness = 1.0
	var arrel: Node3D = StaticBody3D.new() if not transparent else Node3D.new()
	var mat_pal: Material = _mat_pedra_fosca if tipus == "pedra" else _mat_fosca
	var mat_trav: Material = _mat_pedra if tipus == "pedra" else _mat_fusta
	if transparent:
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat_pal = m
		mat_trav = m
	var gruix := 0.26 if tipus == "pedra" else 0.16
	_caixa(arrel, Vector3(gruix, ALCADA + 0.1, gruix), Vector3(0, (ALCADA + 0.1) / 2.0, 0), mat_pal, not transparent and tipus != "porta")
	for v in connexions:
		var dir := Vector3(v.x, 0, v.y)
		var mida := Vector3(0.5, 0.08, 0.06) if v.x != 0 else Vector3(0.06, 0.08, 0.5)
		if tipus == "porta":
			# La porta: un marc més clar i una creu (no té col·lisió: s'hi pot passar)
			_caixa(arrel, mida, dir * 0.25 + Vector3.UP * 0.25, mat_trav, false)
			_caixa(arrel, mida, dir * 0.25 + Vector3.UP * 0.7, mat_trav, false)
			_caixa(arrel, Vector3(0.05, 0.5, 0.05) if v.x != 0 else Vector3(0.05, 0.5, 0.05), dir * 0.25 + Vector3.UP * 0.47, mat_trav, false)
		elif tipus == "pedra":
			# Un mur baix de pedra
			var mur := Vector3(0.5, 0.7, 0.2) if v.x != 0 else Vector3(0.2, 0.7, 0.5)
			_caixa(arrel, mur, dir * 0.25 + Vector3.UP * 0.35, mat_trav, not transparent)
		else:
			_caixa(arrel, mida, dir * 0.25 + Vector3.UP * 0.35, mat_trav, not transparent)
			_caixa(arrel, mida, dir * 0.25 + Vector3.UP * 0.75, mat_trav, not transparent)
	if tipus == "porta" and connexions.is_empty():
		_caixa(arrel, Vector3(0.5, 0.08, 0.06), Vector3.UP * 0.5, mat_trav, false)
	return arrel

func _caixa(pare: Node3D, mida: Vector3, pos: Vector3, mat: Material, col: bool):
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = mida
	m.mesh = b
	m.material_override = mat
	m.position = pos
	pare.add_child(m)
	if col and pare is StaticBody3D:
		var forma := CollisionShape3D.new()
		var caixa := BoxShape3D.new()
		caixa.size = mida + Vector3(0.04, 0.0, 0.04)
		forma.shape = caixa
		forma.position = pos
		pare.add_child(forma)

# ─────────────── Detectar corrals (zones tancades)

## Cerca les zones de terra envoltades del tot per tanques (o portes)
func _detectar_corrals():
	var zones := []
	if not tanques.is_empty():
		var mn := Vector2i(1 << 20, 1 << 20)
		var mx := -mn
		for c in tanques:
			mn = Vector2i(mini(mn.x, c.x), mini(mn.y, c.y))
			mx = Vector2i(maxi(mx.x, c.x), maxi(mx.y, c.y))
		var vist := {}
		for x in range(mn.x, mx.x + 1):
			for z in range(mn.y, mx.y + 1):
				var inici := Vector2i(x, z)
				if tanques.has(inici) or vist.has(inici):
					continue
				# Omple la zona; si toca la vora de la caixa, no està tancada
				var zona := []
				var tancada := true
				var pila := [inici]
				vist[inici] = true
				while not pila.is_empty():
					var c: Vector2i = pila.pop_back()
					zona.append(c)
					if c.x <= mn.x or c.x >= mx.x or c.y <= mn.y or c.y >= mx.y:
						tancada = false
					for v in VEINS:
						var n: Vector2i = c + v
						if n.x < mn.x or n.x > mx.x or n.y < mn.y or n.y > mx.y:
							continue
						if not tanques.has(n) and not vist.has(n):
							vist[n] = true
							pila.append(n)
				if tancada and zona.size() >= 2 and zona.size() <= MAX_CORRAL:
					zones.append(zona)
	# Refà els nodes Corral (es conserven els que no han canviat)
	var nous: Array[Corral] = []
	for zona in zones:
		var clau := _clau(zona)
		var existent: Corral = null
		for c in corrals:
			if is_instance_valid(c) and c.clau == clau:
				existent = c
		if existent == null:
			existent = Corral.new()
			existent.clau = clau
			existent.tanques = self
			existent.celles = zona
			existent.y = _alcada_zona(zona)
			mon.add_child(existent)
			if not corrals.any(func(x): return is_instance_valid(x)) and actiu:
				avis.emit("🏡 Corral construït! (%d caselles, hi caben %d criatures)" % [zona.size(), existent.capacitat()])
		nous.append(existent)
	for c in corrals:
		if is_instance_valid(c) and not c in nous:
			c.desmuntar()
	corrals = nous
	Criatures.capacitat_corrals = 0
	for c in corrals:
		Criatures.capacitat_corrals += c.capacitat()
	Criatures.repartir_corrals(corrals)

func _clau(zona: Array) -> String:
	var copia := zona.duplicate()
	copia.sort()
	return str(copia.size()) + ":" + str(copia[0]) + str(copia[-1])

func _alcada_zona(zona: Array) -> int:
	# L'alçada de terra més habitual de les tanques del voltant
	for c in zona:
		for v in VEINS:
			if tanques.has(c + v):
				return tanques[c + v].y
	return 0

# ─────────────── Desat

func _guardar():
	var llista := []
	for c in tanques:
		llista.append([c.x, c.y, tanques[c].y, tanques[c].tipus])
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"tanques": llista}))

func _carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for t in d.get("tanques", []):
			tanques[Vector2i(int(t[0]), int(t[1]))] = {"tipus": str(t[3]), "y": int(t[2]), "node": null}
		for c in tanques:
			_refer(c)
