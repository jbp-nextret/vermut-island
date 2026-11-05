extends CanvasLayer
## Mapa del món (autoload). M l'obre i el tanca (Esc també tanca). Atura el joc.
##
##  - El terreny es dibuixa a partir del GridMap (1 píxel = 1 metre), amb el nord a dalt.
##  - Només es veu el que s'ha explorat: mentre camines (o navegues) es va destapant un
##    cercle al teu voltant. L'exploració es desa a user://mapa.save.
##  - Marca on ets, cap on mira la càmera, casa, la barca, els NPC que ja has vist i
##    els objectius de les missions actives (encara que siguin en zona per explorar).
##  - Roda: zoom. Arrossegar: moure. Clic a una missió de la llista: hi centra el mapa.

const FITXER := "user://mapa.save"
const MIDA := 128                 # metres de costat del mapa (de -64 a 63)
const ORIGEN := Vector2i(64, 64)  # cel·la (0, 0) del món dins la imatge
const RADI_VISTA := 11.0          # metres que es destapen al voltant del jugador
const RADI_INICIAL := 16.0        # el primer cop: el voltant de casa

# Colors del terreny
const C_MAR_FONS := Color(0.16, 0.36, 0.62)
const C_MAR_SOM := Color(0.27, 0.58, 0.78)
const C_SORRA := Color(0.93, 0.84, 0.58)
const C_HERBA := Color(0.42, 0.72, 0.33)
const C_TERRA := Color(0.55, 0.38, 0.22)
const C_ALTRES := Color(0.62, 0.62, 0.6)
const C_ARBRE := Color(0.18, 0.42, 0.2)
const C_ROCA := Color(0.5, 0.5, 0.52)
const C_CULTIU := Color(0.9, 0.75, 0.25)
const C_BOIRA := Color(0.09, 0.1, 0.16)

var explorat := Image.create(MIDA, MIDA, false, Image.FORMAT_L8)
var canvis := false
var temps_explorar := 0.0

# El que es veu al mapa (es guarda l'últim per quan s'obre des de dins de casa)
var textura_terreny: ImageTexture
var textura_boira: ImageTexture
var marcadors := []        # [{tipus, pos: Vector2, text, color}]
var pos_jugador := Vector2.ZERO
var dir_camera := Vector2.UP
var a_casa := false

var vista: Control
var llista_missions: VBoxContainer
var titol_lloc: Label

func _ready():
	layer = 49
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_carregar()
	_construir_ui()

# ─────────────── Exploració

func _process(delta):
	if get_tree().paused:
		return
	temps_explorar -= delta
	if temps_explorar > 0.0:
		return
	temps_explorar = 0.2
	var jugador := _jugador_al_mon()
	if jugador:
		destapar(jugador.global_position, RADI_VISTA)

func _jugador_al_mon() -> Node3D:
	var mon := get_tree().current_scene
	if mon == null or mon.get_node_or_null("GridMap") == null:
		return null
	return get_tree().get_first_node_in_group("player") as Node3D

## Destapa un cercle (amb la vora suau) al voltant d'un punt del món
func destapar(punt: Vector3, radi: float):
	var c := Vector2(punt.x, punt.z) + Vector2(ORIGEN)
	var r := ceili(radi + 2.0)
	for y in range(maxi(0, int(c.y) - r), mini(MIDA, int(c.y) + r + 1)):
		for x in range(maxi(0, int(c.x) - r), mini(MIDA, int(c.x) + r + 1)):
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d > radi + 2.0:
				continue
			var valor := clampf((radi + 2.0 - d) / 2.0, 0.0, 1.0)
			var actual := explorat.get_pixel(x, y).r
			if valor > actual + 0.01:
				explorat.set_pixel(x, y, Color(valor, valor, valor))
				canvis = true

func explorat_a(punt: Vector2) -> bool:
	var p := Vector2i(floori(punt.x), floori(punt.y)) + ORIGEN
	if p.x < 0 or p.y < 0 or p.x >= MIDA or p.y >= MIDA:
		return false
	return explorat.get_pixelv(p).r > 0.5

# ─────────────── Desat

func guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f == null:
		return
	var dades := explorat.get_data().compress(FileAccess.COMPRESSION_ZSTD)
	f.store_string(JSON.stringify({"mida": MIDA, "explorat": Marshalls.raw_to_base64(dades)}))
	canvis = false

func _carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		destapar(Vector3(-5, 0, -13), RADI_INICIAL)   # casa
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary and int(d.get("mida", 0)) == MIDA:
		var dades := Marshalls.base64_to_raw(d.explorat).decompress(MIDA * MIDA, FileAccess.COMPRESSION_ZSTD)
		if dades.size() == MIDA * MIDA:
			explorat = Image.create_from_data(MIDA, MIDA, false, Image.FORMAT_L8, dades)

