extends Node3D
class_name CombatMagic
## Atacs a curta distància del jugador amb una espasa espectral que apareix i s'esvaeix.
## No depèn de les animacions del cos: l'espasa és un efecte independent.
##  - tall(): l'espasa escombra davant del jugador (cap al ratolí). Combo de 3:
##    el 2n en sentit contrari i el 3r és un remolí de 360° que toca tot el voltant.
##  - estocada(): dash cap al ratolí amb l'espasa estesa; fa mal a tot el que travessa.

signal cop_encertat(enemic: Node3D, dany: int)

const TALL := {"dany": 20, "abast": 2.3, "mig_angle": 75.0, "recarrega": 0.32}
const REMOLI := {"multiplicador": 1.6, "radi": 2.6}
const ESTOCADA := {"dany": 35, "radi": 1.4, "recarrega": 1.0, "durada": 0.18}
const FINESTRA_COMBO := 0.7
const ALCADA_MAXIMA := 2.4
const ALCADA_EFECTE := 0.7

const TEXTURA_ESPASA := preload("res://Sprites/sword.png")
const TEXTURA_REMOLI := preload("res://Sprites/Misc/magic-1.png")
const PIXEL_ESPASA := 0.055
const COLOR_ESPASA := Color(0.75, 0.92, 1.0)
const COLORS_TALL := [Color(0.55, 0.85, 1.0), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.5)]

var jugador: Node3D
var combo := 0
var temps_des_del_tall := 99.0
var temps_des_de_estocada := 99.0
var temps_estocada := 0.0
var direccio_estocada := Vector3.ZERO
var tocats_estocada := {}

static var _materials := {}
static var _textura_tall: ImageTexture

func _ready():
	jugador = get_parent()

func _physics_process(delta):
	temps_des_del_tall += delta
	temps_des_de_estocada += delta
	if temps_estocada > 0.0:
		temps_estocada -= delta
		# Tot el que el jugador travessa durant el dash rep un cop (un sol cop per enemic)
		for enemic in _enemics_propers(ESTOCADA.radi):
			if not tocats_estocada.has(enemic):
				tocats_estocada[enemic] = true
				_colpejar(enemic, ESTOCADA.dany)

func progres_tall() -> float:
	return clampf(temps_des_del_tall / TALL.recarrega, 0.0, 1.0)

func progres_estocada() -> float:
	return clampf(temps_des_de_estocada / ESTOCADA.recarrega, 0.0, 1.0)

# ─────────────── Tall i remolí

## Retorna false si encara s'està recarregant
func tall(direccio: Vector3) -> bool:
	if temps_des_del_tall < TALL.recarrega:
		return false
	combo = combo + 1 if temps_des_del_tall < FINESTRA_COMBO and combo < 3 else 1
	temps_des_del_tall = 0.0

	if combo == 3:
		var dany := int(TALL.dany * REMOLI.multiplicador)
		_escombrada(direccio, 1.0, 360.0, 0.26, REMOLI.radi / TALL.abast, COLORS_TALL[2])
		_efecte_cercle(REMOLI.radi, COLORS_TALL[2])
		for enemic in _enemics_propers(REMOLI.radi):
			_colpejar(enemic, dany)
	else:
		var sentit := 1.0 if combo == 1 else -1.0
		_escombrada(direccio, sentit, TALL.mig_angle * 2.0, 0.11, 1.0, COLORS_TALL[combo - 1])
		_efecte_mitja_lluna(direccio, TALL.abast, COLORS_TALL[combo - 1])
		_colpejar_con(direccio, TALL.abast, TALL.mig_angle, TALL.dany)
	return true

## L'espasa apareix, gira `obertura` graus al voltant del jugador i s'esvaeix
func _escombrada(direccio: Vector3, sentit: float, obertura: float, durada: float, mida: float, color: Color):
	var pivot := Node3D.new()
	jugador.get_parent().add_child(pivot)
	pivot.global_position = jugador.global_position + Vector3.UP * ALCADA_EFECTE
	var base := atan2(direccio.x, direccio.z)
	var meitat := deg_to_rad(obertura) / 2.0
	pivot.rotation.y = base - sentit * meitat
	var espasa := _crear_espasa(color)
	pivot.add_child(espasa)

	pivot.scale = Vector3.ONE * mida * 0.7
	var t := pivot.create_tween()
	t.tween_property(pivot, "scale", Vector3.ONE * mida, 0.05)
	t.parallel().tween_property(pivot, "rotation:y", base + sentit * meitat, durada).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(espasa, "modulate:a", 0.0, 0.12)
	t.parallel().tween_property(espasa.get_child(0), "modulate:a", 0.0, 0.12)
	t.tween_callback(pivot.queue_free)

# ─────────────── Estocada (dash)

## Només prepara el mal i l'efecte: el moviment del dash el fa el personatge
func estocada(direccio: Vector3) -> bool:
	if temps_des_de_estocada < ESTOCADA.recarrega:
		return false
	temps_des_de_estocada = 0.0
	temps_estocada = ESTOCADA.durada
	direccio_estocada = direccio
	tocats_estocada.clear()

	# Espasa estesa al davant, que viatja amb el jugador
	var pivot := Node3D.new()
	jugador.add_child(pivot)
	pivot.position = Vector3.UP * ALCADA_EFECTE
	pivot.rotation.y = atan2(direccio.x, direccio.z)
	var espasa := _crear_espasa(COLORS_TALL[0])
	pivot.add_child(espasa)
	var final_z := espasa.position.z
	espasa.position.z = final_z - 0.5
	var t := pivot.create_tween()
	t.tween_property(espasa, "position:z", final_z + 0.2, 0.07).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_interval(ESTOCADA.durada)
	t.tween_property(espasa, "modulate:a", 0.0, 0.12)
	t.parallel().tween_property(espasa.get_child(0), "modulate:a", 0.0, 0.12)
	t.tween_callback(pivot.queue_free)
	return true

