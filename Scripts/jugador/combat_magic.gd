extends Node3D
class_name CombatMagic
## Atacs màgics a curta distància del jugador (substitueixen l'espasa).
##  - tall(): mitja lluna d'energia davant del jugador, cap al ratolí. Combo de 3.
##  - ona(): cercle que s'expandeix al voltant del jugador i empeny els enemics.
## Són efectes que no depenen de les animacions del cos, així que no cal sincronitzar res.

signal cop_encertat(enemic: Node3D, dany: int)

const TALL := {"dany": 20, "abast": 2.3, "mig_angle": 70.0, "recarrega": 0.32}
const ONA := {"dany": 30, "radi": 2.8, "recarrega": 2.5}
const FINESTRA_COMBO := 0.7        # segons per encadenar el tall següent
const ALCADA_MAXIMA := 2.4         # enemics una mica enlaire també compten
const ALCADA_EFECTE := 0.7         # a quina alçada es dibuixa el tall

const TEXTURA_ONA := preload("res://Sprites/Misc/magic-3.png")
const COLOR_TALL := [Color(0.55, 0.85, 1.0), Color(0.75, 0.6, 1.0), Color(1.0, 0.85, 0.5)]
const COLOR_ONA := Color(0.8, 0.5, 1.0)

var jugador: Node3D
var combo := 0
var temps_des_del_tall := 99.0
var temps_des_de_ona := 99.0

static var _materials := {}
static var _textura_tall: ImageTexture

## Mitja lluna gruixuda en pixel art, amb la panxa cap amunt (cap on va el tall).
## (El slash.PNG de l'espasa és massa prim per veure's estirat a terra.)
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
			var d_int := p.distance_to(interior)
			if d_ext <= 14.0 and d_int > 12.5 and p.y < 24.0:
				# La vora exterior més opaca; cap a dins, més transparent
				var alfa := 1.0 if d_ext > 12.0 else 0.65
				imatge.set_pixel(x, y, Color(1, 1, 1, alfa))
	_textura_tall = ImageTexture.create_from_image(imatge)
	return _textura_tall

func _ready():
	jugador = get_parent()

func _physics_process(delta):
	temps_des_del_tall += delta
	temps_des_de_ona += delta

func progres_tall() -> float:
	return clampf(temps_des_del_tall / TALL.recarrega, 0.0, 1.0)

func progres_ona() -> float:
	return clampf(temps_des_de_ona / ONA.recarrega, 0.0, 1.0)

# ─────────────── Tall

## Retorna false si encara s'està recarregant
func tall(direccio: Vector3) -> bool:
	if temps_des_del_tall < TALL.recarrega:
		return false
	combo = combo + 1 if temps_des_del_tall < FINESTRA_COMBO and combo < 3 else 1
	temps_des_del_tall = 0.0

	var fort := combo == 3
	var dany: int = int(TALL.dany * (1.6 if fort else 1.0))
	var abast: float = TALL.abast * (1.2 if fort else 1.0)
	_efecte_tall(direccio, abast, fort)
	_colpejar_con(direccio, abast, TALL.mig_angle, dany, 5.0 if not fort else 8.0)
	return true

func _efecte_tall(direccio: Vector3, abast: float, fort: bool):
	# Un pivot girat cap a la direcció, i el sprite estirat a terra (horitzontal)
	var pivot := Node3D.new()
	jugador.get_parent().add_child(pivot)
	pivot.global_position = jugador.global_position + Vector3.UP * ALCADA_EFECTE
	pivot.rotation.y = atan2(direccio.x, direccio.z)

	# Dues capes: una aura de color més gran i un nucli blanc a sobre
	var mida_px: float = abast * 1.1 / 32.0
	var aura := _sprite_tall(mida_px * 1.25, COLOR_TALL[combo - 1], 0)
	var nucli := _sprite_tall(mida_px, Color(1, 1, 1, 0.95), 1)
	for sprite in [aura, nucli]:
		sprite.position = Vector3(0, 0, abast * 0.3)
		pivot.add_child(sprite)

	pivot.scale = Vector3.ONE * 0.5
	var t := pivot.create_tween().set_parallel(true)
	t.tween_property(pivot, "scale", Vector3.ONE * (1.25 if fort else 1.0), 0.09).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(nucli, "modulate:a", 0.0, 0.15).set_delay(0.05)
	t.tween_property(aura, "modulate:a", 0.0, 0.25).set_delay(0.08)
	t.chain().tween_callback(pivot.queue_free)

func _sprite_tall(pixel_size: float, color: Color, prioritat: int) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.texture = textura_tall()
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.pixel_size = pixel_size
	sprite.flip_h = combo == 2          # el 2n tall, en sentit contrari
	sprite.material_override = _material_efecte(textura_tall())
	sprite.modulate = color
	sprite.render_priority = prioritat
	sprite.rotation_degrees.x = 90      # estirat a terra, amb la panxa cap endavant
	return sprite

# ─────────────── Ona

func ona() -> bool:
	if temps_des_de_ona < ONA.recarrega:
		return false
	temps_des_de_ona = 0.0
	_efecte_ona()
	for enemic in _enemics_propers(ONA.radi):
		_colpejar(enemic, ONA.dany, 9.0)
	return true

func _efecte_ona():
	var cercle := Sprite3D.new()
	cercle.texture = TEXTURA_ONA
	cercle.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cercle.material_override = _material_efecte(TEXTURA_ONA)
	cercle.modulate = COLOR_ONA
	cercle.rotation_degrees.x = -90
	jugador.get_parent().add_child(cercle)
	cercle.global_position = jugador.global_position + Vector3.UP * 0.1
	# Mida final = diàmetre de l'ona
	var mida_final: float = ONA.radi * 2.0 / (TEXTURA_ONA.get_width() * cercle.pixel_size)
	cercle.scale = Vector3.ONE * mida_final * 0.2
	var t := cercle.create_tween().set_parallel(true)
	t.tween_property(cercle, "scale", Vector3.ONE * mida_final, 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(cercle, "rotation_degrees:y", 90.0, 0.45)
	t.tween_property(cercle, "modulate:a", 0.0, 0.3).set_delay(0.15)
	t.chain().tween_callback(cercle.queue_free)

# ─────────────── Impactes

func _colpejar_con(direccio: Vector3, abast: float, mig_angle: float, dany: int, empenta: float):
	for enemic in _enemics_propers(abast):
		var pla := _pla(enemic.global_position - jugador.global_position)
		if pla.length() > 0.4 and rad_to_deg(direccio.angle_to(pla.normalized())) > mig_angle:
			continue
		_colpejar(enemic, dany, empenta)

func _colpejar(enemic: Node3D, dany: int, _empenta: float):
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

static func _pla(v: Vector3) -> Vector3:
	return Vector3(v.x, 0, v.z)

## Material dels efectes: sense ombres ni llum, i que no quedi tapat pels ratpenats
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
