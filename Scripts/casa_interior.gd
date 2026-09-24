extends Node3D

const LIMIT_SALA := 4               # cel·les de -4 a 4 (a ±5 hi ha les parets)
const CAPA_TERRA := 1 << 1          # capa de col·lisió 2 ("terra")
const ALFA_PREVIEW := 0.45          # 0 = opac, 1 = invisible
const DISTANCIA_ENTRADA := 0.9      # espai lliure davant la porta dels clients

# Sala
const MIDA_SALA := 10.0
const ALCADA_PARET := 2.2
const GRUIX_PARET := 0.2
const ESCALA_PARET_BAIXADA := 0.08  # paret "abaixada" quan tapa la càmera (com als Sims)

# Mobles
@export var mobles_disponibles: Array[PackedScene]
@export var noms_mobles: Array[String] = ["Barra Normal", "Barra Mig", "Barra Lateral", "Cadira", "Rosa", "Cactus", "Amapola", "Barrica"]
@export var grid_size: float = 1.0

var mode_construccio := false
var mode_eliminacio := false
var moble_preview: Node3D = null
var posicio_preview: Variant = null   # Vector3 o null si el ratolí no apunta a terra
enum EstatPreview { OK, AVIS, BLOQUEJAT }
var estat_preview := EstatPreview.OK
var moble_hovered: Node3D = null
var punts_grid: Array[Node3D] = []
var index_preview := -1
var rotacio_preview := 0.0
var pintant := false                  # clic esquerre mantingut: col·loca mentre arrossegues
var ultima_posicio_pintada: Variant = null

# Càmera de construcció
var camera_rotation_x := 0.0
var camera_rotation_y := 0.0
var camera_distance := 8.0
var camera_height := 5.0
var camera_anterior: Camera3D = null

@onready var panel_ui: Panel = $CanvasLayer/Panel
@onready var item_list: ItemList = $CanvasLayer/ItemList
@onready var porta_sortida = $PortaSortida
@onready var camera_construccio: Camera3D = $Camera3D
@onready var porta_clients: Marker3D = $Door
@onready var rellotge: Label = $CanvasLayer/Rellotge

# HUD (es crea per codi)
var boto_construir: Button
var boto_vermuteria: Button
var label_ajuda: Label
var label_avis: Label
var tween_avis: Tween
var fos_negre: ColorRect
var label_transicio: Label

var gestor_servei: GestorServei

# Parets: [{cos: StaticBody3D, visual: Node3D, normal: Vector3}]
var parets: Array = []

# Acabats (terra i parets)
enum Pestanya { MOBLES, PARETS, TERRA }
var pestanya := Pestanya.MOBLES
var terra_actual := CatalegAcabats.TERRA_PER_DEFECTE
var parets_actual := CatalegAcabats.PARET_PER_DEFECTE
var acabats_comprats: Array = []
var acabat_provant: AcabatInterior = null   # el que s'està provant, encara sense comprar
var acabats_llista: Array = []              # els acabats que mostra ara la llista
var pestanyes: TabBar
var boto_comprar: Button
var material_terra := StandardMaterial3D.new()
var material_parets := StandardMaterial3D.new()

# Materials
var material_hover := StandardMaterial3D.new()
var material_preview_ok := StandardMaterial3D.new()
var material_preview_ko := StandardMaterial3D.new()
var material_preview_avis := StandardMaterial3D.new()
var material_grid := StandardMaterial3D.new()

# ─────────────────────────────────────────────── Cicle de vida

func _ready():
	GameState.dins_casa = true
	GameState.mode = GameState.Mode.EXPLORAR

	crear_interior()
	porta_sortida.salir_casa.connect(_on_salir_casa)
	_configurar_materials()
	_configurar_llista_mobles()
	_crear_hud()
	_crear_gestor_servei()
	add_child(HudDiners.new())

	panel_ui.visible = false
	item_list.visible = false
	rellotge.visible = false   # dins de casa el temps està aturat
	carregar_decoracio()
	_aplicar_acabats_actuals()
	_actualitzar_taules()
	_actualitzar_hud()

func _exit_tree():
	GameState.dins_casa = false
	GameState.mode = GameState.Mode.EXPLORAR

func _configurar_materials():
	material_hover.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_hover.albedo_color = Color(1, 0, 0, 0.8)

	for m in [material_preview_ok, material_preview_ko, material_preview_avis, material_grid]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_preview_ok.albedo_color = Color(0.35, 1.0, 0.45, 0.35)
	material_preview_ko.albedo_color = Color(1.0, 0.25, 0.25, 0.45)
	material_preview_avis.albedo_color = Color(1.0, 0.8, 0.2, 0.4)
	material_grid.albedo_color = Color(1, 1, 1, 0.35)

