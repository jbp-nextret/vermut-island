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
	SEGUINT, AJUDANT, A_LA_BARCA, ATACANT, BUSCANT, PORTANT, CACANT, CORRAL, TREBALLANT }

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
## Nivell (les salvatges en tenen un segons la zona; les domesticades el guanyen)
var nivell := 1
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
var objectiu_atac: Node3D = null
## Qui l'està caçant (una salvatge més amunt a la cadena alimentària)
var amenaca: Node3D = null
var temps_caca := randf() * 4.0
var especial_pendent := false
## Criatures del corral o de tasques (no et segueixen): "corral", "talar", "picar", "herba"
var mode_corral := ""
var corral: Node3D = null
var lloc_treball: Node3D = null
const RADI_CACA := 7.0
var temps_atac := 0.0
var portant := ""            # l'objecte que porta a la boca (BUSCAR)
var icona_portant: Label3D
var particules_llum: CPUParticles3D
var particules_velocitat: CPUParticles3D
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
	vida_maxima = roundi(especie.vida * Criatures.mult_vida(nivell))
	vida = vida_maxima
	casa = global_position
	pos_anterior = global_position
	# Les salvatges també a la capa 1, com els enemics: així les toquen les boles de foc.
	# La companya només a la 32 (no t'encalla ni et bloqueja el pas)
	collision_layer = 32 if domesticada else 1 | 32
	collision_mask = 1
	floor_snap_length = 0.3
	# La companya no topa amb el jugador (si no, s'hi encalla quan l'ha d'avançar)
	if domesticada:
		var jugador := get_tree().get_first_node_in_group("player")
		if jugador is PhysicsBody3D:
			add_collision_exception_with(jugador)

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

	if domesticada and not mode_corral.is_empty():
		add_to_group("criatures_corral")
		add_to_group("interactuables")
		actualitzar_nom()
		_canviar_estat(Estat.CORRAL if mode_corral == "corral" else Estat.TREBALLANT)
	elif domesticada:
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
			# Unes llumetes al voltant quan és fosc
			particules_llum = CPUParticles3D.new()
			particules_llum.amount = 10
			particules_llum.lifetime = 1.6
			particules_llum.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particules_llum.emission_sphere_radius = 0.6
			particules_llum.gravity = Vector3(0, 0.3, 0)
			particules_llum.initial_velocity_max = 0.1
			particules_llum.mesh = EfectesCriatura._quad(especie.color.lightened(0.5), 0.06)
			particules_llum.position = Vector3.UP * alcada * 0.6
			particules_llum.emitting = false
			add_child(particules_llum)
		if especie.habilitat == EspecieCriatura.Ajuda.VELOCITAT:
			# Línies de vent quan correu junts
			particules_velocitat = CPUParticles3D.new()
			particules_velocitat.amount = 14
			particules_velocitat.lifetime = 0.4
			particules_velocitat.local_coords = false
			particules_velocitat.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			particules_velocitat.emission_sphere_radius = 0.35
			particules_velocitat.gravity = Vector3.ZERO
			particules_velocitat.initial_velocity_max = 0.0
			particules_velocitat.scale_amount_min = 0.6
			particules_velocitat.mesh = EfectesCriatura._quad(Color(1, 1, 1, 0.7), 0.05)
			particules_velocitat.position = Vector3.UP * alcada * 0.4
			particules_velocitat.emitting = false
			add_child(particules_velocitat)
		if especie.habilitat == EspecieCriatura.Ajuda.DEFENSA:
			SalutJugador.vida_canviat.connect(_on_vida_jugador)
		icona_portant = _label(80, Color.WHITE)
		icona_portant.position = Vector3(0.25, alcada * 0.55, 0.05)
		icona_portant.no_depth_test = false
		add_child(icona_portant)
	else:
		add_to_group("criatures_salvatges")
		add_to_group("interactuables")
		etiqueta.text = "%s · Nv %d" % [especie.nom, nivell]
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
	etiqueta.text = "%s · Nv %d" % [Criatures.dades(uid).get("nom", especie.nom), nivell]

