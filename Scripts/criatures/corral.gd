extends Node3D
class_name Corral
## Un corral: una zona tancada del tot per tanques (la crea Tanques en detectar-la).
##   - Hi viuen les criatures assignades "al corral" i hi produeixen coses
##   - Les que tenen tasques (talar, picar, tallar herba) treballen pels voltants
##   - Tot el que produeixen va a la cistella: F a la porta (o a una tanca) per
##     gestionar-ho i recollir-ho
## Hi caben 1 criatura per cada 3 caselles de dins (com a molt 8).

var clau := ""
var tanques: Tanques
var celles: Array = []       # Vector2i de dins
var y := 0                   # la cel·la de terra
var criatures := {}          # uid -> Criatura
var cistella: Label3D
var retol: Label3D
var punt_entrada := Vector3.ZERO

func capacitat() -> int:
	return clampi(celles.size() / 3, 1, 8)

func _ready():
	add_to_group("corral")
	add_to_group("interactuables")
	Criatures.produccio.connect(_on_produccio)
	punt_entrada = _trobar_entrada()
	cistella = _label(48)
	add_child(cistella)
	cistella.global_position = punt_entrada + Vector3.UP * 1.5
	retol = _label(36)
	retol.text = "Corral"
	add_child(retol)
	retol.global_position = punt_entrada + Vector3.UP * 1.25
	# Una mica de "terra trepitjada" a dins perquè es vegi que és un corral
	for c in celles:
		var marca := MeshInstance3D.new()
		var pla := PlaneMesh.new()
		pla.size = Vector2(0.96, 0.96)
		marca.mesh = pla
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.42, 0.25, 0.35)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		marca.material_override = mat
		marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marca)
		marca.global_position = tanques._superficie(c, y) + Vector3.UP * 0.02

func _label(mida: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = mida
	l.outline_size = 12
	l.pixel_size = 0.006
	return l

## La porta, si n'hi ha; si no, la tanca de la vora més propera al centre
func _trobar_entrada() -> Vector3:
	var millor = null
	var centre := _centre()
	for c in celles:
		for v in Tanques.VEINS:
			var t: Vector2i = c + v
			if tanques.tanques.has(t):
				var es_porta: bool = tanques.tanques[t].tipus == "porta"
				var d := Vector2(t).distance_to(centre) - (100.0 if es_porta else 0.0)
				if millor == null or d < millor[0]:
					millor = [d, t]
	var t: Vector2i = millor[1] if millor else celles[0]
	return tanques._superficie(t, tanques.tanques[t].y if tanques.tanques.has(t) else y)

func _centre() -> Vector2:
	var s := Vector2.ZERO
	for c in celles:
		s += Vector2(c)
	return s / maxf(1.0, celles.size())

func desmuntar():
	for c in criatures.values():
		if is_instance_valid(c):
			c.queue_free()
	queue_free()

# ─────────────── Interacció

func pot_interactuar(_jugador: Node) -> bool:
	return true

func text_interaccio(_jugador: Node) -> String:
	var n := Criatures.objectes_magatzem()
	return "Corral" + (" (🧺 %d)" % n if n > 0 else "")

func punt_interaccio() -> Vector3:
	return punt_entrada

func interactuar(_interaccio: Node) -> void:
	MenuCorral.obrir(self)

# ─────────────── Criatures

func punt_a_dins() -> Vector3:
	var c: Vector2i = celles[randi() % celles.size()]
	return tanques._superficie(c, y) + Vector3(randf_range(-0.3, 0.3), 0.3, randf_range(-0.3, 0.3))

## Ocupa aquest punt (perquè no hi surtin arbres, roques ni marques d'excavació)?
func ocupa(posicio: Vector3, marge := 0.0) -> bool:
	var p := Vector2(posicio.x, posicio.z)
	for c in celles:
		if (Vector2(c) + Vector2(0.5, 0.5)).distance_to(p) <= marge + 0.8:
			return true
	return false

## L'arbre, la roca o l'herba més propers per a una tasca
func lloc_per_tasca(tasca: String, des_de: Vector3) -> Node3D:
	var tipus: int = {"talar": RecursNatural.Tipus.ARBRE, "picar": RecursNatural.Tipus.ROCA, "herba": RecursNatural.Tipus.HERBA}.get(tasca, -1)
	var millor: Node3D = null
	var millor_d := 30.0
	for r in get_tree().get_nodes_in_group("recursos"):
		if r is RecursNatural and r.tipus == tipus and r.disponible():
			var d: float = r.global_position.distance_to(punt_entrada) + r.global_position.distance_to(des_de) * 0.3
			if d < millor_d:
				millor = r
				millor_d = d
	return millor

## Posa (o treu) les criatures que li toquen: `volem` = {uid: "corral"/"talar"/...}
func posar_criatures(volem: Dictionary):
	for uid in criatures.keys():
		var c: Criatura = criatures[uid]
		if not volem.has(uid) or not is_instance_valid(c) or c.mode_corral != volem[uid]:
			if is_instance_valid(c):
				c.queue_free()
			criatures.erase(uid)
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
		c.global_position = punt_a_dins() if volem[uid] == "corral" else punt_entrada + Vector3(0, 0.3, 1.0)
		c.pos_anterior = c.global_position
		criatures[uid] = c

func _on_produccio(uid: String, objecte: String):
	if criatures.has(uid) and is_instance_valid(criatures[uid]):
		criatures[uid].mostrar_produccio(objecte)

func _process(_delta):
	var n := Criatures.objectes_magatzem()
	cistella.text = "🧺 %d" % n if n > 0 else ""