func _configurar_llista_mobles():
	var capa: CanvasLayer = $CanvasLayer

	pestanyes = TabBar.new()
	pestanyes.add_tab("Mobles")
	pestanyes.add_tab("Parets")
	pestanyes.add_tab("Terra")
	pestanyes.focus_mode = Control.FOCUS_NONE
	pestanyes.position = Vector2(12, 52)
	pestanyes.size = Vector2(240, 32)
	pestanyes.visible = false
	pestanyes.tab_changed.connect(_canviar_pestanya)
	capa.add_child(pestanyes)

	# Sense focus: si no, la llista es "menja" la Q i la E (cerca per lletra)
	item_list.focus_mode = Control.FOCUS_NONE
	item_list.position = Vector2(12, 88)
	item_list.size = Vector2(240, 250)
	item_list.item_selected.connect(_on_item_seleccionat)

	boto_comprar = _crear_boto("")
	boto_comprar.position = Vector2(12, 346)
	boto_comprar.size = Vector2(240, 44)
	boto_comprar.visible = false
	boto_comprar.pressed.connect(_comprar_acabat_provant)
	capa.add_child(boto_comprar)

	_omplir_llista()

func _crear_gestor_servei():
	gestor_servei = GestorServei.new()
	gestor_servei.name = "GestorServei"
	gestor_servei.porta = porta_clients
	add_child(gestor_servei)
	gestor_servei.servei_obert.connect(_actualitzar_hud)
	gestor_servei.servei_tancat.connect(_on_servei_tancat)
	gestor_servei.temps_actualitzat.connect(_on_temps_servei)

# ─────────────────────────────────────────────── Sala

func crear_interior():
	var m := MIDA_SALA / 2.0

	# Sòl
	var sol_static = StaticBody3D.new()
	sol_static.name = "Sol"
	# Capa 1 perquè el jugador hi camini, capa 2 perquè el raig de construcció només vegi el terra
	sol_static.collision_layer = 1 | CAPA_TERRA
	add_child(sol_static)

	var sol_mesh = MeshInstance3D.new()
	sol_mesh.mesh = PlaneMesh.new()
	sol_mesh.mesh.size = Vector2(MIDA_SALA, MIDA_SALA)
	sol_mesh.material_override = material_terra
	sol_static.add_child(sol_mesh)

	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(MIDA_SALA, 0.2, MIDA_SALA)
	collision.position.y = -0.1
	sol_static.add_child(collision)

	# Quatre parets tancades: ja no es pot caure de l'habitació.
	# La que queda entre la càmera i la sala s'abaixa sola (_actualitzar_parets).
	var ample := MIDA_SALA + GRUIX_PARET
	var fons := crear_paret("Paret Fons", Vector3(0, 0, -m), Vector3(ample, ALCADA_PARET, GRUIX_PARET), Vector3(0, 0, -1))
	crear_paret("Paret Davant", Vector3(0, 0, m), Vector3(ample, ALCADA_PARET, GRUIX_PARET), Vector3(0, 0, 1))
	crear_paret("Paret Esquerra", Vector3(-m, 0, 0), Vector3(GRUIX_PARET, ALCADA_PARET, ample), Vector3(-1, 0, 0))
	var dreta := crear_paret("Paret Dreta", Vector3(m, 0, 0), Vector3(GRUIX_PARET, ALCADA_PARET, ample), Vector3(1, 0, 0))

	crear_finestra(fons, Vector3(0, 1.3, 0), Vector3(2, 1.0, GRUIX_PARET + 0.04))
	crear_porta_visual(dreta, Vector3(0, 0.95, 2), Vector3(GRUIX_PARET + 0.04, 1.9, 1))

## Retorna el node visual de la paret (per penjar-hi porta o finestra)
func crear_paret(nom: String, posicio: Vector3, mida: Vector3, normal: Vector3) -> Node3D:
	var paret_static = StaticBody3D.new()
	paret_static.position = posicio
	paret_static.name = nom
	add_child(paret_static)

	# Tot el que es veu penja d'aquest node: escalant-lo en Y la paret "baixa" des de terra
	var visual := Node3D.new()
	visual.name = "Visual"
	paret_static.add_child(visual)

	var paret_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = mida
	paret_mesh.mesh = box
	paret_mesh.position.y = mida.y / 2.0
	paret_mesh.material_override = material_parets
	visual.add_child(paret_mesh)

	# La col·lisió no baixa mai
	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(mida.x, 3.0, mida.z)
	collision.position.y = 1.5
	paret_static.add_child(collision)

	parets.append({"cos": paret_static, "visual": visual, "normal": normal})
	return visual

func crear_finestra(paret: Node3D, posicio: Vector3, mida: Vector3):
	var finestra = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = mida
	finestra.mesh = box
	finestra.position = posicio
	finestra.name = "Finestra"
	paret.add_child(finestra)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.7, 1.0, 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	finestra.material_override = material

func crear_porta_visual(paret: Node3D, posicio: Vector3, mida: Vector3):
	var porta = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = mida
	porta.mesh = box
	porta.position = posicio
	porta.name = "PortaVisual"
	paret.add_child(porta)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.0)
	material.emission_enabled = true
	material.emission = Color(0.8, 0.6, 0.0)
	material.emission_energy_multiplier = 0.6
	porta.material_override = material

