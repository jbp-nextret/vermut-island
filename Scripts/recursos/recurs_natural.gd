extends Node3D
class_name RecursNatural
## Una cosa que es pot recol·lectar: un arbre (destral), una roca (pic) o herba (espasa).
## Va com a fill del node que es veu (el sprite de l'arbre, la roca...). Quan s'esgota,
## aquest node s'amaga i torna a sortir al cap d'uns dies. L'estat es desa amb el món.

signal esgotat(recurs: RecursNatural)

enum Tipus { ARBRE, ROCA, HERBA }

@export var tipus: Tipus = Tipus.ARBRE
## Cops que cal donar-li
@export var cops := 3
## Què dona i quant
@export var objecte := "fusta"
@export var quantitat_min := 2
@export var quantitat_max := 4
## Dies que triga a tornar a sortir
@export var dies_per_tornar := 3
## Experiència en esgotar-lo (clau de Progressio.XP)
@export var motiu_xp := "talar"
## No torna a sortir si a aquesta distància hi ha cultius, terra llaurada o l'hort
@export var marge_conreu := 1.5
## Distància a què ocupa el terra: no s'hi pot plantar ni llaurar
@export var radi_ocupat := 0.8

const NOMS_ACCIO := {Tipus.ARBRE: "🪓 Talar", Tipus.ROCA: "⛏ Picar", Tipus.HERBA: "Tallar"}

var cops_rebuts := 0
var esgotat_dia := -1    # -1 = disponible
var escala_original := Vector3.ONE
var _dia_comprovat := -1

func _ready():
	add_to_group("recursos")
	if tipus == Tipus.HERBA:
		add_to_group("herba")
	escala_original = visual().scale

func visual() -> Node3D:
	return get_parent() as Node3D

func disponible() -> bool:
	return esgotat_dia < 0

func nom_accio() -> String:
	return NOMS_ACCIO[tipus]

## Es pot clicar (els arbres i les roques; l'herba es talla amb l'espasa)
func clicable() -> bool:
	return tipus != Tipus.HERBA and disponible()

## La caixa que ocupa al món (per saber si el ratolí hi és a sobre)
func caixa() -> AABB:
	var resultat := AABB()
	var primer := true
	var malles := visual().find_children("*", "VisualInstance3D", true, false)
	if visual() is VisualInstance3D:
		malles.append(visual())
	for m in malles:
		if m is VisualInstance3D:
			var c: AABB = m.global_transform * m.get_aabb()
			resultat = c if primer else resultat.merge(c)
			primer = false
	return resultat

func rebre_cop() -> void:
	if not disponible():
		return
	cops_rebuts += 1
	_sacsejar()
	_estelles()
	if cops_rebuts >= cops:
		_esgotar()

## L'espasa talla l'herba que queda dins de l'arc del tall
func rebre_tall(origen: Vector3, direccio: Vector3, abast: float, mig_angle: float) -> void:
	if tipus != Tipus.HERBA or not disponible():
		return
	var pla := global_position - origen
	pla.y = 0.0
	if pla.length() > abast:
		return
	if pla.length() > 0.4 and rad_to_deg(direccio.angle_to(pla.normalized())) > mig_angle:
		return
	rebre_cop()

func _esgotar():
	esgotat_dia = GestorTemps.dia_actual
	cops_rebuts = 0
	var quantitat := randi_range(quantitat_min, quantitat_max)
	var info := CatalegObjectes.info(objecte)
	if Inventari.afegir(objecte, quantitat):
		TextFlotant.mostrar(get_tree().current_scene, global_position + Vector3.UP * 1.2, "+%d %s" % [quantitat, info.icona], Color(1.0, 0.9, 0.6))
	Progressio.guanyar_xp(motiu_xp)
	esgotat.emit(self)
	# L'arbre cau, la roca s'esmicola, l'herba desapareix
	var v := visual()
	var t := v.create_tween()
	match tipus:
		Tipus.ARBRE:
			t.tween_property(v, "scale", Vector3(escala_original.x * 1.1, escala_original.y * 0.05, escala_original.z), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_:
			t.tween_property(v, "scale", escala_original * 0.05, 0.2)
	t.tween_callback(func(): _mostrar(false))
	GestorPartida.call_deferred("guardar_mundo")

func _process(_delta):
	var dia: int = GestorTemps.dia_actual
	if disponible() or dia < esgotat_dia + dies_per_tornar or dia == _dia_comprovat:
		return
	_dia_comprovat = dia
	# Si mentrestant hi han plantat o llaurat a prop, no torna (ho prova l'endemà)
	if conreu_a_prop():
		return
	reapareixer()

## Hi ha cultius, terra llaurada o l'hort massa a prop?
func conreu_a_prop() -> bool:
	var mon := get_tree().current_scene
	return mon != null and mon.has_method("zona_de_conreu_a_prop") and mon.zona_de_conreu_a_prop(global_position, marge_conreu)

## L'amaga sense donar res (quan és en un lloc on ara es conrea)
func retirar():
	esgotat_dia = GestorTemps.dia_actual
	cops_rebuts = 0
	_mostrar(false)

## Ocupa el terra en aquest punt? (per no plantar-hi ni llaurar-hi a sobre)
func ocupa(punt: Vector3) -> bool:
	return disponible() and Vector2(punt.x - global_position.x, punt.z - global_position.z).length() < radi_ocupat

func reapareixer():
	esgotat_dia = -1
	_mostrar(true)
	var v := visual()
	v.scale = escala_original * 0.2
	v.create_tween().tween_property(v, "scale", escala_original, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Amaga o mostra el recurs (i desactiva les col·lisions, si en té)
func _mostrar(visible_ara: bool):
	var v := visual()
	v.visible = visible_ara
	if visible_ara:
		v.scale = escala_original
	for forma in v.find_children("*", "CollisionShape3D", true, false):
		forma.set_deferred("disabled", not visible_ara)

func _sacsejar():
	var v := visual()
	var pos := v.position
	var t := v.create_tween()
	for x in [0.12, -0.1, 0.06, 0.0]:
		t.tween_property(v, "position:x", pos.x + x, 0.04)

func _estelles():
	var color: Color = {Tipus.ARBRE: Color(0.55, 0.38, 0.2), Tipus.ROCA: Color(0.6, 0.6, 0.62), Tipus.HERBA: Color(0.4, 0.8, 0.3)}[tipus]
	var p := GPUParticles3D.new()
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3.UP
	mat.spread = 70.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -10, 0)
	mat.color = color
	p.process_material = mat
	var q := QuadMesh.new()
	q.size = Vector2(0.08, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.local_coords = false
	get_tree().current_scene.add_child(p)
	p.global_position = global_position + Vector3.UP * (0.8 if tipus == Tipus.ARBRE else 0.3)
	p.emitting = true
	p.finished.connect(p.queue_free)

# ─────────────── Desar / carregar

## { camí del node respecte al món: dia en què es va esgotar }
static func estats(mon: Node) -> Dictionary:
	var d := {}
	for r in mon.get_tree().get_nodes_in_group("recursos"):
		if not r.disponible():
			d[str(mon.get_path_to(r))] = r.esgotat_dia
	return d

static func restaurar(mon: Node, d: Dictionary) -> void:
	for cami in d:
		var r := mon.get_node_or_null(NodePath(cami)) as RecursNatural
		if r:
			r.esgotat_dia = int(d[cami])
			r._mostrar(false)
