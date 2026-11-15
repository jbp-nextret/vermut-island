extends CharacterBody3D

@export var nom_enemic: String = "Zombi"
@export var vida_maxima: int = 20
@export var dany: int = 10
@export var velocitat: float = 2.0
@export var rango_deteccio: float = 15.0   # a quina distància "veu" el jugador i el prefereix
@export var rango_atac: float = 1.5
@export var cooldown_atac: float = 1.5
@export var textura_enemic: Texture2D
@export var es_volador: bool = false  # Marca si és volador o terrestre
@export var altura_vol: float = 2.0   # Altura a la que vola mentre es desplaça

const ALCADA_ATAC_VOLADOR := 0.6      # baixa en picat fins aquí per atacar

# Voladors (ratpenats): s'acosten voleiant, fan cercles al voltant de l'objectiu, es
# llancen en picat, ataquen i tornen a pujar (en lloc d'anar en línia recta i quedar-se quiets)
enum Vol { APROPANT, VOLTANT, PICAT, RETIRADA }
const ACCELERACIO_VOL := 7.0
const RADI_VOLTA := 3.2
const SEPARACIO_VOLADORS := 1.4
var vol := Vol.APROPANT
var temps_vol := 0.0
var sentit_volta := 1.0
var fase := 0.0
var velocitat_vol := Vector3.ZERO
var mirall := 1.0

var vida_actual = 0
var objectiu: Node3D = null
var temps_darrer_atac: float = 0.0
var velocitat_moviment = Vector3.ZERO
var gravity = 20.0
var escala_original = Vector3.ONE
var material_original: StandardMaterial3D = null
var material_dany: StandardMaterial3D = null
var temps_feedback: float = 0.0
var jugador: Node3D = null
var barra_vida: BarraVida3D

# Ortigues
var factor_velocitat := 1.0
var alentit_fins := 0.0

# Cops rebuts: empenta i una aturada curta
var empenta := Vector3.ZERO
var atordit_fins := 0.0

# Alba: fuig i desapareix
var fugint := false
var direccio_fuga := Vector3.ZERO

@onready var sprite = $Sprite

# Dibuix suau entre tics de física (vegeu personatge.gd)
var pos_fisica_anterior := Vector3.ZERO
var offset_sprite := Vector3.ZERO

# Recursos de les partícules de mort, compartits per tots els enemics
static var _particules_mat: ParticleProcessMaterial
static var _particules_quad: QuadMesh

func _ready():
	offset_sprite = sprite.position
	pos_fisica_anterior = global_position
	vida_actual = vida_maxima
	add_to_group("enemics")
	add_to_group("enemics_voladors" if es_volador else "enemics_terrestres")
	escala_original = scale

	material_original = StandardMaterial3D.new()
	material_original.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material_original.alpha_scissor_threshold = 0.5
	material_original.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material_original.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_original.cull_mode = BaseMaterial3D.CULL_DISABLED
	if textura_enemic:
		material_original.albedo_texture = textura_enemic
	else:
		material_original.albedo_color = Color(0.8, 0.2, 0.2)
	sprite.set_surface_override_material(0, material_original)

	barra_vida = BarraVida3D.crear(self, 0.9)
	jugador = get_tree().get_first_node_in_group("player")
	if jugador == null:
		jugador = get_parent().get_node_or_null("Personatge")
	fase = randf() * TAU
	sentit_volta = 1.0 if randf() < 0.5 else -1.0
	_apareixer()

func _process(_delta):
	if pos_fisica_anterior.distance_to(global_position) > 2.0:
		pos_fisica_anterior = global_position   # acaba d'aparèixer: sense interpolar
	var fraccio := Engine.get_physics_interpolation_fraction()
	sprite.position = offset_sprite + (pos_fisica_anterior.lerp(global_position, fraccio) - global_position)
	if es_volador and not fugint:
		# Aleteig: s'aixafa i s'estira, i puja i baixa una mica
		var t := Time.get_ticks_msec() / 1000.0 * (14.0 if vol == Vol.PICAT else 9.0) + fase
		sprite.scale = Vector3((1.0 + 0.08 * sin(t)) * mirall, 1.0 - 0.14 * sin(t), 1.0)
		sprite.position.y += 0.08 * sin(t * 0.5)