## Ha pujat de nivell: més vida (i el nom)
func aplicar_nivell():
	nivell = Criatures.nivell(uid)
	vida_maxima = roundi(especie.vida * Criatures.mult_vida(nivell))
	vida = vida_maxima
	actualitzar_nom()
	_mostrar_icona("⭐")
	get_tree().create_timer(1.2).timeout.connect(_mostrar_icona.bind(""))

func dany() -> int:
	return roundi(especie.dany_atac() * Criatures.mult_dany(nivell))

func recarrega() -> float:
	return especie.recarrega() * Criatures.mult_recarrega(nivell)

## Les domesticades aprenen: experiència per a aquesta criatura
func guanyar_xp(quantitat: int):
	if domesticada:
		Criatures.guanyar_xp(uid, quantitat * (2 if Tactica.activa else 1))

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
		return estat in [Estat.SEGUINT, Estat.CORRAL] and _pla(jugador.global_position - global_position).length() < 1.6
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
		Criatures.capturar(especie, nivell)
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
		if is_instance_valid(amenaca) and amenaca.objectiu_atac == self:
			TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.2, "🍖", Color(1, 0.8, 0.5))
		else:
			TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.2, "S'ha escapat!", Color(1, 0.8, 0.5))
			if Tactica.activa:
				_deixar_boti()
		_desapareixer("💨")
		return
	# Pausa tàctica: quan queda poca vida, es rendeix i la pots domesticar
	if Tactica.activa and vida <= vida_maxima * 0.35 and not (is_instance_valid(amenaca) and amenaca.objectiu_atac == self):
		_canviar_estat(Estat.HIPNOTITZADA)
		set_meta("rendida", true)
		_mostrar_icona("🏳")
		TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.3, "Es rendeix!", Color(0.9, 0.95, 1.0))
		return
	# Si l'ataca un depredador, fuig d'ell (no del jugador)
	if is_instance_valid(amenaca) and origen.is_finite() and _pla(amenaca.global_position - origen).length() < 1.6:
		_canviar_estat(Estat.FUGINT)
		return
	# Un cop la desperta i la fa reaccionar
	if especie.caracter == EspecieCriatura.Caracter.POREGOSA or (especie.dieta == EspecieCriatura.Dieta.HERBIVORA and especie.caracter != EspecieCriatura.Caracter.AGRESSIVA):
		_canviar_estat(Estat.FUGINT)
	else:
		enfadada = true
		_canviar_estat(Estat.PERSEGUINT)
	_mostrar_icona("💢" if enfadada else "")

## Pausa tàctica: botí extra en derrotar-la
func _deixar_boti():
	if especie.boti.is_empty():
		return
	var objecte: String = especie.boti[randi() % especie.boti.size()]
	var quantitat := randi_range(1, 2)
	if Inventari.afegir(objecte, quantitat):
		TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.6, "+%d %s" % [quantitat, CatalegObjectes.info(objecte).icona], Color(1.0, 0.85, 0.4))
		EventBus.avis.emit("Botí tàctic: %s" % CatalegObjectes.info(objecte).nom.to_lower())

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
	if domesticada and not mode_corral.is_empty():
		var r := _al_corral(delta)
		moviment = r[0]
		rapid = r[1]
	elif domesticada:
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
	# Si topa amb un graó (un bloc de terra), fa un saltet per pujar-hi
	if is_on_floor() and is_on_wall() and moviment.length() > 0.1:
		velocity.y = 7.5
	if absf(moviment.x) > 0.05:
		mirall = _cap_a_la_camera(moviment) < 0.0

