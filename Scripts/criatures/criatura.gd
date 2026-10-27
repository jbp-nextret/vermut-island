extends CharacterBody3D
class_name Criatura
## Una criatura: salvatge (passeja, fuig o ataca segons el caràcter) o domesticada
## (et segueix i t'ajuda amb la seva habilitat). Es crea amb Criatura.crear(especie).
##
## Salvatge → per domesticar-la ha d'estar "capturable":
##   - menjant olives marinades (herbívores), o
##   - hipnotitzada amb vermut hipnòtic (qualsevol; les de força 4+ cal debilitar-les)
## i llavors F a prop obre el minijoc (Domesticacio).

enum Estat { QUIET, PASSEJANT, FUGINT, PERSEGUINT, ANANT_ESQUER, MENJANT, HIPNOTITZADA, DOMESTICANT,
	SEGUINT, AJUDANT, A_LA_BARCA }

const GRAVETAT := 20.0
const RADI_PASSEIG := 4.5
const DISTANCIA_POR := 4.5
const DISTANCIA_ATAC := 6.5
const RADI_ESQUER := 8.0
const DURADA_MENJAR := 12.0
const ABAST_DOMESTICAR := 2.0
const SEGONS_HIPNOSI := 10.0

var especie: EspecieCriatura
var domesticada := false
var uid := ""
var vida := 30
var vida_maxima := 30
var estat: Estat = Estat.QUIET
var temps_estat := 0.0
var casa := Vector3.ZERO
var desti := Vector3.ZERO
var esquer: Node3D = null
var feina: Node3D = null
var temps_cop := 0.0
var temps_habilitat := 0.0
var enfadada := false        # una tranquil·la que has atacat
var mirall := false

var sprite: Sprite3D
var icona: Label3D
var etiqueta: Label3D
var llum: OmniLight3D
var barra_vida: BarraVida3D
var offset_sprite := Vector3.ZERO
var pos_anterior := Vector3.ZERO
var temps_anim := 0.0
var flash := 0.0

static func crear(e: EspecieCriatura) -> Criatura:
	var c := Criatura.new()
	c.especie = e
	c.name = e.nom.to_pascal_case() if not e.nom.is_empty() else "Criatura"
	return c

func _ready():
	vida_maxima = especie.vida
	vida = vida_maxima
	casa = global_position
	pos_anterior = global_position
	# Les salvatges també a la capa 1, com els enemics: així les toquen les boles de foc.
	# La companya només a la 32 (no t'encalla ni et bloqueja el pas)
	collision_layer = 32 if domesticada else 1 | 32
	collision_mask = 1
	floor_snap_length = 0.3

	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.28 * especie.mida
	capsula.height = maxf(capsula.radius * 2.0, 0.75 * especie.mida)
	forma.shape = capsula
	forma.position.y = capsula.height / 2.0
	add_child(forma)

	sprite = Sprite3D.new()
	sprite.texture = especie.textura()
	sprite.pixel_size = 0.036 * especie.mida * 32.0 / float(sprite.texture.get_width())
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	# Els peus a terra (el dibuix deixa 3 px buits a sota)
	offset_sprite = Vector3.UP * (sprite.texture.get_height() / 2.0 - 3.0) * sprite.pixel_size
	sprite.position = offset_sprite
	add_child(sprite)

	var alcada := sprite.texture.get_height() * sprite.pixel_size
	icona = _label(72, Color.WHITE)
	icona.position = Vector3.UP * (alcada + 0.25)
	add_child(icona)
	etiqueta = _label(26, Color(1, 1, 1, 0.9))
	etiqueta.position = Vector3.UP * (alcada + 0.05)
	add_child(etiqueta)
	barra_vida = BarraVida3D.crear(self, alcada + 0.1)

	if domesticada:
		add_to_group("criatura_companya")
		add_to_group("interactuables")
		actualitzar_nom()
		_canviar_estat(Estat.SEGUINT)
		if especie.habilitat == EspecieCriatura.Ajuda.LLUM:
			llum = OmniLight3D.new()
			llum.light_color = especie.color.lightened(0.4)
			llum.omni_range = 6.0
			llum.light_energy = 0.0
			llum.shadow_enabled = false
			llum.position = Vector3.UP * alcada * 0.6
			add_child(llum)
	else:
		add_to_group("criatures_salvatges")
		add_to_group("interactuables")
		etiqueta.text = especie.nom
	temps_habilitat = especie.valor_habilitat if especie.habilitat == EspecieCriatura.Ajuda.BUSCAR else 0.0