## Abaixa les parets que queden entre la càmera i la sala, i aixeca les altres
func _actualitzar_parets(delta: float):
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	for paret in parets:
		var tapa: bool = (camera.global_position - paret.cos.global_position).dot(paret.normal) > 0.0
		var objectiu := ESCALA_PARET_BAIXADA if tapa else 1.0
		paret.visual.scale.y = move_toward(paret.visual.scale.y, objectiu, delta * 4.0)

func _rids_parets() -> Array[RID]:
	var rids: Array[RID] = []
	for paret in parets:
		rids.append(paret.cos.get_rid())
	return rids

# ─────────────────────────────────────────────── HUD

func _crear_hud():
	var capa: CanvasLayer = $CanvasLayer

	# Botons a dalt a la dreta
	var caixa := HBoxContainer.new()
	caixa.add_theme_constant_override("separation", 8)
	capa.add_child(caixa)
	caixa.anchor_left = 1.0
	caixa.anchor_right = 1.0
	caixa.offset_top = 12
	caixa.offset_right = -12
	caixa.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	boto_construir = _crear_boto("Construir")
	boto_construir.pressed.connect(alternar_mode_construccio)
	caixa.add_child(boto_construir)

	boto_vermuteria = _crear_boto("Obrir vermuteria")
	boto_vermuteria.pressed.connect(_on_boto_vermuteria)
	caixa.add_child(boto_vermuteria)

	# Ajuda de controls, a baix
	label_ajuda = _crear_label(Color.WHITE, 18)
	capa.add_child(label_ajuda)
	label_ajuda.anchor_top = 1.0
	label_ajuda.anchor_bottom = 1.0
	label_ajuda.anchor_right = 1.0
	label_ajuda.offset_top = -44
	label_ajuda.offset_bottom = -14

	# Avisos temporals ("aquí no hi cap"...)
	label_avis = _crear_label(Color(1, 0.55, 0.5), 22)
	capa.add_child(label_avis)
	label_avis.anchor_top = 1.0
	label_avis.anchor_bottom = 1.0
	label_avis.anchor_right = 1.0
	label_avis.offset_top = -84
	label_avis.offset_bottom = -52
	label_avis.modulate.a = 0.0

	# Fos a negre per a la transició a la nit
	fos_negre = ColorRect.new()
	fos_negre.color = Color(0.02, 0.02, 0.06)
	fos_negre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fos_negre.set_anchors_preset(Control.PRESET_FULL_RECT)
	fos_negre.modulate.a = 0.0
	capa.add_child(fos_negre)

	label_transicio = _crear_label(Color(0.85, 0.85, 1.0), 36)
	label_transicio.set_anchors_preset(Control.PRESET_FULL_RECT)
	label_transicio.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fos_negre.add_child(label_transicio)

func _crear_boto(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 44)
	# Sense focus: si no, l'Espai (saltar) tornaria a "clicar" l'últim botó
	b.focus_mode = Control.FOCUS_NONE
	return b

