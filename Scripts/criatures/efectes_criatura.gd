extends Node3D
class_name EfectesCriatura
## Efectes visuals de les criatures (provisionals, fets amb codi):
##   - projectil(): una boleta que vola cap a l'objectiu (llavors, grans de raïm...)
##   - mossegada(): una mitja lluna blanca que s'obre i es tanca sobre l'objectiu
##   - arrels(): terra que es remou amb unes arrels que surten (l'olivetó buscant)
##   - esquitx(): gotes d'un color que fan un arc d'un punt a un altre (regar)
##   - escut(): una bombolla que apareix un moment al voltant d'algú (el cranc)
## També fa de projectil (és un Node3D que es mou sol).

var velocitat := Vector3.ZERO
var objectiu: Node3D = null
var dany := 0
var contra_jugador := false
var vida := 1.4
var origen := Vector3.ZERO

static var _textura_mossegada: ImageTexture

# ─────────────── Projectil

static func projectil(pare: Node, des_de: Vector3, p_objectiu: Node3D, color: Color, p_dany: int, p_contra_jugador := false) -> EfectesCriatura:
	var p := EfectesCriatura.new()
	p.objectiu = p_objectiu
	p.dany = p_dany
	p.contra_jugador = p_contra_jugador
	p.origen = des_de
	var bola := MeshInstance3D.new()
	var esfera := SphereMesh.new()
	esfera.radius = 0.1
	esfera.height = 0.2
	esfera.radial_segments = 8
	esfera.rings = 4
	bola.mesh = esfera
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	bola.material_override = mat
	bola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(bola)
	# Una cueta de partícules
	var cua := CPUParticles3D.new()
	cua.amount = 12
	cua.lifetime = 0.3
	cua.local_coords = false
	cua.gravity = Vector3.ZERO
	cua.initial_velocity_min = 0.0
	cua.initial_velocity_max = 0.2
	cua.scale_amount_min = 0.5
	cua.scale_amount_max = 1.0
	cua.mesh = _quad(color, 0.08)
	p.add_child(cua)
	pare.add_child(p)
	p.global_position = des_de
	var cap := (p_objectiu.global_position + Vector3.UP * 0.5) - des_de
	p.velocitat = cap.normalized() * 9.0
	return p

func _physics_process(delta):
	if velocitat == Vector3.ZERO:
		return
	vida -= delta
	# Segueix una mica l'objectiu (no tant que sigui impossible d'esquivar)
	if is_instance_valid(objectiu):
		var cap := (objectiu.global_position + Vector3.UP * 0.5) - global_position
		velocitat = velocitat.lerp(cap.normalized() * 9.0, minf(1.0, delta * 3.0))
		if cap.length() < 0.6:
			_impacte()
			return
	global_position += velocitat * delta
	if vida <= 0.0:
		queue_free()

func _impacte():
	if contra_jugador:
		SalutJugador.prendre_dany(dany)
	elif objectiu.has_method("prendre_dany"):
		objectiu.prendre_dany(dany, origen)
	var esclat := CPUParticles3D.new()
	esclat.one_shot = true
	esclat.emitting = true
	esclat.amount = 10
	esclat.lifetime = 0.35
	esclat.explosiveness = 1.0
	esclat.spread = 180.0
	esclat.initial_velocity_min = 1.0
	esclat.initial_velocity_max = 2.5
	esclat.gravity = Vector3(0, -6, 0)
	var bola := get_child(0) as MeshInstance3D
	esclat.mesh = _quad((bola.material_override as StandardMaterial3D).albedo_color, 0.07)
	get_parent().add_child(esclat)
	esclat.global_position = global_position
	esclat.get_tree().create_timer(0.8).timeout.connect(esclat.queue_free)
	queue_free()

# ─────────────── Mossegada