func _label(mida: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = mida
	l.outline_size = 14
	l.pixel_size = 0.006
	l.modulate = color
	l.visible = false
	return l

func actualitzar_nom():
	etiqueta.text = Criatures.dades(uid).get("nom", especie.nom)

func _canviar_estat(nou: Estat):
	estat = nou
	temps_estat = 0.0

func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

static func _pla(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

# ─────────────── Estat de captura

## Es pot domesticar ara mateix (menja o està hipnotitzada)?
func capturable() -> bool:
	return not domesticada and estat in [Estat.MENJANT, Estat.HIPNOTITZADA]

func debilitada() -> bool:
	return vida <= vida_maxima * 0.5

## Les olives marinades l'atrauen (només herbívores i si no està enfadada)
func atraure(e: Node3D) -> bool:
	if domesticada or especie.dieta != EspecieCriatura.Dieta.HERBIVORA or enfadada:
		return false
	if estat in [Estat.MENJANT, Estat.HIPNOTITZADA, Estat.DOMESTICANT, Estat.ANANT_ESQUER]:
		return false
	esquer = e
	_canviar_estat(Estat.ANANT_ESQUER)
	_mostrar_icona("🫒")
	return true

## El vermut hipnòtic. Retorna false si l'aguanta (força 4+ sense debilitar)
func hipnotitzar() -> bool:
	if domesticada or estat == Estat.DOMESTICANT:
		return false
	if especie.forca >= 4 and not debilitada():
		_mostrar_icona("💢")
		TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.4, "Massa forta! Debilita-la", Color(1, 0.55, 0.45))
		if especie.caracter != EspecieCriatura.Caracter.POREGOSA:
			enfadada = true
			_canviar_estat(Estat.PERSEGUINT)
		return false
	_canviar_estat(Estat.HIPNOTITZADA)
	_mostrar_icona("💫")
	velocity = Vector3.ZERO
	return true

func durada_hipnosi() -> float:
	return SEGONS_HIPNOSI * (1.0 - (especie.forca - 1) * 0.12)

func _mostrar_icona(text: String):
	icona.text = text
	icona.visible = not text.is_empty()

# ─────────────── Interacció (F)

func pot_interactuar(jugador: Node) -> bool:
	if domesticada:
		return estat == Estat.SEGUINT and _pla(jugador.global_position - global_position).length() < 1.6
	return capturable() and _pla(jugador.global_position - global_position).length() < ABAST_DOMESTICAR

func text_interaccio(_jugador: Node) -> String:
	if domesticada:
		return "Acaronar %s" % etiqueta.text
	return "Domesticar %s" % especie.nom

func punt_interaccio() -> Vector3:
	return global_position + Vector3.UP * 0.3

func interactuar(_interaccio: Node) -> void:
	if domesticada:
		_mostrar_icona("❤")
		temps_cop = 0.0
		var t := create_tween()
		t.tween_property(sprite, "scale", Vector3(1.2, 0.8, 1.0), 0.08)
		t.tween_property(sprite, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		t.tween_interval(1.0)
		t.tween_callback(_mostrar_icona.bind(""))
		return
	if not capturable():
		return
	_canviar_estat(Estat.DOMESTICANT)
	_mostrar_icona("")
	etiqueta.visible = false
	Domesticacio.comencar(self)

## El minijoc ha acabat
func resultat_domesticacio(exit: bool):
	if exit:
		Criatures.capturar(especie)
		_desapareixer("❤")
		return
	# Se t'escapa: les herbívores fugen, les carnívores s'enfaden
	_mostrar_icona("💢")
	enfadada = true
	if especie.dieta == EspecieCriatura.Dieta.CARNIVORA or especie.caracter == EspecieCriatura.Caracter.AGRESSIVA:
		_canviar_estat(Estat.PERSEGUINT)
	else:
		_canviar_estat(Estat.FUGINT)

func _desapareixer(text: String):
	remove_from_group("criatures_salvatges")
	remove_from_group("interactuables")
	set_physics_process(false)
	_mostrar_icona(text)
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector3(1.3, 1.3, 1.0), 0.12)
	t.tween_property(sprite, "scale", Vector3(0.01, 1.6, 1.0), 0.25)
	t.parallel().tween_property(sprite, "modulate:a", 0.0, 0.25)
	t.tween_callback(queue_free)

# ─────────────── Combat

func prendre_dany(quantitat: int, origen: Vector3 = Vector3.INF):
	if domesticada or vida <= 0 or estat == Estat.DOMESTICANT:
		return
	vida -= quantitat
	flash = 0.2
	barra_vida.mostrar(vida, vida_maxima)
	if SettingsManager.valor("numeros_dany"):
		TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 0.9, str(quantitat), Color.WHITE)
	if origen.is_finite():
		var lluny := _pla(global_position - origen).normalized()
		velocity += lluny * 5.0 + Vector3.UP * 2.0
	if vida <= 0:
		# No mor: fuig i desapareix (ja en sortirà una altra)
		TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.2, "S'ha escapat!", Color(1, 0.8, 0.5))
		_desapareixer("💨")
		return
	# Un cop la desperta i la fa reaccionar
	if especie.caracter == EspecieCriatura.Caracter.POREGOSA or (especie.dieta == EspecieCriatura.Dieta.HERBIVORA and especie.caracter != EspecieCriatura.Caracter.AGRESSIVA):
		_canviar_estat(Estat.FUGINT)
	else:
		enfadada = true
		_canviar_estat(Estat.PERSEGUINT)
	_mostrar_icona("💢" if enfadada else "")

