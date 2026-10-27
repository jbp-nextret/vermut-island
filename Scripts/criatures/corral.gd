@tool
extends Node3D
class_name Corral
## El corral de les criatures, a prop de casa (provisional: tanca de fusta feta amb codi,
## es pot substituir per un model propi).
##   - Hi viuen les criatures assignades "al corral" i hi produeixen coses (olives, raïm...)
##   - Les que tenen tasques (talar, picar, tallar herba) treballen pels voltants
##   - Tot el que produeixen va a la cistella: F a la porta per gestionar-ho i recollir-ho

@export var mida := Vector2(6.0, 5.0):
	set(v): mida = v; _construir()
@export var color_fusta := Color(0.55, 0.37, 0.22):
	set(v): color_fusta = v; _construir()

const ALCADA_TANCA := 0.9
const AMPLADA_PORTA := 1.6

var cistella: Label3D
var criatures := {}   # uid -> Criatura

func _ready():
	_construir()
	if Engine.is_editor_hint():
		return
	add_to_group("corral")
	add_to_group("interactuables")
	Criatures.assignacions_canviades.connect(_actualitzar_criatures)
	Criatures.produccio.connect(_on_produccio)
	# Espera que el terreny tingui col·lisions abans de posar-hi les criatures
	await get_tree().physics_frame
	await get_tree().physics_frame
	_actualitzar_criatures()

# ─────────────── Interacció (F a la porta)

func pot_interactuar(_jugador: Node) -> bool:
	return true

func text_interaccio(_jugador: Node) -> String:
	var n := Criatures.objectes_magatzem()
	return "Corral" + (" (🧺 %d)" % n if n > 0 else "")

func punt_interaccio() -> Vector3:
	return global_position + Vector3(0, 0.3, mida.y / 2.0 + 0.3)

func interactuar(_interaccio: Node) -> void:
	MenuCorral.obrir(self)

# ─────────────── Criatures

func punt_a_dins() -> Vector3:
	return global_position + Vector3(randf_range(-mida.x / 2.0 + 0.7, mida.x / 2.0 - 0.7), 0.3, randf_range(-mida.y / 2.0 + 0.7, mida.y / 2.0 - 0.7))

## Ocupa aquest punt (perquè no hi surtin arbres, roques ni marques d'excavació)?
func ocupa(posicio: Vector3, marge := 0.0) -> bool:
	var local := posicio - global_position
	return absf(local.x) < mida.x / 2.0 + marge and absf(local.z) < mida.y / 2.0 + marge + 1.0

## L'arbre, la roca o l'herba més propers per a una tasca
func lloc_per_tasca(tasca: String, des_de: Vector3) -> Node3D:
	var tipus: int = {"talar": RecursNatural.Tipus.ARBRE, "picar": RecursNatural.Tipus.ROCA, "herba": RecursNatural.Tipus.HERBA}.get(tasca, -1)
	var millor: Node3D = null
	var millor_d := 30.0
	for r in get_tree().get_nodes_in_group("recursos"):
		if r is RecursNatural and r.tipus == tipus and r.disponible():
			var d: float = r.global_position.distance_to(global_position) + r.global_position.distance_to(des_de) * 0.3
			if d < millor_d:
				millor = r
				millor_d = d
	return millor

func _actualitzar_criatures():
	var volem := {}
	for a in ["corral", "talar", "picar", "herba"]:
		for uid in Criatures.amb_assignacio(a):
			volem[uid] = a
	# Treu les que ja no hi han de ser (o que han canviat de feina)
	for uid in criatures.keys():
		var c: Criatura = criatures[uid]
		if not volem.has(uid) or not is_instance_valid(c) or c.mode_corral != volem[uid]:
			if is_instance_valid(c):
				c.queue_free()
			criatures.erase(uid)
	# Posa les que falten
	for uid in volem:
		if criatures.has(uid):
			continue
		var d := Criatures.dades(uid)
		var e := Criatures.especie(d.especie)
		if e == null:
			continue
		var c := Criatura.crear(e)
		c.domesticada = true
		c.uid = uid
		c.nivell = Criatures.nivell(uid)
		c.mode_corral = volem[uid]
		c.corral = self
		get_parent().add_child(c)
		c.global_position = punt_a_dins() if volem[uid] == "corral" else global_position + Vector3(0, 0.3, mida.y / 2.0 + 1.0)
		c.pos_anterior = c.global_position
		criatures[uid] = c