# ─────────────── Obrir / tancar

func _unhandled_input(event: InputEvent):
	if visible:
		if event.is_action_pressed("mapa") or event.is_action_pressed("ui_cancel"):
			tancar()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("mapa") and MenuPausa.en_partida() and not MenuPausa.visible:
		obrir()
		get_viewport().set_input_as_handled()

func obrir():
	if visible or not MenuPausa.en_partida() or GameState.en_dialeg or MenuInventari.visible or MenuHabilitats.visible or (has_node("/root/Bestiari") and get_node("/root/Bestiari").visible):
		return
	_actualitzar_dades()
	visible = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	vista.centrar(pos_jugador)
	_omplir_missions()

func tancar():
	visible = false
	get_tree().paused = false
	guardar()

# ─────────────── Dades del mapa

func _actualitzar_dades():
	var mon := get_tree().current_scene
	var gridmap: GridMap = mon.get_node_or_null("GridMap") if mon else null
	a_casa = gridmap == null
	titol_lloc.text = "Ets a casa" if a_casa else ""
	if gridmap:
		textura_terreny = ImageTexture.create_from_image(_imatge_terreny(mon, gridmap))
		marcadors = _marcadors(mon)
		var jugador := get_tree().get_first_node_in_group("player") as Node3D
		if jugador:
			pos_jugador = Vector2(jugador.global_position.x, jugador.global_position.z)
		var camera := get_viewport().get_camera_3d()
		if camera:
			var cap := -camera.global_basis.z
			dir_camera = Vector2(cap.x, cap.z).normalized()
	else:
		# Des de dins de casa: el mapa de l'última vegada, amb tu a casa
		if textura_terreny == null:
			textura_terreny = ImageTexture.create_from_image(Image.create(MIDA, MIDA, false, Image.FORMAT_RGBA8))
		for mk in marcadors:
			if mk.tipus == "casa":
				pos_jugador = mk.pos
	_actualitzar_missions_marcadors(mon)
	textura_boira = ImageTexture.create_from_image(_imatge_boira())

func _imatge_terreny(mon: Node, gridmap: GridMap) -> Image:
	var img := Image.create(MIDA, MIDA, false, Image.FORMAT_RGBA8)
	img.fill(C_MAR_FONS)
	var lib := gridmap.mesh_library
	var plantables: Array = mon.get("blocs_plantables") if "blocs_plantables" in mon else []
	var dalt := {}   # Vector2i -> cel·la més alta
	for c in gridmap.get_used_cells():
		var k := Vector2i(c.x, c.z)
		if not dalt.has(k) or c.y > dalt[k].y:
			dalt[k] = c
	for k in dalt:
		var p: Vector2i = k + ORIGEN
		if p.x < 0 or p.y < 0 or p.x >= MIDA or p.y >= MIDA:
			continue
		var c: Vector3i = dalt[k]
		var color := C_MAR_SOM
		if c.y >= 0:
			var nom := lib.get_item_name(gridmap.get_cell_item(c))
			if nom in plantables or ("llaurades" in mon and mon.llaurades.has(c)):
				color = C_TERRA
			elif nom.begins_with("cube-top") or nom.begins_with("cube-side") or nom.begins_with("cube-corner"):
				color = C_HERBA
			else:
				color = C_ALTRES
			color = color.lightened(clampf(c.y * 0.12, 0.0, 0.4))
		elif c.y == -1:
			color = C_SORRA
		# Una mica de textura perquè no sigui pla del tot
		var soroll := float(hash(k) % 100) / 100.0
		img.set_pixelv(p, color.darkened(soroll * 0.06))
	# Vores: una línia més fosca on l'herba toca la sorra o l'aigua
	var copia := img.duplicate() as Image
	for y in range(1, MIDA - 1):
		for x in range(1, MIDA - 1):
			var k := Vector2i(x, y) - ORIGEN
			if not dalt.has(k) or dalt[k].y < 0:
				continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var vei: Vector2i = k + v
				if not dalt.has(vei) or dalt[vei].y < 0:
					img.set_pixel(x, y, copia.get_pixel(x, y).darkened(0.25))
					break
	# Arbres, roques i cultius
	for r in get_tree().get_nodes_in_group("recursos"):
		if r is RecursNatural and r.tipus != RecursNatural.Tipus.HERBA and r.visible:
			_punt(img, r.global_position, C_ARBRE if r.tipus == RecursNatural.Tipus.ARBRE else C_ROCA)
	for c in get_tree().get_nodes_in_group("cultius"):
		_punt(img, c.global_position, C_CULTIU)
	# El moll
	for m in get_tree().get_nodes_in_group("moll"):
		for fill in m.get_children():
			if fill is CollisionShape3D and not fill.disabled and fill.shape is BoxShape3D:
				var mida: Vector3 = fill.shape.size
				var centre: Vector3 = fill.global_position
				for dx in range(-int(mida.x / 2), int(mida.x / 2) + 1):
					for dz in range(-int(mida.z / 2), int(mida.z / 2) + 1):
						_punt(img, centre + Vector3(dx, 0, dz), Color(0.62, 0.43, 0.25))
	return img

