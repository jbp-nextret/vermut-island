extends Node
class_name EscalatPixel
## Fa que la imatge del joc (que es dibuixa en un SubViewport de baixa resolució) s'ampliï
## sempre un nombre ENTER de vegades a la pantalla.
##
## Amb ampliacions fraccionàries (una pantalla de 900 px d'alçada donaria ×2,5) unes files
## i columnes de píxels surten més gruixudes que d'altres, i en moure la càmera sembla que
## la imatge trontolli o estigui mal retallada. Aquí triem un factor enter (perquè el joc
## faci com a mínim 360 px d'alçada) i fem el SubViewport de la mida justa per omplir la
## pantalla: 720 i 1080 → 360 px, 900 → 450, 1200 → 400, 1440 → 360, 2160 → 360.

const ALCADA_OBJECTIU := 360.0

var subviewport: SubViewport
var contenidor: SubViewportContainer
var factor := 2

static func aplicar(sv: SubViewport, pare: Node) -> EscalatPixel:
	var e := EscalatPixel.new()
	e.name = "EscalatPixel"
	e.subviewport = sv
	e.contenidor = sv.get_parent() as SubViewportContainer
	pare.add_child(e)
	return e

func _ready():
	if contenidor == null:
		return
	contenidor.stretch = false
	contenidor.set_anchors_preset(Control.PRESET_TOP_LEFT)
	get_tree().root.size_changed.connect(_recalcular)
	_recalcular()

func _recalcular():
	var pantalla := Vector2(get_window().size)
	# Arrodonim cap avall: el joc fa com a mínim 360 px d'alçada i el HUD no queda gegant
	factor = maxi(1, floori(pantalla.y / ALCADA_OBJECTIU))
	var mida := (pantalla / factor).ceil()
	subviewport.size = Vector2i(mida)
	# El contenidor viu dins del canvas escalat del projecte (canvas_items): compensem
	# aquesta escala perquè cada píxel del joc ocupi exactament `factor` píxels de pantalla
	var escala_canvas := get_tree().root.get_final_transform().get_scale().x
	contenidor.position = Vector2.ZERO
	contenidor.size = mida
	contenidor.scale = Vector2.ONE * (factor / escala_canvas)
