extends Node
class_name Llancador
## Mode llançar (L): apuntes amb el ratolí (es veu l'arc i on caurà), clic per llançar,
## Q/E per canviar entre olives marinades i vermut hipnòtic, clic dret o L per sortir.

signal mode_canviat(actiu: bool)
signal avis(text: String)

const ABAST := 9.0
const RECARREGA := 0.6
const OBJECTES := ["olives_marinades", "vermut_hipnotic"]
const COLORS := {"olives_marinades": Color(0.6, 0.8, 0.3), "vermut_hipnotic": Color(0.8, 0.45, 1.0)}
const PUNTS_ARC := 14

var jugador: Node3D
var actiu := false
var index := 0
var temps := 99.0
var punt := Vector3.ZERO
var punt_valid := false

var anell: AnellAbast
var punts_arc: Array[MeshInstance3D] = []

func configurar(p_jugador: Node3D):
	jugador = p_jugador

func _ready():
	anell = AnellAbast.new()
	anell.top_level = true
	anell.visible = false
	add_child(anell)
	var esfera := SphereMesh.new()
	esfera.radius = 0.045
	esfera.height = 0.09
	esfera.radial_segments = 8
	esfera.rings = 4
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.75)
	mat.no_depth_test = true
	esfera.material = mat
	for i in PUNTS_ARC:
		var m := MeshInstance3D.new()
		m.mesh = esfera
		m.top_level = true
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		punts_arc.append(m)
	_configurar_anell()

func objecte() -> String:
	return OBJECTES[index]

func quantitat() -> int:
	return Inventari.tenir(objecte())

func progres() -> float:
	return clampf(temps / RECARREGA, 0.0, 1.0)

# ─────────────── Entrada

func _unhandled_input(event: InputEvent) -> void:
	if not GameState.pot_atacar():
		return
	if event.is_action_pressed("llancar"):
		alternar()
		get_viewport().set_input_as_handled()
		return
	if not actiu:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("accio_secundaria"):
		sortir()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("accio_primaria"):
		llancar()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mode_combat") or event.is_action_pressed("atac_magia"):
		# Q / E: canviar d'objecte (en aquest mode no s'ataca)
		seleccionar(index + (-1 if event.is_action_pressed("mode_combat") else 1))
		get_viewport().set_input_as_handled()

func alternar():
	if actiu:
		sortir()
	else:
		entrar()

func entrar():
	if not GameState.pot_atacar():
		return
	actiu = true
	# Si no en tens de l'escollit però sí de l'altre, canvia sol
	if quantitat() == 0 and Inventari.tenir(OBJECTES[1 - index]) > 0:
		index = 1 - index
		_configurar_anell()
	mode_canviat.emit(true)

func sortir_si_actiu():
	if actiu:
		sortir()

func sortir():
	actiu = false
	anell.visible = false
	for m in punts_arc:
		m.visible = false
	mode_canviat.emit(false)

func seleccionar(nou: int):
	index = posmod(nou, OBJECTES.size())
	_configurar_anell()
	var info := CatalegObjectes.info(objecte())
	avis.emit("%s %s (%d)" % [info.icona, info.nom, quantitat()])

func _configurar_anell():
	var radi := Llancable.RADI_HIPNOSI if objecte() == "vermut_hipnotic" else 0.6
	anell.configurar(radi, COLORS[objecte()])

func llancar():
	if temps < RECARREGA or not punt_valid:
		return
	if quantitat() <= 0:
		var info := CatalegObjectes.info(objecte())
		avis.emit("No tens %s (es fan a la barrica)" % info.nom.to_lower())
		return
	Inventari.treure(objecte())
	temps = 0.0
	if jugador.has_method("encarar"):
		jugador.encarar(punt, true, 0.8)
	Llancable.llancar(get_tree().current_scene, objecte(), _origen(), punt)

func _origen() -> Vector3:
	return jugador.global_position + Vector3.UP * 1.1

# ─────────────── Cada frame

func _process(delta):
	temps += delta
	if not actiu:
		return
	if not GameState.pot_atacar():
		sortir()
		return
	punt_valid = _apuntar()
	anell.visible = punt_valid
	if punt_valid:
		anell.global_position = punt + Vector3.UP * 0.04
	# L'arc que farà (el mateix que Llancable)
	var o := _origen()
	for i in PUNTS_ARC:
		var f := float(i + 1) / float(PUNTS_ARC + 1)
		var m := punts_arc[i]
		m.visible = punt_valid
		m.global_position = o.lerp(punt, f) + Vector3.UP * Llancable.ALCADA_ARC * 4.0 * f * (1.0 - f)

## On cau: on apunta el ratolí (terra o aigua), limitat a l'abast
func _apuntar() -> bool:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return false
	var ratoli := get_viewport().get_mouse_position()
	var o := camera.project_ray_origin(ratoli)
	var d := camera.project_ray_normal(ratoli)
	var consulta := PhysicsRayQueryParameters3D.create(o, o + d * 200.0, 1)
	consulta.exclude = [jugador.get_rid()]
	var cop := jugador.get_world_3d().direct_space_state.intersect_ray(consulta)
	var mon := get_tree().current_scene
	var aigua: float = mon.nivell_aigua() if mon.has_method("nivell_aigua") else 0.0
	var objectiu: Vector3
	if not cop.is_empty():
		objectiu = cop.position
		if objectiu.y < aigua:
			objectiu.y = aigua
	elif absf(d.y) > 0.01:
		objectiu = o + d * ((aigua - o.y) / d.y)
	else:
		return false
	var cap := Criatura._pla(objectiu - jugador.global_position)
	if cap.length() > ABAST:
		objectiu = jugador.global_position + cap.normalized() * ABAST
		objectiu = CombatMagic.terra_sota(jugador, objectiu + Vector3.UP * 2.0)
		objectiu.y = maxf(objectiu.y, aigua)
	punt = objectiu
	return true