func _crear_label(color: Color, mida: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_font_size_override("font_size", mida)
	return l

func _actualitzar_hud():
	boto_construir.text = "Sortir de construcció" if mode_construccio else "Construir"
	boto_construir.disabled = not mode_construccio and not GameState.pot_construir()

	if gestor_servei.obert:
		_on_temps_servei(gestor_servei.temps_restant)
	elif not GestorTemps.es_hora_de_servei():
		boto_vermuteria.text = "Tancat fins demà"
	else:
		boto_vermuteria.text = "Obrir vermuteria"
	boto_vermuteria.disabled = not gestor_servei.obert and not GameState.pot_obrir_vermuteria()

	if not mode_construccio:
		label_ajuda.text = ""
	elif pestanya != Pestanya.MOBLES:
		label_ajuda.text = "Tria un acabat per provar com queda   ·   Roda: zoom   ·   Botó central: girar càmera   ·   Esc: desfer / sortir"
	elif mode_eliminacio:
		label_ajuda.text = "Clic esquerre: esborrar   ·   Clic dret / Esc: tornar a col·locar"
	else:
		label_ajuda.text = "Clic esquerre: col·locar (mantén per pintar)   ·   Q/E: girar   ·   Clic dret: esborrar   ·   Roda: zoom   ·   Botó central: girar càmera   ·   Esc: sortir"

func _on_boto_vermuteria():
	if not gestor_servei.obert and _seients_utilitzables() == 0:
		_mostrar_avis("Necessites almenys una cadira amb una barra al costat")
		return
	gestor_servei.alternar()

func _seients_utilitzables() -> int:
	return get_tree().get_nodes_in_group("seats").filter(func(s): return s.es_utilitzable()).size()

## Reparteix les barres entre els seients (una barra = una cadira)
## i, en mode construcció, marca els seients que s'han quedat sense taula.
func _actualitzar_taules():
	var seients := _vius("seats")
	var barres := _vius("barres")
	var posicions := seients.map(func(s): return s.global_position)
	var preferides := seients.map(func(s): return barres.find(s.taula()))
	var assignacio := AssignadorTaules.assignar(posicions, preferides, barres)
	for i in seients.size():
		seients[i].taula_assignada = barres[assignacio[i]] if assignacio[i] != -1 else null
	for seient in seients:
		seient.mostrar_avis(mode_construccio and not seient.es_utilitzable())

func _mateixa_cella(a: Vector3, b: Vector3) -> bool:
	return round(a.x / grid_size) == round(b.x / grid_size) and round(a.z / grid_size) == round(b.z / grid_size)

func _vius(grup: String) -> Array:
	return get_tree().get_nodes_in_group(grup).filter(func(n): return not n.is_queued_for_deletion())

func _on_temps_servei(segons: float):
	var s := int(ceil(segons))
	boto_vermuteria.text = "Tancar vermuteria  %d:%02d" % [floori(s / 60.0), s % 60]

func _on_servei_tancat():
	_actualitzar_hud()
	# Fos a negre curt: "Ha caigut la nit" i tornem a la casa
	var resum := "%d clients servits   ·   +%d 🪙" % [gestor_servei.clients_servits, gestor_servei.guanys]
	if gestor_servei.clients_enfadats > 0:
		resum += "\n%d clients han marxat enfadats" % gestor_servei.clients_enfadats
	label_transicio.text = "Fi del servei\n\n%s\n\nHa caigut la nit..." % resum
	var t := create_tween()
	t.tween_property(fos_negre, "modulate:a", 1.0, 0.6)
	t.tween_interval(2.8)
	t.tween_property(fos_negre, "modulate:a", 0.0, 0.8)

func _mostrar_avis(text: String):
	label_avis.text = text
	if tween_avis:
		tween_avis.kill()
	label_avis.modulate.a = 1.0
	tween_avis = create_tween()
	tween_avis.tween_interval(1.2)
	tween_avis.tween_property(label_avis, "modulate:a", 0.0, 0.4)

# ─────────────────────────────────────────────── Input

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("decorar"):
		alternar_mode_construccio()
		return
	if not mode_construccio:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				if acabat_provant:
					_restaurar_acabats()
				elif mode_eliminacio:
					desactivar_mode_eliminacio()
				elif moble_preview:
					_cancelar_preview()
				else:
					sortir_mode_construccio()
			KEY_Q:
				rotacio_preview -= 90
			KEY_E:
				rotacio_preview += 90

	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if event.pressed else Input.MOUSE_MODE_VISIBLE)
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom(-0.5)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom(0.5)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					if mode_eliminacio:
						eliminar_moble(moble_hovered)
					else:
						pintant = true
						ultima_posicio_pintada = null
						col_locar_moble(true)
				else:
					pintant = false
			MOUSE_BUTTON_RIGHT:
				if event.pressed and pestanya == Pestanya.MOBLES:
					if mode_eliminacio:
						desactivar_mode_eliminacio()
					else:
						activar_mode_eliminacio()

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		camera_rotation_y -= event.relative.x * 0.01
		camera_rotation_x = clamp(camera_rotation_x - event.relative.y * 0.01, -1.5, 1.5)
		actualitzar_posicio_camera()

func _zoom(canvi: float):
	camera_distance = clamp(camera_distance + canvi, 3.0, 15.0)
	actualitzar_posicio_camera()

# ─────────────────────────────────────────────── Mode construcció

func alternar_mode_construccio():
	if mode_construccio:
		sortir_mode_construccio()
	elif GameState.pot_construir():
		entrar_mode_construccio()
	elif gestor_servei.obert:
		_mostrar_avis("Tanca la vermuteria abans de construir")

func entrar_mode_construccio():
	mode_construccio = true
	GameState.mode = GameState.Mode.CONSTRUIR
	panel_ui.visible = true
	item_list.visible = true
	pestanyes.visible = true
	_omplir_llista()
	mostrar_grid()

	# Càmera pròpia, perquè no toqui la del jugador
	camera_anterior = get_viewport().get_camera_3d()
	camera_construccio.make_current()
	actualitzar_posicio_camera()

	if index_preview >= 0:
		_crear_preview()
	_actualitzar_taules()
	_actualitzar_hud()

func sortir_mode_construccio():
	mode_construccio = false
	pintant = false
	desactivar_mode_eliminacio()
	_eliminar_preview()
	_restaurar_acabats()
	panel_ui.visible = false
	item_list.visible = false
	pestanyes.visible = false
	amagar_grid()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if is_instance_valid(camera_anterior):
		camera_anterior.make_current()
	camera_anterior = null

	GameState.mode = GameState.Mode.EXPLORAR
	guardar_decoracio()
	_actualitzar_taules()
	_actualitzar_hud()

func actualitzar_posicio_camera():
	var pos_x = sin(camera_rotation_y) * cos(camera_rotation_x) * camera_distance
	var pos_y = camera_height + sin(camera_rotation_x) * camera_distance
	var pos_z = cos(camera_rotation_y) * cos(camera_rotation_x) * camera_distance
	camera_construccio.global_position = Vector3(pos_x, pos_y, pos_z)
	camera_construccio.look_at(Vector3.ZERO, Vector3.UP)