func _punt(img: Image, pos: Vector3, color: Color):
	var p := Vector2i(floori(pos.x), floori(pos.z)) + ORIGEN
	if p.x >= 0 and p.y >= 0 and p.x < MIDA and p.y < MIDA:
		img.set_pixelv(p, color)

## Boira: fosca on no s'ha explorat, transparent on sí. Es fa al doble de resolució
## (amb la vora suavitzada i una mica de gra) perquè no es vegin els quadres de metre.
func _imatge_boira() -> Image:
	const ESCALA := 2
	var mascara := explorat.duplicate() as Image
	mascara.resize(MIDA * ESCALA, MIDA * ESCALA, Image.INTERPOLATE_BILINEAR)
	var img := Image.create(MIDA * ESCALA, MIDA * ESCALA, false, Image.FORMAT_RGBA8)
	for y in MIDA * ESCALA:
		for x in MIDA * ESCALA:
			var e := mascara.get_pixel(x, y).r
			var gra := float(hash(Vector2i(x, y)) % 100) / 100.0 - 0.5
			var vora := 1.0 - absf(e * 2.0 - 1.0)   # 1 a la meitat de la transició
			var alfa := clampf(1.0 - e * 1.2 + gra * 0.35 * vora, 0.0, 1.0)
			img.set_pixel(x, y, Color(C_BOIRA.r, C_BOIRA.g, C_BOIRA.b, alfa))
	return img

## Casa, barca i NPC (els que ja s'han vist, és a dir, en zona explorada)
func _marcadors(mon: Node) -> Array:
	var llista := []
	var casa := mon.get_node_or_null("Casa") as Node3D
	if casa:
		llista.append({"tipus": "casa", "pos": _pla(casa.global_position), "text": "Casa"})
	for b in get_tree().get_nodes_in_group("barques"):
		if b.visible:
			llista.append({"tipus": "barca", "pos": _pla(b.global_position), "text": "Barca"})
	for npc in get_tree().get_nodes_in_group("npcs"):
		llista.append({"tipus": "npc", "pos": _pla(npc.global_position), "text": npc.nom, "id": npc.id,
			"marca": Missions.marcador_npc(npc.id)})
	# Amb la brúixola de tresors: on hi ha punts d'excavació (i de quina raresa)
	var punts = mon.get("punts_excavacio")
	if punts and Inventari.tenir("bruixola_tresors") > 0:
		for cella in punts.punts:
			llista.append({"tipus": "tresor", "pos": Vector2(cella.x + 0.5, cella.z + 0.5), "raresa": punts.punts[cella].boti.raresa})
	# Taula de fabricació i corrals
	for t in get_tree().get_nodes_in_group("taula_fabricacio"):
		llista.append({"tipus": "taula", "pos": _pla(t.global_position), "text": "Taula"})
	# Les criatures de cada illa: la seva icona si ja l'has vista, "?" si no
	var generador = mon.get("generador_criatures")
	if generador:
		for z in generador.zones:
			var ids := []
			for c in z.criatures:
				if is_instance_valid(c) and c.is_in_group("criatures_salvatges") and not c.especie.id in ids:
					ids.append(c.especie.id)
			if not ids.is_empty():
				ids.sort_custom(func(a, b): return Criatures.especie(a).forca < Criatures.especie(b).forca)
				llista.append({"tipus": "criatures", "pos": generador.centre_zona(z), "especies": ids})
	return llista

## Els objectius de les missions actives que són en algun lloc concret
func _actualitzar_missions_marcadors(mon: Node):
	marcadors = marcadors.filter(func(m): return m.tipus != "objectiu")
	for m in Missions.missions_actives():
		var pos = posicio_missio(m)
		if pos != null:
			marcadors.append({"tipus": "objectiu", "pos": pos, "text": m.titol, "id": m.id})