# ─────────────── Cada frame

func _physics_process(delta):
	pos_anterior = global_position
	temps_estat += delta
	temps_cop += delta
	if estat == Estat.A_LA_BARCA or _a_la_barca():
		_seure_a_la_barca()
		return
	if not is_on_floor():
		velocity.y -= GRAVETAT * delta
	else:
		velocity.y = maxf(velocity.y, 0.0)
	if global_position.y < -10.0:
		if domesticada:
			apareixer_al_costat_del_jugador()
		else:
			global_position = casa + Vector3.UP
		velocity = Vector3.ZERO

	var moviment := Vector3.ZERO
	var rapid := 1.0
	if domesticada:
		var r := _company(delta)
		moviment = r[0]
		rapid = r[1]
	else:
		var r := _salvatge(delta)
		moviment = r[0]
		rapid = r[1]

	var objectiu := moviment * especie.velocitat * rapid
	velocity.x = move_toward(velocity.x, objectiu.x, 30.0 * delta)
	velocity.z = move_toward(velocity.z, objectiu.z, 30.0 * delta)
	move_and_slide()
	if absf(moviment.x) > 0.05:
		mirall = _cap_a_la_camera(moviment) < 0.0

func _salvatge(_delta) -> Array:
	var jugador := _jugador()
	var cap_jugador := _pla(jugador.global_position - global_position) if jugador else Vector3(99, 0, 99)
	var d_jugador := cap_jugador.length()
	match estat:
		Estat.QUIET:
			if temps_estat > randf_range(2.0, 5.0):
				var angle := randf() * TAU
				desti = casa + Vector3(cos(angle), 0, sin(angle)) * randf_range(1.0, RADI_PASSEIG)
				_canviar_estat(Estat.PASSEJANT)
			return _reaccionar(d_jugador, cap_jugador, Vector3.ZERO)
		Estat.PASSEJANT:
			var m := _cap_a(desti, 0.3)
			if m == Vector3.ZERO or temps_estat > 6.0:
				_canviar_estat(Estat.QUIET)
			return _reaccionar(d_jugador, cap_jugador, m * 0.6)
		Estat.FUGINT:
			if temps_estat > 3.0 or d_jugador > DISTANCIA_POR * 2.2:
				enfadada = false
				_mostrar_icona("")
				_canviar_estat(Estat.QUIET)
				return [Vector3.ZERO, 1.0]
			var fugida := -cap_jugador.normalized()
			if _aigua_davant(fugida):
				fugida = _pla(casa - global_position).normalized()
			return [fugida, 1.7]
		Estat.PERSEGUINT:
			if jugador == null or d_jugador > DISTANCIA_ATAC * 2.0 or _pla(global_position - casa).length() > 14.0:
				enfadada = false
				_mostrar_icona("")
				_canviar_estat(Estat.QUIET)
				desti = casa
				return [Vector3.ZERO, 1.0]
			if d_jugador < 1.1:
				if temps_cop > 1.3:
					temps_cop = 0.0
					SalutJugador.prendre_dany(especie.dany)
					_saltet()
				return [Vector3.ZERO, 1.0]
			return [cap_jugador.normalized(), 1.35]
		Estat.ANANT_ESQUER:
			if not is_instance_valid(esquer) or temps_estat > 10.0:
				_mostrar_icona("")
				_canviar_estat(Estat.QUIET)
				return [Vector3.ZERO, 1.0]
			var m := _cap_a(esquer.global_position, 0.55)
			if m == Vector3.ZERO:
				if esquer.menjar():
					_canviar_estat(Estat.MENJANT)
					_mostrar_icona("🫒")
				else:
					_mostrar_icona("")
					_canviar_estat(Estat.QUIET)
			return [m, 1.2]
		Estat.MENJANT:
			if temps_estat > DURADA_MENJAR:
				_mostrar_icona("")
				_canviar_estat(Estat.QUIET)
				casa = global_position
			return [Vector3.ZERO, 1.0]
		Estat.HIPNOTITZADA:
			if temps_estat > durada_hipnosi():
				_mostrar_icona("")
				_canviar_estat(Estat.QUIET)
			return [Vector3.ZERO, 1.0]
	return [Vector3.ZERO, 1.0]