func _process(delta):
	_actualitzar_parets(delta)
	if not mode_construccio:
		return
	if mode_eliminacio:
		actualitzar_hover_eliminacio()
	elif moble_preview:
		actualitzar_preview(delta)
		# Pintar: si mantens el clic i canvies de cel·la, col·loca-hi un altre moble
		if pintant and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			pintant = false
		if pintant and posicio_preview != null and posicio_preview != ultima_posicio_pintada:
			col_locar_moble(false)

func mostrar_grid():
	amagar_grid()
	var mesh := SphereMesh.new()
	mesh.radius = 0.04
	mesh.height = 0.08
	for x in range(-LIMIT_SALA, LIMIT_SALA + 1):
		for z in range(-LIMIT_SALA, LIMIT_SALA + 1):
			var punt := MeshInstance3D.new()
			punt.mesh = mesh
			punt.material_override = material_grid
			punt.position = Vector3(x * grid_size, 0.02, z * grid_size)
			add_child(punt)
			punts_grid.append(punt)

func amagar_grid():
	for punt in punts_grid:
		if is_instance_valid(punt):
			punt.queue_free()
	punts_grid.clear()

# ─────────────────────────────────────────────── Pestanyes i acabats

func _canviar_pestanya(index: int):
	_restaurar_acabats()
	pintant = false
	if mode_eliminacio:
		desactivar_mode_eliminacio()
	if pestanya == Pestanya.MOBLES:
		_cancelar_preview()
	pestanya = index as Pestanya
	_omplir_llista()
	_actualitzar_hud()

func _omplir_llista():
	item_list.clear()
	acabats_llista.clear()
	if pestanya == Pestanya.MOBLES:
		for nom in noms_mobles:
			item_list.add_item(nom)
		return

	var superficie := AcabatInterior.Superficie.PARET if pestanya == Pestanya.PARETS else AcabatInterior.Superficie.TERRA
	var actual := parets_actual if superficie == AcabatInterior.Superficie.PARET else terra_actual
	for acabat in CatalegAcabats.de_superficie(superficie):
		var text: String = acabat.nom
		if acabat.id == actual:
			text += "   ✓"
		elif not _es_meu(acabat):
			text += "   %d 🪙" % acabat.preu
		var i := item_list.add_item(text, acabat.icona())
		if acabat.textura:
			item_list.set_item_icon_modulate(i, acabat.color)
		acabats_llista.append(acabat)

func _on_item_seleccionat(index: int):
	if pestanya == Pestanya.MOBLES:
		_on_moble_seleccionat(index)
	else:
		_provar_acabat(acabats_llista[index])

func _es_meu(acabat: AcabatInterior) -> bool:
	return acabat.es_gratuit() or acabats_comprats.has(acabat.id)

## Es veu a la sala de seguida. Si ja és teu, queda posat; si no, cal comprar-lo.
func _provar_acabat(acabat: AcabatInterior):
	_restaurar_acabats()
	acabat.aplicar(_material_de(acabat.superficie))
	if _es_meu(acabat):
		_fixar_acabat(acabat)
		return
	acabat_provant = acabat
	boto_comprar.visible = true
	if Inventari.diners >= acabat.preu:
		boto_comprar.text = "Comprar per %d 🪙" % acabat.preu
		boto_comprar.disabled = false
	else:
		boto_comprar.text = "Et falten %d 🪙" % (acabat.preu - Inventari.diners)
		boto_comprar.disabled = true

func _comprar_acabat_provant():
	var acabat := acabat_provant
	if acabat == null or not Inventari.gastar_diners(acabat.preu):
		return
	acabats_comprats.append(acabat.id)
	_fixar_acabat(acabat)
	_mostrar_avis("Comprat: " + acabat.nom)
	guardar_decoracio()

func _fixar_acabat(acabat: AcabatInterior):
	if acabat.superficie == AcabatInterior.Superficie.PARET:
		parets_actual = acabat.id
	else:
		terra_actual = acabat.id
	acabat_provant = null
	boto_comprar.visible = false
	_omplir_llista()

## Desfà la prova d'un acabat no comprat i torna a posar els que tens
func _restaurar_acabats():
	acabat_provant = null
	if boto_comprar:
		boto_comprar.visible = false
	_aplicar_acabats_actuals()

func _aplicar_acabats_actuals():
	CatalegAcabats.per_id(terra_actual).aplicar(material_terra)
	CatalegAcabats.per_id(parets_actual).aplicar(material_parets)

func _material_de(superficie: AcabatInterior.Superficie) -> StandardMaterial3D:
	return material_parets if superficie == AcabatInterior.Superficie.PARET else material_terra

func _id_valid(id, per_defecte: String) -> String:
	return id if id is String and CatalegAcabats.per_id(id) != null else per_defecte

# ─────────────────────────────────────────────── Preview