func _salvatge(_delta) -> Array:
	var jugador := _jugador()
	var cap_jugador := _pla(jugador.global_position - global_position) if jugador else Vector3(99, 0, 99)
	var d_jugador := cap_jugador.length()
	match estat:
		Estat.QUIET:
			if _potser_cacar(_delta):
				return [Vector3.ZERO, 1.0]
			if temps_estat > randf_range(2.0, 5.0):
				var angle := randf() * TAU
				desti = casa + Vector3(cos(angle), 0, sin(angle)) * randf_range(1.0, RADI_PASSEIG)
				_canviar_estat(Estat.PASSEJANT)
			return _reaccionar(d_jugador, cap_jugador, Vector3.ZERO)
		Estat.PASSEJANT:
			if _potser_cacar(_delta):
				return [Vector3.ZERO, 1.0]
			var m := _cap_a(desti, 0.3)
			if m == Vector3.ZERO or temps_estat > 6.0:
				_canviar_estat(Estat.QUIET)
			return _reaccionar(d_jugador, cap_jugador, m * 0.6)
		Estat.FUGINT:
			if temps_estat > 3.0 or (d_jugador > DISTANCIA_POR * 2.2 and not is_instance_valid(amenaca)):
				enfadada = false
				_mostrar_icona("")
				_canviar_estat(Estat.QUIET)
				return [Vector3.ZERO, 1.0]
			var fugida := -cap_jugador.normalized()
			if is_instance_valid(amenaca):
				fugida = -_pla(amenaca.global_position - global_position).normalized()
				if temps_estat > 3.0:
					amenaca = null
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
			# Les que disparen es queden a una distància; les que mosseguen s'acosten
			if especie.atac == EspecieCriatura.Atac.PROJECTIL:
				if d_jugador < especie.abast_atac * 0.85:
					if temps_cop > recarrega() * 1.3:
						temps_cop = 0.0
						_disparar(jugador, true)
					return [-cap_jugador.normalized() * (0.6 if d_jugador < 3.0 else 0.0), 1.0]
				return [cap_jugador.normalized(), 1.2]
			if d_jugador < 1.1:
				if temps_cop > recarrega() * 1.1:
					temps_cop = 0.0
					_mossegar(jugador, true)
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
		Estat.CACANT:
			return _cacar()
		Estat.HIPNOTITZADA:
			if temps_estat > durada_hipnosi():
				_mostrar_icona("")
				_canviar_estat(Estat.QUIET)
			return [Vector3.ZERO, 1.0]
	return [Vector3.ZERO, 1.0]

# ─────────────── Cadena alimentària

## Les carnívores, de tant en tant, cacen una presa més petita del seu territori
func _potser_cacar(delta: float) -> bool:
	if especie.dieta != EspecieCriatura.Dieta.CARNIVORA or enfadada:
		return false
	temps_caca -= delta
	if temps_caca > 0.0:
		return false
	temps_caca = randf_range(4.0, 8.0)
	if randf() > 0.45:
		return false
	var presa: Criatura = null
	var millor := RADI_CACA
	for c in get_tree().get_nodes_in_group("criatures_salvatges"):
		if c == self or c.especie.nivell_trofic >= especie.nivell_trofic or c.estat in [Estat.DOMESTICANT, Estat.HIPNOTITZADA]:
			continue
		# Del mateix territori (a prop de casa seva)
		if _pla(c.global_position - casa).length() > RADI_CACA * 1.6:
			continue
		var d := _pla(c.global_position - global_position).length()
		if d < millor:
			presa = c
			millor = d
	if presa == null:
		return false
	objectiu_atac = presa
	presa.amenaca = self
	_canviar_estat(Estat.CACANT)
	_mostrar_icona("💢")
	return true

