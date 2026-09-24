extends Node3D

const LIMIT_SALA := 4               # cel·les de -4 a 4 (a ±5 hi ha les parets)
const CAPA_TERRA := 1 << 1          # capa de col·lisió 2 ("terra")
const ALFA_PREVIEW := 0.45          # 0 = opac, 1 = invisible
const DISTANCIA_ENTRADA := 0.9      # espai lliure davant la porta dels clients

# Mobles
@export var mobles_disponibles: Array[PackedScene]
@export var noms_mobles: Array[String] = ["Barra Normal", "Barra Mig", "Barra Lateral", "Cadira", "Rosa", "Cactus", "Amapola"]
@export var grid_size: float = 1.0

var mode_construccio := false
var mode_eliminacio := false
var moble_preview: Node3D = null
var posicio_preview: Variant = null   # Vector3 o null si el ratolí no apunta a terra
var preview_valida := false
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

# HUD (es crea per codi)
var boto_construir: Button
var boto_vermuteria: Button
var label_ajuda: Label
var label_avis: Label
var tween_avis: Tween

var gestor_servei: GestorServei

# Materials
var material_hover := StandardMaterial3D.new()
var material_preview_ok := StandardMaterial3D.new()
var material_preview_ko := StandardMaterial3D.new()
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

	panel_ui.visible = false
	item_list.visible = false
	carregar_decoracio()
	_actualitzar_hud()

func _exit_tree():
	GameState.dins_casa = false
	GameState.mode = GameState.Mode.EXPLORAR

func _configurar_materials():
	material_hover.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_hover.albedo_color = Color(1, 0, 0, 0.8)

	for m in [material_preview_ok, material_preview_ko, material_grid]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_preview_ok.albedo_color = Color(0.35, 1.0, 0.45, 0.35)
	material_preview_ko.albedo_color = Color(1.0, 0.25, 0.25, 0.45)
	material_grid.albedo_color = Color(1, 1, 1, 0.35)

func _configurar_llista_mobles():
	item_list.clear()
	for nom in noms_mobles:
		item_list.add_item(nom)
	# Sense focus: si no, la llista es "menja" la Q i la E (cerca per lletra)
	item_list.focus_mode = Control.FOCUS_NONE
	item_list.position = Vector2(12, 70)
	item_list.size = Vector2(200, 230)
	item_list.item_selected.connect(_on_moble_seleccionat)

func _crear_gestor_servei():
	gestor_servei = GestorServei.new()
	gestor_servei.name = "GestorServei"
	gestor_servei.porta = porta_clients
	add_child(gestor_servei)
	gestor_servei.servei_obert.connect(_actualitzar_hud)
	gestor_servei.servei_tancat.connect(_actualitzar_hud)
	gestor_servei.temps_actualitzat.connect(_on_temps_servei)

# ─────────────────────────────────────────────── Sala

func crear_interior():
	# Sòl
	var sol_static = StaticBody3D.new()
	sol_static.name = "Sol"
	# Capa 1 perquè el jugador hi camini, capa 2 perquè el raig de construcció només vegi el terra
	sol_static.collision_layer = 1 | CAPA_TERRA
	add_child(sol_static)

	var sol_mesh = MeshInstance3D.new()
	sol_mesh.mesh = PlaneMesh.new()
	sol_mesh.mesh.size = Vector2(10, 10)
	sol_static.add_child(sol_mesh)

	var material_sol = StandardMaterial3D.new()
	material_sol.albedo_color = Color(0.8, 0.7, 0.6)
	sol_mesh.set_surface_override_material(0, material_sol)

	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = Vector3(10, 0.2, 10)
	collision.position.y = -0.1
	sol_static.add_child(collision)

	# Parets
	crear_paret("Paret Fons", Vector3(0, 0, -5), Vector3(10, 3, 0.2))
	crear_paret("Paret Esquerra", Vector3(-5, 0, 0), Vector3(0.2, 3, 10))
	crear_paret("Paret Dreta", Vector3(5, 0, 0), Vector3(0.2, 3, 10))

	crear_finestra(Vector3(0, 1.5, -5), Vector3(2, 1.5, 0.1))
	crear_porta_visual(Vector3(5, 0, 2), Vector3(0.1, 2, 1))