func _physics_process(delta):
	pos_fisica_anterior = global_position
	if temps_feedback > 0:
		temps_feedback -= delta
		if temps_feedback <= 0:
			restaurar_aparenca()

	if fugint:
		global_position += direccio_fuga * velocitat * 2.0 * delta
		return

	var ara := Time.get_ticks_msec() / 1000.0
	var multiplicador := factor_velocitat if ara < alentit_fins else 1.0

	# Empenta del cop (es va apagant) i atordiment: mentre dura, no ataca
	empenta = empenta.move_toward(Vector3.ZERO, 25.0 * delta)
	if ara < atordit_fins:
		if es_volador:
			global_position += empenta * delta
		else:
			velocity = Vector3(empenta.x, velocitat_moviment.y - gravity * delta, empenta.z)
			move_and_slide()
		return

	temps_darrer_atac += delta
	objectiu = obtenir_objectiu()
	if es_volador:
		_volar(delta, multiplicador)
		return
	velocitat_moviment.x = 0
	velocitat_moviment.z = 0

	if objectiu:
		var desti := objectiu.global_position
		var horitzontal := Vector2(desti.x - global_position.x, desti.z - global_position.z)

		if es_volador:
			# Vola alt i, quan és a prop, baixa en picat
			desti.y += ALCADA_ATAC_VOLADOR if horitzontal.length() < 2.5 else altura_vol
		var distancia := global_position.distance_to(desti) if es_volador else horitzontal.length()

		if distancia <= rango_atac:
			if es_volador:
				velocitat_moviment = Vector3.ZERO   # es queda suspès mentre ataca
			if temps_darrer_atac >= cooldown_atac:
				atacar_objectiu()
				temps_darrer_atac = 0.0
		else:
			var direccio := (desti - global_position).normalized()
			if es_volador:
				velocitat_moviment = direccio * velocitat * multiplicador
			else:
				velocitat_moviment.x = direccio.x * velocitat * multiplicador
				velocitat_moviment.z = direccio.z * velocitat * multiplicador

	if es_volador:
		global_position += velocitat_moviment * delta
	else:
		if not is_on_floor():
			velocitat_moviment.y -= gravity * delta
		else:
			velocitat_moviment.y = 0
		velocity = velocitat_moviment
		move_and_slide()