func _on_moble_seleccionat(index: int):
	index_preview = index
	if mode_eliminacio:
		desactivar_mode_eliminacio()
	_crear_preview()

func _crear_preview():
	_eliminar_preview()
	if index_preview < 0 or index_preview >= mobles_disponibles.size():
		return
	moble_preview = mobles_disponibles[index_preview].instantiate()
	# La preview no ha de comptar com a moble: fora de tots els grups
	# (si no, es desaria, bloquejaria cel·les o un poring s'hi asseuria)
	for grup in moble_preview.get_groups():
		moble_preview.remove_from_group(grup)
	add_child(moble_preview)
	_desactivar_colisions(moble_preview)
	_per_cada_malla(moble_preview, func(m: GeometryInstance3D): m.transparency = ALFA_PREVIEW)
	moble_preview.visible = false
	estat_preview = EstatPreview.OK
	_pintar_preview()

func _eliminar_preview():
	if moble_preview:
		moble_preview.queue_free()
		moble_preview = null
	posicio_preview = null

func _cancelar_preview():
	_eliminar_preview()
	index_preview = -1
	item_list.deselect_all()

func actualitzar_preview(delta: float):
	posicio_preview = obtenir_posicio_grid()
	if posicio_preview == null:
		moble_preview.visible = false
		return

	var apareix := not moble_preview.visible
	moble_preview.visible = true
	if apareix:
		moble_preview.global_position = posicio_preview
	else:
		# Llisca cap a la cel·la en lloc de saltar-hi
		moble_preview.global_position = moble_preview.global_position.lerp(posicio_preview, minf(1.0, delta * 25.0))
	moble_preview.rotation.y = lerp_angle(moble_preview.rotation.y, deg_to_rad(rotacio_preview), minf(1.0, delta * 20.0))

	var estat := _estat_col_locacio(posicio_preview)
	if estat != estat_preview:
		estat_preview = estat
		_pintar_preview()

func _pintar_preview():
	var material: StandardMaterial3D
	match estat_preview:
		EstatPreview.OK: material = material_preview_ok
		EstatPreview.AVIS: material = material_preview_avis
		_: material = material_preview_ko
	_per_cada_malla(moble_preview, func(m: GeometryInstance3D): m.material_overlay = material)

func _estat_col_locacio(pos: Vector3) -> EstatPreview:
	if not _motiu_bloqueig(pos).is_empty():
		return EstatPreview.BLOQUEJAT
	if not _avis_col_locacio(pos).is_empty():
		return EstatPreview.AVIS
	return EstatPreview.OK

## Es pot col·locar, però potser no és bona idea (groc)
func _avis_col_locacio(pos: Vector3) -> String:
	if _tipus(moble_preview) == MobleBarra.Tipus.SEIENT and not _tindria_taula(pos):
		return "Cap barra lliure al costat: cap client s'hi asseurà"
	return ""

## Si posem una cadira nova a `pos`, li tocaria alguna barra?
## (fa el repartiment com si ja hi fos, sense treure la taula a cap altra cadira)
func _tindria_taula(pos: Vector3) -> bool:
	var seients := _vius("seats").filter(func(s): return not _mateixa_cella(s.global_position, pos))
	var barres := _vius("barres")
	var posicions := seients.map(func(s): return s.global_position)
	var preferides := seients.map(func(s): return barres.find(s.taula()))
	posicions.append(pos)
	preferides.append(-1)
	return AssignadorTaules.assignar(posicions, preferides, barres).back() != -1

func obtenir_posicio_grid() -> Variant:
	var ratoli := get_viewport().get_mouse_position()
	var camera := get_viewport().get_camera_3d()
	var origen := camera.project_ray_origin(ratoli)
	var query := PhysicsRayQueryParameters3D.create(origen, origen + camera.project_ray_normal(ratoli) * 100.0)
	query.collision_mask = CAPA_TERRA   # només el terra: ni mobles, ni jugador, ni porings
	var resultat := get_world_3d().direct_space_state.intersect_ray(query)
	if resultat.is_empty():
		return null
	var pos: Vector3 = resultat.position
	pos.x = round(pos.x / grid_size) * grid_size
	pos.z = round(pos.z / grid_size) * grid_size
	pos.y = 0.5
	return pos

# ─────────────────────────────────────────────── Col·locar