static func mossegada(pare: Node, pos: Vector3, mirall: bool):
	var s := Sprite3D.new()
	s.texture = _mossegada_textura()
	s.pixel_size = 0.03
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.flip_h = mirall
	pare.add_child(s)
	s.global_position = pos + Vector3.UP * 0.5
	s.scale = Vector3(0.6, 1.4, 1)
	var t := s.create_tween()
	t.tween_property(s, "scale", Vector3(1.2, 0.5, 1), 0.08)
	t.tween_property(s, "scale", Vector3(1.3, 0.2, 1), 0.06)
	t.parallel().tween_property(s, "modulate:a", 0.0, 0.12)
	t.tween_callback(s.queue_free)

## Dues fileres de dents blanques (provisional)
static func _mossegada_textura() -> ImageTexture:
	if _textura_mossegada == null:
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		for x in 24:
			var ona := 2 if x % 6 < 3 else 0
			for y in range(3 + ona, 7):
				img.set_pixel(x, y, Color.WHITE)
			for y in range(17, 21 - ona):
				img.set_pixel(x, y, Color.WHITE)
		_textura_mossegada = ImageTexture.create_from_image(img)
	return _textura_mossegada

# ─────────────── Arrels (buscar)

static func arrels(pare: Node, pos: Vector3, durada: float):
	var terra := CPUParticles3D.new()
	terra.amount = 24
	terra.lifetime = 0.6
	terra.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	terra.emission_sphere_radius = 0.3
	terra.direction = Vector3.UP
	terra.spread = 50.0
	terra.initial_velocity_min = 1.0
	terra.initial_velocity_max = 2.2
	terra.gravity = Vector3(0, -9, 0)
	terra.mesh = _quad(Color(0.42, 0.29, 0.18), 0.08)
	pare.add_child(terra)
	terra.global_position = pos
	# Unes arrels que surten de terra, es retorcen i tornen a entrar
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.36, 0.2)
	for i in 4:
		var arrel := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.01
		c.bottom_radius = 0.035
		c.height = 0.45
		c.radial_segments = 5
		arrel.mesh = c
		arrel.material_override = mat
		pare.add_child(arrel)
		var angle := TAU * i / 4.0 + randf() * 0.5
		arrel.global_position = pos + Vector3(cos(angle), 0, sin(angle)) * 0.35
		arrel.rotation = Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
		arrel.scale = Vector3(1, 0.01, 1)
		var t := arrel.create_tween()
		t.tween_interval(i * 0.12)
		t.tween_property(arrel, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(arrel, "rotation:z", arrel.rotation.z + 0.5, durada * 0.3)
		t.tween_property(arrel, "rotation:z", arrel.rotation.z - 0.3, durada * 0.3)
		t.tween_property(arrel, "scale", Vector3(1, 0.01, 1), 0.2)
		t.tween_callback(arrel.queue_free)
	terra.get_tree().create_timer(durada).timeout.connect(func(): terra.emitting = false)
	terra.get_tree().create_timer(durada + 1.0).timeout.connect(terra.queue_free)

# ─────────────── Esquitx (regar)

static func esquitx(pare: Node, de: Vector3, a: Vector3, color: Color):
	for i in 7:
		var gota := MeshInstance3D.new()
		var e := SphereMesh.new()
		e.radius = 0.05
		e.height = 0.1
		e.radial_segments = 6
		e.rings = 3
		gota.mesh = e
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		gota.material_override = mat
		pare.add_child(gota)
		gota.global_position = de
		var final := a + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
		var t := gota.create_tween()
		t.tween_interval(i * 0.05)
		t.tween_method(func(f: float):
			gota.global_position = de.lerp(final, f) + Vector3.UP * 1.2 * 4.0 * f * (1.0 - f), 0.0, 1.0, 0.45)
		t.tween_callback(gota.queue_free)

# ─────────────── Escut (defensa)

static func escut(pare: Node3D, color: Color):
	var b := MeshInstance3D.new()
	var e := SphereMesh.new()
	e.radius = 1.0
	e.height = 2.0
	b.mesh = e
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(color, 0.25)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	b.material_override = mat
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pare.add_child(b)
	b.position = Vector3.UP * 0.9
	b.scale = Vector3.ONE * 0.6
	var t := b.create_tween()
	t.tween_property(b, "scale", Vector3.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	t.tween_callback(b.queue_free)

static func _quad(color: Color, mida: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(mida, mida)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = color
	q.material = mat
	return q