func _cacar() -> Array:
	var presa := objectiu_atac
	if not is_instance_valid(presa) or not presa.is_in_group("criatures_salvatges"):
		# Si ha fet fugir (o caçat) la presa, s'atura a menjar
		objectiu_atac = null
		_mostrar_icona("🍖")
		_canviar_estat(Estat.MENJANT)
		casa = global_position
		return [Vector3.ZERO, 1.0]
	var cap := _pla(presa.global_position - global_position)
	if temps_estat > 12.0 or cap.length() > RADI_CACA * 2.0:
		objectiu_atac = null
		_mostrar_icona("")
		_canviar_estat(Estat.QUIET)
		return [Vector3.ZERO, 1.0]
	mirall = _cap_a_la_camera(cap) < 0.0
	if especie.atac == EspecieCriatura.Atac.PROJECTIL:
		if cap.length() > especie.abast_atac * 0.8:
			return [cap.normalized(), 1.4]
		if temps_cop > recarrega():
			temps_cop = 0.0
			_disparar(presa, false)
		return [Vector3.ZERO, 1.0]
	if cap.length() > 1.0:
		return [cap.normalized(), 1.6]
	if temps_cop > recarrega():
		temps_cop = 0.0
		_mossegar(presa, false)
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
	temps_atac += delta
	_habilitats(delta, jugador)
	match estat:
		Estat.ATACANT:
			return _atacar(jugador)
		Estat.AJUDANT:
			if not is_instance_valid(feina) or temps_estat > 8.0:
				_acabar_feina()
				return [Vector3.ZERO, 1.0]
			var m := _cap_a(feina.global_position, 1.2)
			if m == Vector3.ZERO:
				_fer_feina()
			return [m, 1.8]
		Estat.BUSCANT:
			# Remou la terra una estona; després surt la troballa i la porta
			if temps_estat > 1.4:
				_trobar_alguna_cosa()
			return [Vector3.ZERO, 1.0]
		Estat.PORTANT:
			if cap_jugador.length() < 1.3:
				_lliurar()
				return [Vector3.ZERO, 1.0]
			return [cap_jugador.normalized(), 1.9]
		_:
			# Segueix una mica per darrere
			if cap_jugador.length() > 2.2:
				return [cap_jugador.normalized(), clampf(cap_jugador.length() / 2.0, 1.0, 2.6)]
			return [Vector3.ZERO, 1.0]

## Què fa segons l'habilitat i el comportament (només quan et segueix tranquil·la)
func _habilitats(delta: float, jugador: Node3D):
	if llum:
		var nit := GestorTemps.es_nit()
		var objectiu: float = especie.valor_habilitat * (0.85 + 0.15 * sin(temps_anim * 3.0)) if nit else 0.0
		llum.light_energy = move_toward(llum.light_energy, objectiu, delta * 2.0)
		particules_llum.emitting = nit
	if particules_velocitat:
		particules_velocitat.emitting = _pla(velocity).length() > especie.velocitat * 1.5
	if estat != Estat.SEGUINT:
		return
	temps_habilitat -= delta
	# Atacar (segons el comportament que li hagis triat; en pausa tàctica, només per ordre)
	if temps_atac > 0.4 and not Tactica.activa:
		var enemic := _triar_enemic(jugador)
		if enemic:
			objectiu_atac = enemic
			_canviar_estat(Estat.ATACANT)
			if especie.habilitat == EspecieCriatura.Ajuda.ATACAR:
				_mostrar_icona("💢")
				get_tree().create_timer(0.8).timeout.connect(_mostrar_icona.bind(""))
			return
	match especie.habilitat:
		EspecieCriatura.Ajuda.REGAR:
			if temps_habilitat <= 0.0:
				temps_habilitat = 4.0
				feina = _cultiu_amb_set(jugador, 7.0)
				if feina:
					feina.set_meta("regant", true)
					_canviar_estat(Estat.AJUDANT)
		EspecieCriatura.Ajuda.BUSCAR:
			if temps_habilitat <= 0.0 and is_on_floor():
				temps_habilitat = especie.valor_habilitat / Criatures.mult_habilitat(nivell)
				_canviar_estat(Estat.BUSCANT)
				EfectesCriatura.arrels(get_parent(), global_position, 1.4)