## Retorna per què no es pot col·locar la preview a `pos`, o "" si es pot.
func _motiu_bloqueig(pos: Vector3) -> String:
	if abs(round(pos.x / grid_size)) > LIMIT_SALA or abs(round(pos.z / grid_size)) > LIMIT_SALA:
		return "Fora de la sala"
	if Vector2(pos.x, pos.z).distance_to(Vector2(porta_clients.global_position.x, porta_clients.global_position.z)) < DISTANCIA_ENTRADA:
		return "Deixa lliure l'entrada dels clients"

	var hi_ha_barra := buscar_moble_a_posicio(pos, "barres") != null
	var hi_ha_seient := buscar_moble_a_posicio(pos, "mobles_reposats") != null
	var hi_ha_deco := buscar_moble_a_posicio(pos, "decoracio") != null
	var hi_ha_barrica := buscar_moble_a_posicio(pos, "barriques") != null

	match _tipus(moble_preview):
		MobleBarra.Tipus.BARRICA:
			if hi_ha_barra or hi_ha_seient or hi_ha_deco:
				return "La barrica necessita la cel·la buida"
		_:
			if hi_ha_barrica:
				return "Aquí hi ha una barrica"
	match _tipus(moble_preview):
		MobleBarra.Tipus.DECORACIO, MobleBarra.Tipus.BARRA:
			if hi_ha_seient:
				return "Aquí hi ha una cadira"
		MobleBarra.Tipus.SEIENT:
			if hi_ha_barra or hi_ha_deco:
				return "Aquí no hi cap una cadira"
	return ""

