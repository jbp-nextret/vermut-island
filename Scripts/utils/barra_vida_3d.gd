extends Node3D
class_name BarraVida3D
## Barra de vida petita que flota sobre un personatge o un cultiu.
## Només es veu quan no té la vida plena.

const AMPLE_PX := 32
const ALT_PX := 4

var fons: Sprite3D
var ple: Sprite3D

static func crear(pare: Node3D, alcada: float) -> BarraVida3D:
	var barra := BarraVida3D.new()
	barra.position = Vector3.UP * alcada
	pare.add_child(barra)
	return barra

func _ready():
	var imatge := Image.create(AMPLE_PX, ALT_PX, false, Image.FORMAT_RGBA8)
	imatge.fill(Color.WHITE)
	var textura := ImageTexture.create_from_image(imatge)

	fons = _crear_sprite(textura, Color(0.1, 0.1, 0.1, 0.8), 0)
	ple = _crear_sprite(textura, Color.GREEN, 1)
	# La part plena s'escurça per la dreta: ancorada a l'esquerra
	ple.centered = false
	ple.offset = Vector2(-AMPLE_PX / 2.0, -ALT_PX / 2.0)
	ple.region_enabled = true
	ple.region_rect = Rect2(0, 0, AMPLE_PX, ALT_PX)
	visible = false

func _crear_sprite(textura: Texture2D, color: Color, prioritat: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = textura
	s.modulate = color
	s.pixel_size = 0.02
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.render_priority = prioritat
	s.shaded = false
	add_child(s)
	return s

func mostrar(actual: float, maxim: float) -> void:
	var r := clampf(actual / maxim, 0.0, 1.0) if maxim > 0 else 0.0
	visible = r < 1.0 and r > 0.0
	ple.region_rect = Rect2(0, 0, maxf(1.0, AMPLE_PX * r), ALT_PX)
	ple.modulate = Color.RED.lerp(Color(0.3, 1.0, 0.3), r)
