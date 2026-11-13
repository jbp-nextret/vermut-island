extends Node
## Món en baixa resolució (estil pixel art) amb un SubViewport.
##
## No cal canviar cap escena: el SubViewport comparteix el World3D de la finestra i té una
## càmera "mirall" que copia la càmera activa a cada fotograma (la del jugador, la del
## mode construcció...). La finestra deixa de dibuixar el 3D (disable_3d) i mostra la
## imatge petita ampliada un nombre ENTER de vegades, sense filtrar (píxels nets), sota
## del HUD. El HUD i els menús continuen a la resolució de la pantalla.
##
## Perquè els píxels no "bullin" quan la càmera es mou, la càmera mirall es col·loca a la
## graella de píxels del món i la imatge es desplaça la resta (en píxels de pantalla),
## així el moviment és suau. La imatge té un píxel de marge per cada costat per poder-la
## desplaçar sense que es vegi la vora.
##
## La càmera de veritat no es toca: els raigs del ratolí (apuntar, clicar arbres...) i
## les posicions a la pantalla (etiquetes, indicadors) continuen funcionant igual.
##
## Els textos 3D (Label3D: noms, "Cal la destral", números de dany...) no es pixelen:
## van a la capa visual ETIQUETES i es dibuixen a part, a la resolució de la pantalla, en
## un segon SubViewport transparent per sobre del món.
##
## Opció "resolucio_pixel" (alçada de la imatge en píxels): 0 = resolució nativa (sense
## SubViewport), o 270, 360, 480...

const MARGE := 1   # píxels de marge a cada costat
const CAPA_ETIQUETES := 1 << 19   # capa visual 20

var sv: SubViewport
var camera: Camera3D
var capa: CanvasLayer
var imatge: TextureRect
var sv_etiquetes: SubViewport
var camera_etiquetes: Camera3D
var imatge_etiquetes: TextureRect
var factor := 1
var alcada := 0          # alçada visible en píxels del joc
var actiu := false

func _ready():
	process_priority = 1000   # després de les càmeres (que es mouen al seu _process)
	sv = SubViewport.new()
	sv.name = "MonPixelat"
	sv.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sv.handle_input_locally = false
	sv.audio_listener_enable_3d = false
	sv.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(sv)
	camera = Camera3D.new()
	sv.add_child(camera)
	capa = CanvasLayer.new()
	capa.layer = -100   # per sota de tot el HUD
	add_child(capa)
	imatge = TextureRect.new()
	imatge.texture = sv.get_texture()
	imatge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	imatge.stretch_mode = TextureRect.STRETCH_SCALE
	imatge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(imatge)
	# Els textos 3D, a part i a la resolució de la pantalla
	sv_etiquetes = SubViewport.new()
	sv_etiquetes.name = "Etiquetes"
	sv_etiquetes.transparent_bg = true
	sv_etiquetes.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sv_etiquetes.handle_input_locally = false
	sv_etiquetes.audio_listener_enable_3d = false
	add_child(sv_etiquetes)
	camera_etiquetes = Camera3D.new()
	camera_etiquetes.cull_mask = CAPA_ETIQUETES
	sv_etiquetes.add_child(camera_etiquetes)
	imatge_etiquetes = TextureRect.new()
	imatge_etiquetes.texture = sv_etiquetes.get_texture()
	imatge_etiquetes.stretch_mode = TextureRect.STRETCH_SCALE
	imatge_etiquetes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(imatge_etiquetes)
	get_tree().node_added.connect(_node_afegit)
	get_tree().root.size_changed.connect(_recalcular)
	SettingsManager.opcio_canviada.connect(func(clau, _v):
		if clau == "resolucio_pixel":
			_recalcular())
	_recalcular()

