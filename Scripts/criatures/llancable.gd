extends Node3D
class_name Llancable
## Un objecte llançat (olives marinades o vermut hipnòtic) que fa un arc fins al punt
## d'impacte. En caure:
##   - olives: deixa un esquer que atrau les herbívores del voltant
##   - vermut: l'ampolla es trenca i hipnotitza les criatures d'un radi petit

const DURADA_VOL := 0.65
const ALCADA_ARC := 2.2
const RADI_HIPNOSI := 2.3
const RADI_HIPNOSI_FORT := 3.2

static func radi(tipus_objecte: String) -> float:
	match tipus_objecte:
		"vermut_hipnotic":
			return RADI_HIPNOSI
		"vermut_hipnotic_fort":
			return RADI_HIPNOSI_FORT
	return 0.6

var tipus := "olives_marinades"
var origen := Vector3.ZERO
var desti := Vector3.ZERO
var t := 0.0
var model: Node3D

static func llancar(pare: Node, p_tipus: String, des_de: Vector3, fins_a: Vector3) -> Llancable:
	var l := Llancable.new()
	l.tipus = p_tipus
	l.origen = des_de
	l.desti = fins_a
	pare.add_child(l)
	l.global_position = des_de
	return l

func _ready():
	model = _model_olives() if tipus == "olives_marinades" else _model_ampolla()
	add_child(model)

func _physics_process(delta):
	t += delta / DURADA_VOL
	var f := minf(t, 1.0)
	global_position = origen.lerp(desti, f) + Vector3.UP * ALCADA_ARC * 4.0 * f * (1.0 - f)
	model.rotation.z -= delta * 14.0
	model.rotation.x += delta * 5.0
	if t >= 1.0:
		_impacte()

func _impacte():
	set_physics_process(false)
	var mon := get_parent()
	if tipus == "olives_marinades":
		var e := Esquer.new()
		mon.add_child(e)
		e.global_position = desti
		_esquitx(Color(0.45, 0.55, 0.2), 10)
	else:
		_esquitx(Color(0.75, 0.35, 0.95), 26)
		_ona(Color(0.8, 0.45, 1.0))
		var cap := 0
		for c in get_tree().get_nodes_in_group("criatures_salvatges"):
			if Criatura._pla(c.global_position - desti).length() <= radi(tipus) and c.hipnotitzar(tipus == "vermut_hipnotic_fort"):
				cap += 1
		if cap == 0:
			TextFlotant.mostrar(mon, desti + Vector3.UP * 0.8, "💫", Color(0.85, 0.6, 1.0))
	queue_free()

# ─────────────── Efectes

func _esquitx(color: Color, quantes: int):
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = quantes
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	quad.material = mat
	p.mesh = quad
	get_parent().add_child(p)
	p.global_position = desti + Vector3.UP * 0.1
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

## Una onada lila que s'expandeix a terra (mostra l'abast de l'hipnosi)
func _ona(color: Color):
	var anell := AnellAbast.new()
	get_parent().add_child(anell)
	anell.configurar(radi(tipus), color)
	anell.global_position = desti + Vector3.UP * 0.05
	anell.scale = Vector3.ONE * 0.2
	var tw := anell.create_tween()
	tw.tween_property(anell, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.4)
	tw.tween_property(anell, "scale", Vector3.ONE * 1.15, 0.3)
	tw.parallel().tween_callback(func(): anell.visible = false).set_delay(0.3)
	tw.tween_callback(anell.queue_free)

# ─────────────── Models provisionals

static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.6
	return m

static func _model_olives() -> Node3D:
	var n := Node3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.07
	esfera.height = 0.11
	for i in 3:
		var m := MeshInstance3D.new()
		m.mesh = esfera
		m.material_override = _material(Color(0.42, 0.52, 0.18).darkened(i * 0.12))
		m.position = Vector3(cos(i * TAU / 3.0), 0, sin(i * TAU / 3.0)) * 0.06
		n.add_child(m)
	return n

static func _model_ampolla() -> Node3D:
	var n := Node3D.new()
	var cos := MeshInstance3D.new()
	var cilindre := CylinderMesh.new()
	cilindre.top_radius = 0.07
	cilindre.bottom_radius = 0.08
	cilindre.height = 0.22
	cos.mesh = cilindre
	var vidre := _material(Color(0.6, 0.25, 0.75))
	vidre.emission_enabled = true
	vidre.emission = Color(0.5, 0.2, 0.7)
	vidre.emission_energy_multiplier = 0.6
	cos.material_override = vidre
	n.add_child(cos)
	var coll := MeshInstance3D.new()
	var c2 := CylinderMesh.new()
	c2.top_radius = 0.025
	c2.bottom_radius = 0.035
	c2.height = 0.1
	coll.mesh = c2
	coll.material_override = vidre
	coll.position.y = 0.16
	n.add_child(coll)
	var tap := MeshInstance3D.new()
	var c3 := CylinderMesh.new()
	c3.top_radius = 0.03
	c3.bottom_radius = 0.03
	c3.height = 0.04
	tap.mesh = c3
	tap.material_override = _material(Color(0.55, 0.38, 0.22))
	tap.position.y = 0.22
	n.add_child(tap)
	return n