## El vol dels ratpenats (vegeu Vol)
func _volar(delta: float, multiplicador: float):
	temps_vol += delta
	var desitjada := Vector3.ZERO
	var rapidesa := velocitat * multiplicador
	if objectiu:
		var centre := objectiu.global_position
		var pla := Vector3(global_position.x - centre.x, 0.0, global_position.z - centre.z)
		var dist := pla.length()
		var radi := pla / maxf(dist, 0.01)
		match vol:
			Vol.APROPANT:
				# Cap a l'objectiu, alt i fent eses
				var cap := Vector3(centre.x, centre.y + altura_vol, centre.z) - global_position
				var costat := Vector3(-cap.z, 0.0, cap.x).normalized() * sin(temps_vol * 2.3 + fase) * 0.6
				desitjada = (cap.normalized() + costat).normalized() * rapidesa
				if dist < RADI_VOLTA * 1.3:
					_canviar_vol(Vol.VOLTANT)
			Vol.VOLTANT:
				# Fa voltes al seu voltant una estona, i després es llança
				var tangent := Vector3(-radi.z, 0.0, radi.x) * sentit_volta
				var correccio := -radi * (dist - RADI_VOLTA) * 0.8
				var alcada := (centre.y + altura_vol * 0.7 + 0.4 * sin(temps_vol * 3.0 + fase)) - global_position.y
				desitjada = (tangent * rapidesa) + correccio + Vector3.UP * alcada * 2.0
				if temps_vol > 0.9 + fmod(fase, 1.2) and temps_darrer_atac >= cooldown_atac:
					_canviar_vol(Vol.PICAT)
				elif dist > RADI_VOLTA * 2.5:
					_canviar_vol(Vol.APROPANT)
			Vol.PICAT:
				var punt := centre + Vector3.UP * ALCADA_ATAC_VOLADOR
				desitjada = (punt - global_position).normalized() * rapidesa * 2.4
				if global_position.distance_to(punt) <= rango_atac:
					if temps_darrer_atac >= cooldown_atac:
						atacar_objectiu()
						temps_darrer_atac = 0.0
					_canviar_vol(Vol.RETIRADA)
				elif temps_vol > 2.0:
					_canviar_vol(Vol.RETIRADA)
			Vol.RETIRADA:
				# Torna a pujar, allunyant-se una mica
				desitjada = (radi * 1.2 + Vector3.UP * 1.3).normalized() * rapidesa * 1.6
				if temps_vol > 0.7:
					sentit_volta = -sentit_volta if randf() < 0.4 else sentit_volta
					_canviar_vol(Vol.VOLTANT)
	else:
		# Sense res a atacar: es queda voleiant
		desitjada = Vector3(sin(temps_vol + fase), cos(temps_vol * 1.7) * 0.3, cos(temps_vol * 0.8 + fase)) * rapidesa * 0.4
	# Que no s'amunteguin
	for altre in get_tree().get_nodes_in_group("enemics_voladors"):
		if altre == self:
			continue
		var lluny: Vector3 = global_position - altre.global_position
		var d := lluny.length()
		if d < SEPARACIO_VOLADORS and d > 0.01:
			desitjada += lluny / d * (SEPARACIO_VOLADORS - d) * 3.0
	# Gira de mica en mica (inèrcia): res de canvis de direcció de cop
	velocitat_vol = velocitat_vol.lerp(desitjada, 1.0 - exp(-ACCELERACIO_VOL * delta))
	global_position += velocitat_vol * delta
	# Mai per sota de terra
	if objectiu and global_position.y < objectiu.global_position.y + 0.3:
		global_position.y = objectiu.global_position.y + 0.3
	# Mira cap on va (vist des de la càmera)
	var camera := get_viewport().get_camera_3d()
	if camera:
		var dreta := velocitat_vol.dot(camera.global_basis.x)
		if absf(dreta) > 0.4:
			mirall = -1.0 if dreta < 0.0 else 1.0

func _canviar_vol(nou: Vol):
	vol = nou
	temps_vol = 0.0

## En sortir: creix des de zero enmig d'un núvol fosc (no apareix de cop)
func _apareixer():
	var final := scale
	scale = final * 0.05
	var t := create_tween()
	t.tween_property(self, "scale", final, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 18
	p.lifetime = 0.7
	p.explosiveness = 0.9
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.6, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	var malla := SphereMesh.new()
	malla.radius = 0.12
	malla.height = 0.24
	malla.radial_segments = 6
	malla.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.22, 0.12, 0.3, 0.75)
	malla.material = m
	p.mesh = malla
	var corba := Curve.new()
	corba.add_point(Vector2(0, 1))
	corba.add_point(Vector2(1, 0))
	p.scale_amount_curve = corba
	get_parent().add_child.call_deferred(p)
	p.ready.connect(func():
		p.global_position = global_position
		p.emitting = true, CONNECT_ONE_SHOT)
	p.finished.connect(p.queue_free)

## Va a pels cultius (l'esquer atrau més), però si el jugador és a prop i més a
## l'abast, el prefereix. Ja no es queda quiet si el cultiu més proper és lluny.
func obtenir_objectiu() -> Node3D:
	var millor: Node3D = null
	var millor_puntuacio := INF
	for cultiu in get_tree().get_nodes_in_group("cultius"):
		if not is_instance_valid(cultiu):
			continue
		var puntuacio: float = global_position.distance_to(cultiu.global_position)
		if cultiu.has_method("atraccio") and puntuacio <= cultiu.radi_influencia * 1.5:
			puntuacio /= cultiu.atraccio()
		if puntuacio < millor_puntuacio:
			millor_puntuacio = puntuacio
			millor = cultiu

	if is_instance_valid(jugador):
		var d_jugador := global_position.distance_to(jugador.global_position)
		if millor == null or (d_jugador <= rango_deteccio and d_jugador < millor_puntuacio):
			return jugador
	return millor

func atacar_objectiu():
	if objectiu == null:
		return
	if objectiu.is_in_group("cultius"):
		objectiu.prendre_dany(dany)
	else:
		SalutJugador.prendre_dany(dany)