## `des_de_clic` = true si és un clic; false si s'està pintant arrossegant.
func col_locar_moble(des_de_clic: bool):
	if moble_preview == null or posicio_preview == null:
		return
	var pos: Vector3 = posicio_preview
	ultima_posicio_pintada = pos

	var motiu := _motiu_bloqueig(pos)
	if not motiu.is_empty():
		if des_de_clic:   # pintant no molestem amb avisos a cada cel·la
			_mostrar_avis(motiu)
		return

	# Si ja hi ha un moble del mateix tipus, el substitueix
	var tipus := _tipus(moble_preview)
	var escena := mobles_disponibles[index_preview]
	var vell := buscar_moble_a_posicio(pos, _grup_principal(tipus))
	if vell:
		var mateix_moble := vell.scene_file_path == escena.resource_path
		if mateix_moble and int(round(vell.rotation_degrees.y - rotacio_preview)) % 360 == 0:
			return   # ja hi és exactament igual, no cal fer res
		_treure_moble(vell)

	var avis := _avis_col_locacio(pos)
	if des_de_clic and not avis.is_empty():
		_mostrar_avis(avis)

	var moble: Node3D = escena.instantiate()
	_afegir_grups(moble, tipus)
	add_child(moble)
	moble.global_position = pos
	moble.rotation_degrees.y = rotacio_preview
	call_deferred("_actualitzar_taules")

	# Petit "pop" en aparèixer
	moble.scale = Vector3.ONE * 0.8
	moble.create_tween().tween_property(moble, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func buscar_moble_a_posicio(posicio: Vector3, grup: String) -> Node3D:
	for moble in get_tree().get_nodes_in_group(grup):
		if moble.is_queued_for_deletion():
			continue
		if round(moble.global_position.x / grid_size) == round(posicio.x / grid_size) \
		and round(moble.global_position.z / grid_size) == round(posicio.z / grid_size):
			return moble
	return null

func _tipus(moble: Node) -> MobleBarra.Tipus:
	if moble is MobleBarra:
		return moble.tipus
	return MobleBarra.Tipus.SEIENT

func _grup_principal(tipus: MobleBarra.Tipus) -> String:
	match tipus:
		MobleBarra.Tipus.BARRA:
			return "barres"
		MobleBarra.Tipus.DECORACIO:
			return "decoracio"
		MobleBarra.Tipus.BARRICA:
			return "barriques"
	return "mobles_reposats"

func _afegir_grups(moble: Node, tipus: MobleBarra.Tipus):
	if tipus == MobleBarra.Tipus.DECORACIO:
		moble.add_to_group("decoracio")
	else:
		moble.add_to_group("mobles_base")
		moble.add_to_group(_grup_principal(tipus))

## Treu un moble del joc de seguida (dels grups ja) i l'esborra al final del frame.
func _treure_moble(moble: Node3D):
	for grup in moble.get_groups():
		if not str(grup).begins_with("_"):
			moble.remove_from_group(grup)
	moble.queue_free()

# ─────────────────────────────────────────────── Esborrar

func activar_mode_eliminacio():
	mode_eliminacio = true
	pintant = false
	if moble_preview:
		moble_preview.visible = false
	_actualitzar_hud()

func desactivar_mode_eliminacio():
	mode_eliminacio = false
	if is_instance_valid(moble_hovered):
		restaurar_materials(moble_hovered)
	moble_hovered = null
	_actualitzar_hud()

func actualitzar_hover_eliminacio():
	var ratoli := get_viewport().get_mouse_position()
	var camera := get_viewport().get_camera_3d()
	var origen := camera.project_ray_origin(ratoli)
	var query := PhysicsRayQueryParameters3D.create(origen, origen + camera.project_ray_normal(ratoli) * 100.0)
	query.exclude = _rids_parets()
	var resultat := get_world_3d().direct_space_state.intersect_ray(query)

	var moble: Node3D = null
	if not resultat.is_empty() and resultat.collider:
		moble = obtenir_moble_desde_collider(resultat.collider)

	if moble == moble_hovered:
		return
	if is_instance_valid(moble_hovered):
		restaurar_materials(moble_hovered)
	moble_hovered = moble
	if moble_hovered:
		canviar_color_moble(moble_hovered)

func obtenir_moble_desde_collider(collider: Node) -> Node3D:
	var node := collider
	while node and node != self:
		if node.is_in_group("mobles_base") or node.is_in_group("decoracio"):
			return node
		node = node.get_parent()
	return null

func eliminar_moble(moble: Node3D):
	if not is_instance_valid(moble):
		return
	if moble == moble_hovered:
		moble_hovered = null
	_treure_moble(moble)
	call_deferred("_actualitzar_taules")

func canviar_color_moble(moble: Node3D):
	_per_cada_malla(moble, func(m: GeometryInstance3D): m.material_override = material_hover)

func restaurar_materials(moble: Node3D):
	_per_cada_malla(moble, func(m: GeometryInstance3D): m.material_override = null)

# ─────────────────────────────────────────────── Utilitats

func _per_cada_malla(node: Node, accio: Callable):
	for fill in node.get_children():
		if fill is GeometryInstance3D:
			accio.call(fill)
		_per_cada_malla(fill, accio)

func _desactivar_colisions(node: Node):
	if node is CollisionObject3D:
		node.collision_layer = 0
		node.collision_mask = 0
	for fill in node.get_children():
		_desactivar_colisions(fill)

# ─────────────────────────────────────────────── Desar / carregar

func guardar_decoracio():
	var mobles_data = []
	var mobles = get_tree().get_nodes_in_group("mobles_base") + get_tree().get_nodes_in_group("decoracio")
	for moble in mobles:
		if moble == moble_preview or moble.is_queued_for_deletion():
			continue
		mobles_data.append({
			"index": obtenir_index_moble(moble),
			"scene_path": moble.scene_file_path,
			"posicio": {"x": moble.global_position.x, "y": moble.global_position.y, "z": moble.global_position.z},
			"rotacio": {"x": moble.rotation.x, "y": moble.rotation.y, "z": moble.rotation.z},
		})

	var dades := {
		"mobles": mobles_data,
		"terra": terra_actual,
		"parets": parets_actual,
		"acabats_comprats": acabats_comprats,
	}
	var fitxer = FileAccess.open("user://casa_interior_mobles.save", FileAccess.WRITE)
	if fitxer:
		fitxer.store_string(JSON.stringify(dades))
		print("Decoració guardada! (", mobles_data.size(), " mobles)")
	else:
		push_error("No es pot guardar la decoració")

func carregar_decoracio():
	var fitxer = FileAccess.open("user://casa_interior_mobles.save", FileAccess.READ)
	if not fitxer:
		print("Cap decoració guardada prèviament")
		return

	var dades = JSON.parse_string(fitxer.get_as_text())
	var mobles_data = []
	if dades is Array:
		mobles_data = dades   # format antic: només mobles
	elif dades is Dictionary:
		mobles_data = dades.get("mobles", [])
		terra_actual = _id_valid(dades.get("terra", ""), CatalegAcabats.TERRA_PER_DEFECTE)
		parets_actual = _id_valid(dades.get("parets", ""), CatalegAcabats.PARET_PER_DEFECTE)
		acabats_comprats = dades.get("acabats_comprats", [])
	else:
		push_error("El fitxer de decoració està malmès")
		return

	for data in mobles_data:
		if not data is Dictionary:
			continue
		var escena := _escena_des_de_dades(data)
		if escena == null:
			push_warning("No s'ha pogut carregar un moble: " + str(data))
			continue

		var moble: Node3D = escena.instantiate()
		_afegir_grups(moble, _tipus(moble))
		add_child(moble)

		var p = data.get("posicio")
		var r = data.get("rotacio")
		if p is Dictionary and r is Dictionary:
			moble.global_position = Vector3(p.get("x", 0), p.get("y", 0), p.get("z", 0))
			moble.rotation = Vector3(r.get("x", 0), r.get("y", 0), r.get("z", 0))

	print("Decoració carregada! (", mobles_data.size(), " mobles)")

func _escena_des_de_dades(data: Dictionary) -> PackedScene:
	var path = data.get("scene_path", "")
	if path is String and not path.is_empty() and ResourceLoader.exists(path):
		var recurs = load(path)
		if recurs is PackedScene:
			return recurs
	var index = int(data.get("index", -1))
	if index >= 0 and index < mobles_disponibles.size():
		return mobles_disponibles[index]
	return null

func obtenir_index_moble(moble: Node) -> int:
	for i in mobles_disponibles.size():
		if mobles_disponibles[i] and mobles_disponibles[i].resource_path == moble.scene_file_path:
			return i
	return -1

# ─────────────────────────────────────────────── Sortir

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar_decoracio()
		get_tree().quit()

func _on_salir_casa():
	if mode_construccio:
		sortir_mode_construccio()
	gestor_servei.tancar()
	guardar_decoracio()
	call_deferred("change_scene_to_world")

func change_scene_to_world():
	get_tree().change_scene_to_file("res://Scenes/World.tscn")