## La mida de la imatge petita i l'ampliació, segons la finestra i l'opció
func _recalcular():
	var objectiu := int(SettingsManager.valor("resolucio_pixel"))
	var pantalla := Vector2(get_window().size)
	if objectiu <= 0 or pantalla.y < 1.0:
		alcada = 0
		return
	# Arrodonim cap avall: la imatge fa com a mínim l'alçada triada
	factor = maxi(1, floori(pantalla.y / objectiu))
	var visible_px := (pantalla / factor).ceil()
	alcada = int(visible_px.y)
	sv.size = Vector2i(visible_px) + Vector2i.ONE * MARGE * 2
	sv_etiquetes.size = Vector2i(pantalla)

## Els textos 3D van a la seva capa (també els que ja hi havia)
func _node_afegit(n: Node):
	if n is Label3D:
		(n as Label3D).layers = CAPA_ETIQUETES

func _process(_delta):
	var principal := get_tree().root.get_camera_3d()
	var ara := alcada > 0 and principal != null
	if ara != actiu:
		actiu = ara
		get_tree().root.disable_3d = actiu
		capa.visible = actiu
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS if actiu else SubViewport.UPDATE_DISABLED
		sv_etiquetes.render_target_update_mode = sv.render_target_update_mode
	if not actiu:
		return
	if sv.world_3d != get_tree().root.world_3d:
		sv.world_3d = get_tree().root.world_3d
		sv_etiquetes.world_3d = sv.world_3d
	_copiar_camera(principal)

func _copiar_camera(c: Camera3D):
	camera.projection = c.projection
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = c.near
	camera.far = c.far
	camera.fov = c.fov
	camera.cull_mask = c.cull_mask & ~CAPA_ETIQUETES
	camera.attributes = c.attributes
	camera.environment = c.environment
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	camera.current = true
	# Amb el marge, la imatge és una mica més alta que el que es veu
	var alt_total := float(sv.size.y)
	var escala := alt_total / float(alcada)
	var xf := c.global_transform
	# El desplaçament de la càmera (el sacseig) passat a la posició
	xf.origin += xf.basis.x.normalized() * c.h_offset + xf.basis.y.normalized() * c.v_offset
	var resta := Vector2.ZERO
	if c.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = c.size * escala
		# Mida d'un píxel del joc en unitats del món, i la càmera a la graella de píxels
		var texel := c.size / float(alcada)
		var dreta := xf.basis.x.normalized()
		var amunt := xf.basis.y.normalized()
		var a := xf.origin.dot(dreta)
		var b := xf.origin.dot(amunt)
		var ra := a - roundf(a / texel) * texel
		var rb := b - roundf(b / texel) * texel
		xf.origin -= dreta * ra + amunt * rb
		resta = Vector2(ra, rb) / texel   # en píxels del joc
	else:
		camera.fov = c.fov   # en perspectiva no s'ajusta a la graella
	camera.global_transform = xf
	# La imatge ampliada, desplaçada la resta (en píxels de pantalla); el canvas del joc
	# està escalat (stretch canvas_items): ho compensem perquè cada píxel faci `factor`
	var escala_canvas := get_tree().root.get_final_transform().get_scale().x
	var px := float(factor) / escala_canvas
	imatge.size = Vector2(sv.size)
	imatge.scale = Vector2.ONE * px
	imatge.position = (Vector2(-MARGE, -MARGE) + Vector2(-resta.x, resta.y)) * px
	# Els textos: la càmera tal com és (sense ajustar a la graella), a tota la pantalla
	camera_etiquetes.projection = c.projection
	camera_etiquetes.keep_aspect = c.keep_aspect
	camera_etiquetes.size = c.size
	camera_etiquetes.fov = c.fov
	camera_etiquetes.near = c.near
	camera_etiquetes.far = c.far
	camera_etiquetes.h_offset = c.h_offset
	camera_etiquetes.v_offset = c.v_offset
	camera_etiquetes.global_transform = c.global_transform
	camera_etiquetes.current = true
	imatge_etiquetes.position = Vector2.ZERO
	imatge_etiquetes.size = Vector2(sv_etiquetes.size)
	imatge_etiquetes.scale = Vector2.ONE / escala_canvas
