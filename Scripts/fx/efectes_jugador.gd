extends Node
class_name EfectesJugador
## Els efectes que fan que moure's i fer coses es noti (fill del Personatge):
##   - Squash & stretch: s'estira en saltar, s'aixafa en aterrar, fa un petit batec en
##     atacar, fer màgia o fer servir una eina (`EfectesJugador.batec(...)`).
##   - Pols: en saltar, en aterrar (més com més alt cau), en fer el dash i, de tant en
##     tant, mentre corre.
##   - Espurnes de colors en llançar màgia.
## Es pot desactivar a Opcions (Efectes del personatge).

const ALCADA_PIVOT := 0.8      # on és l'origen de l'esquelet respecte els peus
const RIGIDESA := 14.0         # com de ràpid torna a la mida normal
const COLOR_POLS := Color(0.85, 0.8, 0.68, 0.85)
const COLOR_AIGUA := Color(0.75, 0.9, 1.0, 0.85)

var jugador: CharacterBody3D
var skeleton: Node3D
var escala := Vector2.ONE       # (horitzontal, vertical)
var a_terra := true
var velocitat_caiguda := 0.0
var dash_abans := false
var atacant_abans := false
var magia_abans := 99.0
var temps_corrent := 0.0

static var _malla_pols: SphereMesh

static func crear(p_jugador: CharacterBody3D) -> EfectesJugador:
	var e := EfectesJugador.new()
	e.name = "EfectesJugador"
	e.jugador = p_jugador
	return e

func _ready():
	skeleton = jugador.get_node_or_null("Skeleton")

func _actius() -> bool:
	return SettingsManager.valor("efectes_personatge")

## Un petit batec (per a qualsevol acció): el personatge s'eixampla i torna
static func batec(qui: Node, forca := 1.0):
	var j := qui.get_tree().get_first_node_in_group("player") if qui else null
	var e: EfectesJugador = j.get_node_or_null("EfectesJugador") if j else null
	if e:
		e.deformar(Vector2(1.0 + 0.14 * forca, 1.0 - 0.12 * forca))

func deformar(nova: Vector2):
	escala = nova

func _physics_process(_delta):
	if jugador == null or jugador.barca != null:
		a_terra = true
		return
	var terra := jugador.is_on_floor()
	if a_terra and not terra and jugador.velocity.y > 1.0:
		# Salt
		deformar(Vector2(0.8, 1.22))
		pols(jugador.global_position, 8, Vector3.ZERO, 1.0)
	elif not a_terra and terra:
		# Aterratge: com més ràpid queia, més s'aixafa i més pols
		var f := clampf(velocitat_caiguda / 12.0, 0.25, 1.0)
		deformar(Vector2(1.0 + 0.3 * f, 1.0 - 0.3 * f))
		pols(jugador.global_position, int(6 + 12 * f), Vector3.ZERO, 0.8 + f)
	if not terra:
		velocitat_caiguda = maxf(0.0, -jugador.velocity.y)
	a_terra = terra
	# Dash: una bufada de pols cap enrere i s'estira cap endavant
	if jugador.dash_actiu and not dash_abans:
		var dir: Vector3 = jugador.dash_direccio
		deformar(Vector2(1.25, 0.85))
		pols(jugador.global_position, 12, -dir, 1.2)
	dash_abans = jugador.dash_actiu
	# Atacs
	if jugador.atacant and not atacant_abans and not jugador.dash_actiu:
		deformar(Vector2(1.12, 0.9))
	atacant_abans = jugador.atacant
	# Màgia (bola de foc): espurnes i batec
	if jugador.temps_darrera_magia < magia_abans and magia_abans > 0.2:
		deformar(Vector2(1.18, 0.86))
		espurnes(jugador.global_position + Vector3.UP * 0.9, Color(1.0, 0.55, 0.2))
	magia_abans = jugador.temps_darrera_magia
	# Una mica de pols de tant en tant mentre corre
	var horitzontal := Vector2(jugador.velocity.x, jugador.velocity.z).length()
	if terra and horitzontal > 6.0:
		temps_corrent += _delta
		if temps_corrent > 0.22:
			temps_corrent = 0.0
			pols(jugador.global_position, 3, -Vector3(jugador.velocity.x, 0, jugador.velocity.z).normalized(), 0.5)
	else:
		temps_corrent = 0.0

func _process(delta):
	if skeleton == null:
		return
	escala = escala.lerp(Vector2.ONE, 1.0 - exp(-RIGIDESA * delta))
	if not _actius():
		escala = Vector2.ONE
	skeleton.scale = Vector3(escala.x, escala.y, escala.x)
	# Que els peus es quedin a terra (l'esquelet es deforma des del centre)
	skeleton.position.y -= (1.0 - escala.y) * ALCADA_PIVOT

## Un núvol de pols als peus (o d'esquitxos, si és a l'aigua)
func pols(on: Vector3, quantitat: int, direccio := Vector3.ZERO, forca := 1.0):
	if not _actius() or not is_inside_tree():
		return
	var aigua: bool = jugador.has_method("profunditat_aigua") and jugador.profunditat_aigua() > 0.05
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(2, quantitat)
	p.lifetime = 0.5
	p.explosiveness = 0.95
	p.local_coords = false
	if direccio == Vector3.ZERO:
		p.direction = Vector3.UP
		p.spread = 80.0
		p.flatness = 0.7
	else:
		p.direction = (direccio.normalized() + Vector3.UP * 0.4).normalized()
		p.spread = 30.0
	p.initial_velocity_min = 1.0 * forca
	p.initial_velocity_max = 2.4 * forca
	p.gravity = Vector3(0, -2.0, 0)
	p.damping_min = 2.5
	p.damping_max = 4.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var corba := Curve.new()
	corba.add_point(Vector2(0, 0.6))
	corba.add_point(Vector2(0.3, 1.0))
	corba.add_point(Vector2(1, 0))
	p.scale_amount_curve = corba
	p.mesh = _malla()
	p.color = COLOR_AIGUA if aigua else COLOR_POLS
	_afegir(p, on + Vector3.UP * 0.08)

## Espurnes de màgia
func espurnes(on: Vector3, color: Color):
	if not _actius() or not is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, 1.0, 0)
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 0.8
	var corba := Curve.new()
	corba.add_point(Vector2(0, 1))
	corba.add_point(Vector2(1, 0))
	p.scale_amount_curve = corba
	p.mesh = _malla()
	p.color = color
	_afegir(p, on)

func _afegir(p: CPUParticles3D, on: Vector3):
	var mon := get_tree().current_scene
	mon.add_child(p)
	p.global_position = on
	p.emitting = true
	p.finished.connect(p.queue_free)

static func _malla() -> SphereMesh:
	if _malla_pols == null:
		_malla_pols = SphereMesh.new()
		_malla_pols.radius = 0.07
		_malla_pols.height = 0.14
		_malla_pols.radial_segments = 6
		_malla_pols.rings = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_malla_pols.material = m
	return _malla_pols