## L'enemic que atacaria ara mateix (o null), segons el comportament
func _triar_enemic(jugador: Node3D) -> Node3D:
	var radi := 0.0
	match Criatures.comportament(uid):
		"pacific":
			return null
		"neutral":
			radi = 3.5     # només els que se t'acosten
		_:
			radi = 8.0
	var millor: Node3D = null
	var millor_d := radi
	var candidats := get_tree().get_nodes_in_group("enemics")
	# Les salvatges que t'ataquen també compten com a enemics
	for c in get_tree().get_nodes_in_group("criatures_salvatges"):
		if c.estat == Estat.PERSEGUINT:
			candidats.append(c)
	for e in candidats:
		if not is_instance_valid(e) or ("fugint" in e and e.fugint):
			continue
		var d := _pla(e.global_position - jugador.global_position).length()
		if d < millor_d:
			millor = e
			millor_d = d
	return millor

func _atacar(jugador: Node3D) -> Array:
	var e := objectiu_atac
	if not is_instance_valid(e) or not (e.is_in_group("enemics") or e.is_in_group("criatures_salvatges")) \
			or _pla(e.global_position - jugador.global_position).length() > 13.0 or (Criatures.comportament(uid) == "pacific" and not Tactica.activa):
		objectiu_atac = null
		_canviar_estat(Estat.SEGUINT)
		return [Vector3.ZERO, 1.0]
	var cap := _pla(e.global_position - global_position)
	mirall = _cap_a_la_camera(cap) < 0.0
	if especie.atac == EspecieCriatura.Atac.PROJECTIL:
		if cap.length() > especie.abast_atac * 0.8:
			return [cap.normalized(), 1.8]
		if temps_atac >= recarrega():
			temps_atac = 0.0
			if especial_pendent:
				_rafega(e)
			else:
				_disparar(e, false)
		return [Vector3.ZERO, 1.0]
	if cap.length() > 1.0:
		return [cap.normalized(), 2.4 if Tactica.activa else 2.0]
	if temps_atac >= recarrega():
		temps_atac = 0.0
		if especial_pendent:
			_mossegada_ferotge(e)
		else:
			_mossegar(e, false)
	return [Vector3.ZERO, 1.0]

# ─────────────── Corral i tasques

func _al_corral(delta: float) -> Array:
	temps_atac += delta
	if mode_corral == "corral":
		# Passeja per dins del tancat
		if estat == Estat.CORRAL and temps_estat > randf_range(2.5, 6.0):
			desti = corral.punt_a_dins()
			_canviar_estat(Estat.PASSEJANT)
		elif estat == Estat.PASSEJANT:
			var m := _cap_a(desti, 0.3)
			if m == Vector3.ZERO or temps_estat > 6.0:
				_canviar_estat(Estat.CORRAL)
			return [m * 0.6, 1.0]
		return [Vector3.ZERO, 1.0]
	# Tasques: va fins a l'arbre, la roca o l'herba i hi treballa
	if not is_instance_valid(lloc_treball) or not lloc_treball.disponible():
		lloc_treball = corral.lloc_per_tasca(mode_corral, global_position) if corral else null
		if lloc_treball == null:
			return [Vector3.ZERO, 1.0]
	var m := _cap_a(lloc_treball.global_position, 1.1)
	if m != Vector3.ZERO:
		return [m, 1.3]
	mirall = _cap_a_la_camera(_pla(lloc_treball.global_position - global_position)) < 0.0
	if temps_atac > 2.2:
		temps_atac = 0.0
		var t := create_tween()
		var cap := _pla(lloc_treball.global_position - global_position).normalized()
		t.tween_property(sprite, "position", offset_sprite + cap * 0.35, 0.07)
		t.tween_property(sprite, "position", offset_sprite, 0.15)
		lloc_treball._sacsejar()
		lloc_treball._estelles()
	return [Vector3.ZERO, 1.0]