## Cridat per les ortigues: `factor` de la velocitat durant `segons`
func alentir(factor: float, segons: float) -> void:
	factor_velocitat = factor
	alentit_fins = Time.get_ticks_msec() / 1000.0 + segons

func prendre_dany(quantitat: int, origen: Vector3 = Vector3.INF):
	if fugint or vida_actual <= 0:
		return
	vida_actual -= quantitat
	if SettingsManager.valor("numeros_dany"):
		TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 0.8, str(quantitat), Color(1, 0.95, 0.6) if quantitat >= 30 else Color.WHITE, true)
	if origen.is_finite():
		var lluny := global_position - origen
		lluny.y = 0
		empenta = lluny.normalized() * (7.0 if quantitat >= 30 else 4.5)
		atordit_fins = Time.get_ticks_msec() / 1000.0 + 0.2
	barra_vida.mostrar(vida_actual, vida_maxima)
	mostrar_feedback_dany()
	if vida_actual <= 0:
		morir()

func mostrar_feedback_dany():
	if material_dany == null:
		material_dany = material_original.duplicate()
		material_dany.albedo_color = Color(1, 0.3, 0.3)
	sprite.set_surface_override_material(0, material_dany)
	scale = escala_original * 1.2
	temps_feedback = 0.2

func restaurar_aparenca():
	sprite.set_surface_override_material(0, material_original)
	scale = escala_original

func morir():
	Progressio.guanyar_xp("enemic" if vida_maxima >= 40 else "enemic_petit")
	# Derrotat en pausa tàctica: botí extra
	if Tactica.activa:
		var monedes := 5 if vida_maxima < 40 else 12
		Inventari.afegir_diners(monedes)
		TextFlotant.mostrar(get_parent(), global_position + Vector3.UP * 1.4, "+%d 🪙" % monedes, Color(1.0, 0.85, 0.4))
	GestorOnades.enemic_mort(self)
	mostrar_particules_mort()
	queue_free()

## A l'alba: s'allunya i s'esvaeix (no compta com a mort)
func fugir() -> void:
	if fugint:
		return
	fugint = true
	remove_from_group("enemics")
	var lluny := global_position - (jugador.global_position if is_instance_valid(jugador) else Vector3.ZERO)
	lluny.y = 0
	direccio_fuga = (lluny.normalized() if lluny.length() > 0.1 else Vector3.FORWARD) + Vector3.UP * 0.5
	barra_vida.visible = false
	var t := create_tween()
	t.tween_property(self, "scale", Vector3.ONE * 0.01, 1.5)   # 0 exacte no li agrada al motor de física
	t.tween_callback(queue_free)

func mostrar_particules_mort():
	var particules = GPUParticles3D.new()
	get_parent().add_child(particules)
	particules.global_position = global_position

	if _particules_mat == null:
		_particules_mat = ParticleProcessMaterial.new()
		_particules_mat.direction = Vector3(0, 1, 0)
		_particules_mat.spread = 180.0
		_particules_mat.initial_velocity_min = 2.0
		_particules_mat.initial_velocity_max = 5.0
		_particules_mat.gravity = Vector3(0, -9.8, 0)
		_particules_mat.scale_min = 0.1
		_particules_mat.scale_max = 0.3
		_particules_mat.color = Color(1.0, 1.0, 0.059, 0.902)
		_particules_quad = QuadMesh.new()
		_particules_quad.size = Vector2(0.30, 0.30)
		var textura_mat := StandardMaterial3D.new()
		textura_mat.albedo_texture = preload("res://Sprites/Misc/particle_2.PNG")
		textura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		textura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		textura_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		textura_mat.vertex_color_use_as_albedo = true
		_particules_quad.material = textura_mat
	particules.process_material = _particules_mat
	particules.draw_pass_1 = _particules_quad

	particules.one_shot = true
	particules.explosiveness = 0.9
	particules.amount = 30
	particules.lifetime = 1.5
	particules.emitting = true
	# Les partícules s'esborren soles quan acaben (abans hi havia un await
	# que continuava després que l'enemic ja s'hagués esborrat)
	particules.finished.connect(particules.queue_free)
