extends Node3D
class_name Recolector
## Talar arbres i picar roques amb el ratolí: en passar-hi per sobre surt "🪓 Talar" o
## "⛏ Picar", i en clicar apareix la destral o el pic màgic i hi dona un cop.
## (L'herba es talla amb l'espasa: ho fa CombatMagic.)

const ABAST := 2.8
const RECARREGA := 0.4
const COLOR_EINA := Color(0.75, 0.9, 1.0)

var mon: Node3D
var jugador: Node3D
var eines_actives: Array = []   # plantador, regador, llaurador: si n'hi ha cap d'activa, no fem res
var recurs_sota_ratoli: RecursNatural = null
var etiqueta: Label3D
var temps_des_del_cop := 99.0

func _ready():
	etiqueta = Label3D.new()
	etiqueta.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	etiqueta.no_depth_test = true
	etiqueta.font_size = 40
	etiqueta.outline_size = 12
	etiqueta.pixel_size = 0.008
	etiqueta.top_level = true
	etiqueta.visible = false
	add_child(etiqueta)

func _process(delta):
	temps_des_del_cop += delta
	recurs_sota_ratoli = _recurs_sota_ratoli() if _pot_recollectar() else null
	etiqueta.visible = recurs_sota_ratoli != null
	if recurs_sota_ratoli:
		var a_labast := _a_labast(recurs_sota_ratoli)
		etiqueta.text = recurs_sota_ratoli.nom_accio() if a_labast else "Massa lluny"
		etiqueta.modulate = Color(1, 1, 1) if a_labast else Color(1, 0.6, 0.55)
		var caixa := recurs_sota_ratoli.caixa()
		# A l'alçada del cap del personatge, no a dalt de tot de l'arbre (que pot ser molt alt)
		var alcada := minf(caixa.end.y + 0.3, caixa.position.y + 2.2)
		etiqueta.global_position = Vector3(caixa.get_center().x, alcada, caixa.get_center().z)

func _unhandled_input(event: InputEvent):
	if recurs_sota_ratoli == null or not event.is_action_pressed("accio_primaria"):
		return
	get_viewport().set_input_as_handled()   # no ataquem quan cliquem un arbre o una roca
	if not _a_labast(recurs_sota_ratoli) or temps_des_del_cop < RECARREGA:
		return
	temps_des_del_cop = 0.0
	var recurs := recurs_sota_ratoli
	# El personatge s'hi gira i fa el gest; l'eina apareix al costat del recurs
	var cap := recurs.global_position - jugador.global_position
	cap.y = 0
	if cap.length() > 0.1 and jugador.has_method("_mirar_cap_a"):
		jugador._mirar_cap_a(cap.normalized())
		jugador.play_anim("attack_" + jugador.ultima_direccio, jugador.mirall_horitzontal)
	var punt := CombatMagic.terra_sota(jugador, recurs.global_position) + Vector3.UP * 0.4
	var eina := "destral" if recurs.tipus == RecursNatural.Tipus.ARBRE else "pic"
	var durada := EinaMagica.invocar(mon, punt, eina, COLOR_EINA)
	get_tree().create_timer(durada).timeout.connect(func():
		if is_instance_valid(recurs):
			recurs.rebre_cop()
			if jugador.has_method("camera_shake"):
				jugador.camera_shake(0.05))

func _pot_recollectar() -> bool:
	if not GameState.pot_atacar():
		return false
	for e in eines_actives:
		if e.actiu:
			return false
	return true

func _a_labast(recurs: RecursNatural) -> bool:
	var d := recurs.global_position - jugador.global_position
	d.y = 0
	return d.length() <= ABAST

## L'arbre o roca sota el ratolí (pel rectangle que ocupa a la pantalla)
func _recurs_sota_ratoli() -> RecursNatural:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null
	var ratoli := get_viewport().get_mouse_position()
	var millor: RecursNatural = null
	var millor_distancia := INF
	for r in get_tree().get_nodes_in_group("recursos"):
		if not r.clicable():
			continue
		var caixa: AABB = r.caixa()
		var rect := Rect2()
		for i in 8:
			var p := camera.unproject_position(caixa.get_endpoint(i))
			rect = Rect2(p, Vector2.ZERO) if i == 0 else rect.expand(p)
		# Una mica més estret que la caixa (els sprites tenen marges transparents)
		rect = rect.grow_individual(-rect.size.x * 0.2, -rect.size.y * 0.1, -rect.size.x * 0.2, 0.0)
		if rect.has_point(ratoli):
			var d := ratoli.distance_to(rect.get_center())
			if d < millor_distancia:
				millor = r
				millor_distancia = d
	return millor