# ─────────────── Efectes

## Espasa espectral estirada a terra, amb la punta cap endavant (+Z del pare) i una aura
func _crear_espasa(color: Color) -> Sprite3D:
	var llarg := TEXTURA_ESPASA.get_height() * PIXEL_ESPASA
	var espasa := _sprite(TEXTURA_ESPASA, PIXEL_ESPASA, Color(COLOR_ESPASA, 0.95), 2)
	espasa.position = Vector3(0, 0, 0.25 + llarg / 2.0)
	var aura := _sprite(TEXTURA_ESPASA, PIXEL_ESPASA * 1.35, Color(color, 0.45), 1)
	aura.rotation = Vector3.ZERO   # ja hereta la rotació de l'espasa
	espasa.add_child(aura)
	return espasa

func _efecte_mitja_lluna(direccio: Vector3, abast: float, color: Color):
	var pivot := Node3D.new()
	jugador.get_parent().add_child(pivot)
	pivot.global_position = jugador.global_position + Vector3.UP * (ALCADA_EFECTE - 0.05)
	pivot.rotation.y = atan2(direccio.x, direccio.z)
	var lluna := _sprite(textura_tall(), abast * 1.1 / 32.0, Color(color, 0.8), 0)
	lluna.position = Vector3(0, 0, abast * 0.3)
	pivot.add_child(lluna)
	var t := pivot.create_tween()
	t.tween_interval(0.05)
	t.tween_property(lluna, "modulate:a", 0.0, 0.22)
	t.tween_callback(pivot.queue_free)

func _efecte_cercle(radi: float, color: Color):
	var cercle := _sprite(TEXTURA_REMOLI, 0.01, Color(color, 0.9), 0)
	jugador.get_parent().add_child(cercle)
	cercle.global_position = terra_sota(jugador, jugador.global_position) + Vector3.UP * 0.02
	var mida_final: float = radi * 1.0 / (TEXTURA_REMOLI.get_width() * cercle.pixel_size)
	cercle.scale = Vector3.ONE * mida_final * 0.1
	var t := cercle.create_tween().set_parallel(true)
	t.tween_property(cercle, "scale", Vector3.ONE * mida_final, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(cercle, "rotation_degrees:y", 90.0, 0.45)
	t.tween_property(cercle, "modulate:a", 0.0, 0.3).set_delay(0.15)
	t.chain().tween_callback(cercle.queue_free)

## Sprite pla a terra (la part de dalt de la textura mira cap endavant)
func _sprite(textura: Texture2D, pixel_size: float, color: Color, prioritat: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = textura
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.pixel_size = pixel_size
	s.material_override = _material_efecte(textura)
	s.modulate = color
	s.render_priority = prioritat
	s.rotation_degrees.x = 90
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s

## Mitja lluna gruixuda en pixel art, amb la panxa cap amunt (cap on va el tall)
static func textura_tall() -> ImageTexture:
	if _textura_tall:
		return _textura_tall
	const N := 32
	var imatge := Image.create(N, N, false, Image.FORMAT_RGBA8)
	var exterior := Vector2(16, 20)
	var interior := Vector2(16, 26)
	for y in N:
		for x in N:
			var p := Vector2(x + 0.5, y + 0.5)
			var d_ext := p.distance_to(exterior)
			if d_ext <= 14.0 and p.distance_to(interior) > 12.5 and p.y < 24.0:
				imatge.set_pixel(x, y, Color(1, 1, 1, 1.0 if d_ext > 12.0 else 0.65))
	_textura_tall = ImageTexture.create_from_image(imatge)
	return _textura_tall

static func _material_efecte(textura: Texture2D) -> StandardMaterial3D:
	if not _materials.has(textura):
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = textura
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		_materials[textura] = mat
	return _materials[textura]

# ─────────────── Impactes

func _colpejar_con(direccio: Vector3, abast: float, mig_angle: float, dany: int):
	for enemic in _enemics_propers(abast):
		var pla := _pla(enemic.global_position - jugador.global_position)
		if pla.length() > 0.4 and rad_to_deg(direccio.angle_to(pla.normalized())) > mig_angle:
			continue
		_colpejar(enemic, dany)

func _colpejar(enemic: Node3D, dany: int):
	# L'habilitat "Fil espectral" augmenta el mal de l'espasa
	dany = roundi(dany * (1.0 + Progressio.valor("dany_espasa")))
	enemic.prendre_dany(dany, jugador.global_position)
	cop_encertat.emit(enemic, dany)

func _enemics_propers(radi: float) -> Array:
	var resultat := []
	for enemic in get_tree().get_nodes_in_group("enemics"):
		if not is_instance_valid(enemic):
			continue
		var cap: Vector3 = enemic.global_position - jugador.global_position
		if absf(cap.y) <= ALCADA_MAXIMA and _pla(cap).length() <= radi:
			resultat.append(enemic)
	return resultat

## El punt de terra just a sota de `punt` (el mateix punt si no en troba)
static func terra_sota(des_de: Node3D, punt: Vector3) -> Vector3:
	var consulta := PhysicsRayQueryParameters3D.create(punt + Vector3.UP * 0.5, punt + Vector3.DOWN * 4.0)
	if des_de is CollisionObject3D:
		consulta.exclude = [des_de.get_rid()]
	var resultat := des_de.get_world_3d().direct_space_state.intersect_ray(consulta)
	return resultat.position if not resultat.is_empty() else punt

static func _pla(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)