## Mentre passeja: si el jugador s'acosta, fuig o ataca segons el caràcter
func _reaccionar(d_jugador: float, _cap: Vector3, moviment: Vector3) -> Array:
	match especie.caracter:
		EspecieCriatura.Caracter.POREGOSA:
			if d_jugador < DISTANCIA_POR:
				_canviar_estat(Estat.FUGINT)
		EspecieCriatura.Caracter.AGRESSIVA:
			if d_jugador < DISTANCIA_ATAC:
				enfadada = true
				_mostrar_icona("💢")
				_canviar_estat(Estat.PERSEGUINT)
	return [moviment, 1.0]

func _company(delta) -> Array:
	var jugador := _jugador()
	if jugador == null:
		return [Vector3.ZERO, 1.0]
	var cap_jugador := _pla(jugador.global_position - global_position)
	if cap_jugador.length() > 14.0 or absf(jugador.global_position.y - global_position.y) > 4.0:
		apareixer_al_costat_del_jugador()
		return [Vector3.ZERO, 1.0]
	_habilitats(delta, jugador)
	match estat:
		Estat.AJUDANT:
			if not is_instance_valid(feina) or temps_estat > 8.0 or (feina.is_in_group("enemics") and _pla(feina.global_position - jugador.global_position).length() > 10.0):
				_acabar_feina()
				return [Vector3.ZERO, 1.0]
			var abast := 1.0 if feina.is_in_group("enemics") else 0.8
			var m := _cap_a(feina.global_position, abast)
			if m == Vector3.ZERO:
				_fer_feina()
			return [m, 1.8]
		_:
			# Segueix una mica per darrere
			if cap_jugador.length() > 2.2:
				return [cap_jugador.normalized(), clampf(cap_jugador.length() / 2.0, 1.0, 2.6)]
			return [Vector3.ZERO, 1.0]