func _on_produccio(uid: String, objecte: String):
	if criatures.has(uid) and is_instance_valid(criatures[uid]):
		criatures[uid].mostrar_produccio(objecte)

func _process(_delta):
	if Engine.is_editor_hint() or cistella == null:
		return
	var n := Criatures.objectes_magatzem()
	cistella.text = "🧺 %d" % n if n > 0 else ""

# ─────────────── Tanca (provisional)

func _construir():
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("generat"):
			remove_child(c)
			c.queue_free()
	var fusta := StandardMaterial3D.new()
	fusta.albedo_color = color_fusta
	fusta.roughness = 1.0
	var fosca := StandardMaterial3D.new()
	fosca.albedo_color = color_fusta.darkened(0.3)
	fosca.roughness = 1.0
	var mx := mida.x / 2.0
	var mz := mida.y / 2.0
	# Els quatre costats; al de davant (+Z) hi ha la porta, al mig
	var costats := [
		[Vector3(-mx, 0, -mz), Vector3(mx, 0, -mz)],
		[Vector3(-mx, 0, -mz), Vector3(-mx, 0, mz)],
		[Vector3(mx, 0, -mz), Vector3(mx, 0, mz)],
		[Vector3(-mx, 0, mz), Vector3(-AMPLADA_PORTA / 2.0, 0, mz)],
		[Vector3(AMPLADA_PORTA / 2.0, 0, mz), Vector3(mx, 0, mz)],
	]
	for c in costats:
		_tram(c[0], c[1], fusta, fosca)
	# Abeurador i cistella
	var abeurador := _caixa(Vector3(1.2, 0.35, 0.45), Vector3(-mx + 1.0, 0.17, -mz + 0.6), fosca)
	var mat_aigua := StandardMaterial3D.new()
	mat_aigua.albedo_color = Color(0.35, 0.6, 0.85)
	_caixa(Vector3(1.05, 0.04, 0.32), Vector3(0, 0.16, 0), mat_aigua, abeurador)
	var cist := _caixa(Vector3(0.5, 0.35, 0.5), Vector3(AMPLADA_PORTA / 2.0 + 0.6, 0.17, mz + 0.5), fusta)
	cistella = Label3D.new()
	cistella.set_meta("generat", true)
	cistella.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cistella.font_size = 48
	cistella.outline_size = 12
	cistella.pixel_size = 0.006
	cistella.position = cist.position + Vector3.UP * 0.6
	add_child(cistella)
	# Rètol
	var retol := Label3D.new()
	retol.set_meta("generat", true)
	retol.text = "Corral"
	retol.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	retol.font_size = 40
	retol.outline_size = 10
	retol.pixel_size = 0.006
	retol.position = Vector3(0, ALCADA_TANCA + 0.5, mz)
	add_child(retol)

func _tram(a: Vector3, b: Vector3, fusta: Material, fosca: Material):
	var llarg := a.distance_to(b)
	var dir := (b - a).normalized()
	var n := maxi(1, ceili(llarg / 1.5))
	for i in n + 1:
		var p := a + dir * llarg * i / n
		_caixa(Vector3(0.14, ALCADA_TANCA + 0.1, 0.14), p + Vector3.UP * (ALCADA_TANCA + 0.1) / 2.0, fosca)
	for alcada in [0.35, 0.75]:
		var travesser := _caixa(Vector3(llarg, 0.08, 0.06), (a + b) / 2.0 + Vector3.UP * alcada, fusta)
		travesser.rotation.y = -atan2(dir.z, dir.x)

func _caixa(mida_caixa: Vector3, pos: Vector3, material: Material, pare: Node = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.set_meta("generat", true)
	var caixa := BoxMesh.new()
	caixa.size = mida_caixa
	m.mesh = caixa
	m.material_override = material
	m.position = pos
	(pare if pare else self).add_child(m)
	return m