func crear_paret(nom: String, posicio: Vector3, mida: Vector3):
	var paret_static = StaticBody3D.new()
	paret_static.position = posicio
	paret_static.name = nom
	add_child(paret_static)

	var paret_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = mida
	paret_mesh.mesh = box
	paret_static.add_child(paret_mesh)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.85, 0.8)
	paret_mesh.set_surface_override_material(0, material)

	var collision = CollisionShape3D.new()
	collision.shape = BoxShape3D.new()
	collision.shape.size = mida
	paret_static.add_child(collision)

func crear_finestra(posicio: Vector3, mida: Vector3):
	var finestra = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = mida
	finestra.mesh = box
	finestra.position = posicio
	finestra.name = "Finestra"
	add_child(finestra)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.5, 0.7, 1.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	finestra.set_surface_override_material(0, material)

func crear_porta_visual(posicio: Vector3, mida: Vector3):
	var porta = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = mida
	porta.mesh = box
	porta.position = posicio
	porta.name = "PortaVisual"
	add_child(porta)

	var material = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.0)
	material.emission = Color(0.8, 0.6, 0.0)
	material.emission_energy_multiplier = 2.0
	porta.set_surface_override_material(0, material)

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
	boto_vermuteria.pressed.connect(func(): gestor_servei.alternar())
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
	else:
		boto_vermuteria.text = "Obrir vermuteria"
	boto_vermuteria.disabled = not gestor_servei.obert and not GameState.pot_obrir_vermuteria()

	if not mode_construccio:
		label_ajuda.text = ""
	elif mode_eliminacio:
		label_ajuda.text = "Clic esquerre: esborrar   ·   Clic dret / Esc: tornar a col·locar"
	else:
		label_ajuda.text = "Clic esquerre: col·locar (mantén per pintar)   ·   Q/E: girar   ·   Clic dret: esborrar   ·   Roda: zoom   ·   Botó central: girar càmera   ·   Esc: sortir"

func _on_temps_servei(segons: float):
	var s := int(ceil(segons))
	boto_vermuteria.text = "Tancar vermuteria  %d:%02d" % [floori(s / 60.0), s % 60]

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
				if mode_eliminacio:
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
				if event.pressed:
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
	mostrar_grid()

	# Càmera pròpia, perquè no toqui la del jugador
	camera_anterior = get_viewport().get_camera_3d()
	camera_construccio.make_current()
	actualitzar_posicio_camera()

	if index_preview >= 0:
		_crear_preview()
	_actualitzar_hud()

func sortir_mode_construccio():
	mode_construccio = false
	pintant = false
	desactivar_mode_eliminacio()
	_eliminar_preview()
	panel_ui.visible = false
	item_list.visible = false
	amagar_grid()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if is_instance_valid(camera_anterior):
		camera_anterior.make_current()
	camera_anterior = null

	GameState.mode = GameState.Mode.EXPLORAR
	guardar_decoracio()
	_actualitzar_hud()

func actualitzar_posicio_camera():
	var pos_x = sin(camera_rotation_y) * cos(camera_rotation_x) * camera_distance
	var pos_y = camera_height + sin(camera_rotation_x) * camera_distance
	var pos_z = cos(camera_rotation_y) * cos(camera_rotation_x) * camera_distance
	camera_construccio.global_position = Vector3(pos_x, pos_y, pos_z)
	camera_construccio.look_at(Vector3.ZERO, Vector3.UP)

func _process(delta):
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
	preview_valida = false
	_pintar_preview(true)

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

	var valida := _motiu_bloqueig(posicio_preview).is_empty()
	if valida != preview_valida:
		preview_valida = valida
		_pintar_preview(valida)

func _pintar_preview(valida: bool):
	var material := material_preview_ok if valida else material_preview_ko
	_per_cada_malla(moble_preview, func(m: GeometryInstance3D): m.material_overlay = material)

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

	var moble: Node3D = escena.instantiate()
	_afegir_grups(moble, tipus)
	add_child(moble)
	moble.global_position = pos
	moble.rotation_degrees.y = rotacio_preview

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

	var fitxer = FileAccess.open("user://casa_interior_mobles.save", FileAccess.WRITE)
	if fitxer:
		fitxer.store_string(JSON.stringify(mobles_data))
		print("Decoració guardada! (", mobles_data.size(), " mobles)")
	else:
		push_error("No es pot guardar la decoració")

func carregar_decoracio():
	var fitxer = FileAccess.open("user://casa_interior_mobles.save", FileAccess.READ)
	if not fitxer:
		print("Cap decoració guardada prèviament")
		return

	var mobles_data = JSON.parse_string(fitxer.get_as_text())
	if not mobles_data is Array:
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