func _habilitats(delta: float, jugador: Node3D):
	var h := especie.habilitat
	if llum:
		var objectiu: float = especie.valor_habilitat if GestorTemps.es_nit() else 0.0
		llum.light_energy = move_toward(llum.light_energy, objectiu, delta)
	if estat != Estat.SEGUINT:
		return
	temps_habilitat -= delta
	match h:
		EspecieCriatura.Ajuda.ATACAR:
			if temps_habilitat <= 0.0:
				temps_habilitat = 0.5
				feina = _enemic_proper(jugador, 7.0)
				if feina:
					_canviar_estat(Estat.AJUDANT)
		EspecieCriatura.Ajuda.REGAR:
			if temps_habilitat <= 0.0:
				temps_habilitat = 4.0
				feina = _cultiu_amb_set(jugador, 7.0)
				if feina:
					feina.set_meta("regant", true)
					_canviar_estat(Estat.AJUDANT)
		EspecieCriatura.Ajuda.BUSCAR:
			if temps_habilitat <= 0.0 and is_on_floor():
				temps_habilitat = especie.valor_habilitat
				_trobar_alguna_cosa()

func _enemic_proper(jugador: Node3D, radi: float) -> Node3D:
	var millor: Node3D = null
	var millor_d := radi
	for e in get_tree().get_nodes_in_group("enemics"):
		if not is_instance_valid(e):
			continue
		var d := _pla(e.global_position - jugador.global_position).length()
		if d < millor_d:
			millor = e
			millor_d = d
	return millor

func _cultiu_amb_set(jugador: Node3D, radi: float) -> Node3D:
	var millor: Node3D = null
	var millor_d := radi
	for c in get_tree().get_nodes_in_group("cultius"):
		if not c.necessita_aigua() or c.has_meta("regant"):
			continue
		var d := _pla(c.global_position - jugador.global_position).length()
		if d < millor_d:
			millor = c
			millor_d = d
	return millor

func _fer_feina():
	if feina.is_in_group("enemics"):
		if temps_cop >= 1.0:
			temps_cop = 0.0
			_saltet()
			feina.prendre_dany(roundi(especie.valor_habilitat), global_position)
		return   # segueix atacant fins que mori o s'allunyi
	if feina.is_in_group("cultius"):
		feina.regar()
		Progressio.accio_feta.emit("regar", 1)
		TextFlotant.mostrar(get_parent(), feina.global_position + Vector3.UP * 0.8, "💧", Color(0.5, 0.8, 1.0))
		_saltet()
	_acabar_feina()

func _acabar_feina():
	if is_instance_valid(feina) and feina.has_meta("regant"):
		feina.remove_meta("regant")
	feina = null
	_canviar_estat(Estat.SEGUINT)

func _trobar_alguna_cosa():
	if especie.troballes.is_empty():
		return
	var objecte: String = especie.troballes[randi() % especie.troballes.size()]
	if not Inventari.afegir(objecte, 1):
		return
	_saltet()
	var info := CatalegObjectes.info(objecte)
	TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.0, "+1 %s" % info.icona, Color(1.0, 0.9, 0.6))
	EventBus.avis.emit("%s ha trobat %s" % [etiqueta.text, info.nom.to_lower()])

func apareixer_al_costat_del_jugador():
	var jugador := _jugador()
	if jugador == null:
		return
	var mon := get_tree().current_scene
	var aigua: float = mon.nivell_aigua() if mon and mon.has_method("nivell_aigua") else -INF
	global_position = jugador.global_position + Vector3(0.0, 0.3, 1.2)
	if is_inside_tree():
		var espai := get_world_3d().direct_space_state
		for despl in [Vector3(0, 0, 1.2), Vector3(1.2, 0, 0.4), Vector3(-1.2, 0, 0.4), Vector3(0, 0, -1.2), Vector3(0.6, 0, 0)]:
			var p: Vector3 = jugador.global_position + despl
			var raig := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.5, p + Vector3.DOWN * 2.5, 1)
			raig.exclude = [get_rid(), jugador.get_rid()]
			var cop := espai.intersect_ray(raig)
			if not cop.is_empty() and cop.normal.y > 0.7 and cop.position.y > aigua - 0.55:
				global_position = cop.position + Vector3.UP * 0.05
				break
	velocity = Vector3.ZERO
	pos_anterior = global_position
	_canviar_estat(Estat.SEGUINT)