## On s'ha d'anar per avançar la missió (o null si no és a cap lloc concret)
func posicio_missio(m: Missio):
	if Missions.pot_lliurar(m.id):
		return _pos_npc(m.donant)
	for i in m.objectius.size():
		var o: ObjectiuMissio = m.objectius[i]
		if Missions.progres(m.id, i) >= o.objectiu():
			continue
		match o.tipus:
			ObjectiuMissio.Tipus.PARLAR:
				return _pos_npc(o.npc)
			ObjectiuMissio.Tipus.ARRIBAR:
				for z in get_tree().get_nodes_in_group("zones_missio"):
					if z.id == o.lloc:
						return _pla(z.global_position)
	return null

func _pos_npc(id: String):
	for mk in marcadors:
		if mk.tipus == "npc" and mk.get("id", "") == id:
			return mk.pos
	return null

static func _pla(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)

# ─────────────── Interfície

func _construir_ui():
	var fons := ColorRect.new()
	fons.color = Color(0.02, 0.02, 0.05, 0.6)
	fons.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fons)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var caixa := PanelContainer.new()
	caixa.theme = EstilMenus.tema()
	caixa.add_theme_stylebox_override("panel", EstilMenus.caixa_fons())
	centre.add_child(caixa)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 10)
	caixa.add_child(columna)

	var capcalera := HBoxContainer.new()
	columna.add_child(capcalera)
	var titol := Label.new()
	titol.text = "🗺️ Mapa"
	titol.add_theme_font_size_override("font_size", 28)
	capcalera.add_child(titol)
	titol_lloc = Label.new()
	titol_lloc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titol_lloc.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	titol_lloc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	capcalera.add_child(titol_lloc)
	var boto_centrar := Button.new()
	boto_centrar.text = "Centrar"
	boto_centrar.pressed.connect(func(): vista.centrar(pos_jugador))
	capcalera.add_child(boto_centrar)
	var tancar_boto := Button.new()
	tancar_boto.text = "Tancar (%s)" % SettingsManager.tecla_de("mapa")
	tancar_boto.pressed.connect(tancar)
	capcalera.add_child(tancar_boto)

	var cos := HBoxContainer.new()
	cos.add_theme_constant_override("separation", 14)
	columna.add_child(cos)
	vista = VistaMapa.new()
	vista.mapa = self
	vista.custom_minimum_size = Vector2(720, 540)
	cos.add_child(vista)

	var lateral := VBoxContainer.new()
	lateral.custom_minimum_size = Vector2(270, 0)
	lateral.add_theme_constant_override("separation", 8)
	cos.add_child(lateral)
	var t := Label.new()
	t.text = "Missions"
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	lateral.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lateral.add_child(scroll)
	llista_missions = VBoxContainer.new()
	llista_missions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	llista_missions.add_theme_constant_override("separation", 6)
	scroll.add_child(llista_missions)
	var llegenda := Label.new()
	llegenda.text = "◆ objectiu   ● tu   ⌂ casa\n! missió nova   ? per lliurar\n(?) criatura per descobrir\nRoda: zoom · Arrossega: moure"
	llegenda.add_theme_font_size_override("font_size", 14)
	llegenda.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	lateral.add_child(llegenda)

func _omplir_missions():
	for fill in llista_missions.get_children():
		fill.queue_free()
	var actives := Missions.missions_actives()
	if actives.is_empty():
		var l := Label.new()
		l.text = "Cap missió activa.\nParla amb la gent de l'illa!"
		l.add_theme_font_size_override("font_size", 15)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		llista_missions.add_child(l)
		return
	for m in actives:
		var boto := Button.new()
		boto.alignment = HORIZONTAL_ALIGNMENT_LEFT
		boto.autowrap_mode = TextServer.AUTOWRAP_WORD
		boto.custom_minimum_size = Vector2(250, 0)
		var pos = null
		for mk in marcadors:
			if mk.tipus == "objectiu" and mk.id == m.id:
				pos = mk.pos
		var linies: Array[String] = [("◆ " if pos != null else "") + m.titol]
		for i in m.objectius.size():
			var o: ObjectiuMissio = m.objectius[i]
			var fet := Missions.progres(m.id, i) >= o.objectiu()
			linies.append(("   ✓ " if fet else "   · ") + o.text(Missions.progres(m.id, i)))
		if Missions.pot_lliurar(m.id):
			linies.append("   → Torna-hi per lliurar-la")
		boto.text = "\n".join(linies)
		boto.add_theme_font_size_override("font_size", 14)
		if pos != null:
			boto.pressed.connect(func(): vista.centrar(pos, true))
		else:
			boto.disabled = true
			boto.tooltip_text = "Aquesta missió no és en cap lloc concret"
		llista_missions.add_child(boto)