## Ha produït alguna cosa: la mostra fent un bot
func mostrar_produccio(objecte: String):
	_saltet()
	var l := _label(80, Color.WHITE)
	l.text = CatalegObjectes.info(objecte).icona
	l.visible = true
	add_child(l)
	l.position = Vector3.UP * 0.8
	var t := l.create_tween()
	t.tween_property(l, "position", Vector3.UP * 1.6, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.3)
	t.tween_callback(l.queue_free)

# ─────────────── Pausa tàctica

## Una ordre de la pausa tàctica (s'executa de seguida, sense esperar la recàrrega)
func ordre_tactica(quina: String, objectiu: Node3D):
	especial_pendent = quina == "especial"
	match quina:
		"atac", "especial":
			objectiu_atac = objectiu
			temps_atac = 99.0
			_canviar_estat(Estat.ATACANT)
		"protegir":
			objectiu_atac = null
			_canviar_estat(Estat.SEGUINT)
			var jugador := _jugador()
			if jugador:
				EfectesCriatura.escut(jugador, especie.color.lightened(0.3))
			_mostrar_icona("🛡️")
			get_tree().create_timer(1.2).timeout.connect(_mostrar_icona.bind(""))
		_:
			_mostrar_icona("❗")
			get_tree().create_timer(0.8).timeout.connect(_mostrar_icona.bind(""))

## Atac especial a distància: una ràfega de tres projectils més forts
func _rafega(objectiu: Node3D):
	especial_pendent = false
	_mostrar_icona("✨")
	for i in 3:
		get_tree().create_timer(i * 0.15).timeout.connect(func():
			if is_instance_valid(objectiu) and is_inside_tree():
				var boca := global_position + Vector3.UP * offset_sprite.y * 1.2
				EfectesCriatura.projectil(get_parent(), boca, objectiu, especie.color_projectil.lightened(0.3), roundi(dany() * 1.5), false)
				_saltet())
	guanyar_xp(4)
	get_tree().create_timer(0.8).timeout.connect(_mostrar_icona.bind(""))

## Atac especial cos a cos: una mossegada molt forta que l'empeny
func _mossegada_ferotge(objectiu: Node3D):
	especial_pendent = false
	_mostrar_icona("✨")
	var cap := _pla(objectiu.global_position - global_position).normalized()
	var t := create_tween()
	t.tween_property(sprite, "scale", Vector3(1.3, 0.8, 1.0), 0.08)
	t.tween_property(sprite, "position", offset_sprite + cap * 0.7, 0.06)
	t.tween_property(sprite, "position", offset_sprite, 0.18)
	t.parallel().tween_property(sprite, "scale", Vector3.ONE, 0.18)
	EfectesCriatura.mossegada(get_parent(), objectiu.global_position, mirall)
	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(objectiu):
			EfectesCriatura.mossegada(get_parent(), objectiu.global_position + Vector3.UP * 0.2, not mirall))
	objectiu.prendre_dany(roundi(dany() * 2.5), global_position - cap * 2.0)
	guanyar_xp(4)
	get_tree().create_timer(0.8).timeout.connect(_mostrar_icona.bind(""))

func _disparar(objectiu: Node3D, contra_jugador: bool):
	_saltet()
	var boca := global_position + Vector3.UP * offset_sprite.y * 1.2
	EfectesCriatura.projectil(get_parent(), boca, objectiu, especie.color_projectil, dany(), contra_jugador)
	if not contra_jugador:
		guanyar_xp(2)