# ─────────────── Barca

func _a_la_barca() -> bool:
	if not domesticada:
		return false
	var jugador := _jugador()
	return jugador != null and "barca" in jugador and jugador.barca != null

func _seure_a_la_barca():
	var jugador := _jugador()
	if jugador == null or not ("barca" in jugador) or jugador.barca == null:
		apareixer_al_costat_del_jugador()
		return
	estat = Estat.A_LA_BARCA
	velocity = Vector3.ZERO
	global_position = jugador.barca.seient(3)
	if not _a_la_barca():
		apareixer_al_costat_del_jugador()

# ─────────────── Moviment

func _cap_a(punt: Vector3, marge: float) -> Vector3:
	var cap := _pla(punt - global_position)
	if cap.length() <= marge:
		return Vector3.ZERO
	return cap.normalized()

## Hi ha aigua fonda just davant? (per no fugir cap al mar)
func _aigua_davant(direccio: Vector3) -> bool:
	var mon := get_tree().current_scene
	if mon == null or not mon.has_method("nivell_aigua"):
		return false
	var p := global_position + direccio * 1.2
	var raig := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 1.0, p + Vector3.DOWN * 3.0, 1)
	raig.exclude = [get_rid()]
	var cop := get_world_3d().direct_space_state.intersect_ray(raig)
	return cop.is_empty() or cop.position.y < mon.nivell_aigua() - 0.3

func _cap_a_la_camera(v: Vector3) -> float:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return v.x
	return v.dot(camera.global_basis.x)

func _saltet():
	var t := create_tween()
	t.tween_property(sprite, "position", offset_sprite + Vector3.UP * 0.25, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "position", offset_sprite, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# ─────────────── Aspecte

func _process(delta):
	if sprite == null:
		return
	temps_anim += delta
	# Interpolació entre passos de física
	var f := Engine.get_physics_interpolation_fraction()
	var visual := pos_anterior.lerp(global_position, f)
	if pos_anterior.distance_to(global_position) > 2.0:
		visual = global_position
	var movent := _pla(velocity).length() > 0.3
	var bot := absf(sin(temps_anim * 12.0)) * 0.08 if movent else 0.0
	var respira := sin(temps_anim * 2.5) * 0.03
	sprite.position = offset_sprite + (visual - global_position) + Vector3.UP * bot
	sprite.flip_h = mirall
	if estat != Estat.DOMESTICANT and not get_tree().paused:
		sprite.scale = sprite.scale.lerp(Vector3(1.0 - respira, 1.0 + respira, 1.0), minf(1.0, delta * 10.0))
	# Hipnotitzada: es balanceja; menjant: pica el terra
	match estat:
		Estat.HIPNOTITZADA:
			sprite.rotation.z = sin(temps_anim * 3.0) * 0.15
			icona.rotation.z = temps_anim * 4.0
		Estat.MENJANT:
			sprite.rotation.z = -absf(sin(temps_anim * 6.0)) * 0.12 * (-1.0 if mirall else 1.0)
		_:
			sprite.rotation.z = 0.0
			icona.rotation.z = 0.0
	if flash > 0.0:
		flash -= delta
		sprite.modulate = Color(1, 0.4, 0.4) if flash > 0.0 else Color.WHITE
	# El nom surt quan el jugador és a prop
	var jugador := _jugador()
	etiqueta.visible = estat != Estat.DOMESTICANT and jugador != null and _pla(jugador.global_position - global_position).length() < 4.0 and not icona.visible