func _mossegar(objectiu: Node3D, contra_jugador: bool):
	# S'abalança cap a l'objectiu i torna
	var cap := _pla(objectiu.global_position - global_position).normalized()
	var t := create_tween()
	t.tween_property(sprite, "position", offset_sprite + cap * 0.45, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "position", offset_sprite, 0.15)
	EfectesCriatura.mossegada(get_parent(), objectiu.global_position, mirall)
	if contra_jugador:
		SalutJugador.prendre_dany(dany())
	else:
		objectiu.prendre_dany(dany(), global_position)
		guanyar_xp(2)

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
	if feina.is_in_group("cultius"):
		# Esquitxa suc fins al cultiu
		_saltet()
		EfectesCriatura.esquitx(get_parent(), global_position + Vector3.UP * 0.5, feina.global_position, especie.color.lightened(0.2))
		var cultiu := feina
		get_tree().create_timer(0.45).timeout.connect(func():
			if is_instance_valid(cultiu):
				cultiu.regar()
				Progressio.accio_feta.emit("regar", 1)
				guanyar_xp(3)
				TextFlotant.mostrar(get_parent(), cultiu.global_position + Vector3.UP * 0.8, "💧", Color(0.5, 0.8, 1.0)))
	_acabar_feina()

func _acabar_feina():
	if is_instance_valid(feina) and feina.has_meta("regant"):
		feina.remove_meta("regant")
	feina = null
	_canviar_estat(Estat.SEGUINT)

## Surt la troballa de terra i se la posa a la boca per portar-te-la
func _trobar_alguna_cosa():
	if especie.troballes.is_empty():
		_canviar_estat(Estat.SEGUINT)
		return
	portant = especie.troballes[randi() % especie.troballes.size()]
	icona_portant.text = CatalegObjectes.info(portant).icona
	icona_portant.visible = true
	icona_portant.scale = Vector3.ONE * 0.2
	var t := icona_portant.create_tween()
	t.tween_property(icona_portant, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_saltet()
	_mostrar_icona("❗")
	get_tree().create_timer(0.7).timeout.connect(_mostrar_icona.bind(""))
	_canviar_estat(Estat.PORTANT)

## Arriba al teu costat i te la dona
func _lliurar():
	var objecte := portant
	portant = ""
	_canviar_estat(Estat.SEGUINT)
	var jugador := _jugador()
	# L'objecte vola de la boca fins al jugador
	var vol := icona_portant.duplicate() as Label3D
	get_parent().add_child(vol)
	vol.global_position = icona_portant.global_position
	icona_portant.visible = false
	var t := vol.create_tween()
	t.tween_property(vol, "global_position", jugador.global_position + Vector3.UP * 1.2, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(vol, "scale", Vector3.ONE * 0.5, 0.3)
	t.tween_callback(vol.queue_free)
	var info := CatalegObjectes.info(objecte)
	if Inventari.afegir(objecte, 1):
		TextFlotant.mostrar(get_parent(), jugador.global_position + Vector3.UP * 1.6, "+1 %s" % info.icona, Color(1.0, 0.9, 0.6))
		EventBus.avis.emit("%s t'ha portat %s" % [Criatures.dades(uid).get("nom", especie.nom), info.nom.to_lower()])
		guanyar_xp(4)

## El cranc: quan reps mal, t'envolta un moment una closca protectora
func _on_vida_jugador(actual, _maxima):
	if not is_inside_tree() or not domesticada:
		return
	if actual < get_meta("vida_abans", actual):
		var jugador := _jugador()
		if jugador:
			EfectesCriatura.escut(jugador, especie.color.lightened(0.3))
	set_meta("vida_abans", actual)

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
	if not domesticada or not mode_corral.is_empty():
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
	# La primera vegada que te la mires de prop, entra al bestiari
	if not domesticada and jugador and not Criatures.vista(especie.id) and _pla(jugador.global_position - global_position).length() < 9.0:
		Criatures.veure(especie.id)
	etiqueta.visible = estat != Estat.DOMESTICANT and jugador != null and _pla(jugador.global_position - global_position).length() < 4.0 and not icona.visible
