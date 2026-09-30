extends CanvasLayer
## Motxilla (autoload): I l'obre i la tanca (també Esc per tancar). Atura el joc.
## A l'esquerra, els objectes que portes; a la dreta, l'estat de la partida: hora i dia,
## el temps (i el d'demà), l'onada d'aquesta nit i la setmana, el servei de la vermuteria
## i l'hort.

const COLS := 5
const DIES_CURTS := ["Dl", "Dt", "Dc", "Dj", "Dv", "Ds", "Dg"]
const MIDA_CASELLA := Vector2(78, 78)

var caixa: PanelContainer
var graella: GridContainer
var descripcio: RichTextLabel
var estat: RichTextLabel
var seleccionat := ""

func _ready():
	layer = 49
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	var fons := ColorRect.new()
	fons.color = Color(0.02, 0.02, 0.05, 0.55)
	fons.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fons)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	caixa = PanelContainer.new()
	caixa.theme = EstilMenus.tema()
	caixa.add_theme_stylebox_override("panel", EstilMenus.caixa_fons())
	centre.add_child(caixa)
	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	caixa.add_child(columna)

	var capcalera := HBoxContainer.new()
	columna.add_child(capcalera)
	var titol := Label.new()
	titol.text = "🎒 Motxilla"
	titol.add_theme_font_size_override("font_size", 28)
	titol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	capcalera.add_child(titol)
	var tancar_boto := Button.new()
	tancar_boto.text = "Tancar (%s)" % SettingsManager.tecla_de("inventari")
	tancar_boto.pressed.connect(tancar)
	capcalera.add_child(tancar_boto)

	var cos := HBoxContainer.new()
	cos.add_theme_constant_override("separation", 18)
	columna.add_child(cos)

	# Esquerra: objectes
	var esquerra := VBoxContainer.new()
	esquerra.add_theme_constant_override("separation", 10)
	cos.add_child(esquerra)
	esquerra.add_child(_titol_seccio("Objectes"))
	graella = GridContainer.new()
	graella.columns = COLS
	graella.add_theme_constant_override("h_separation", 6)
	graella.add_theme_constant_override("v_separation", 6)
	esquerra.add_child(graella)
	descripcio = _text_ric(Vector2(COLS * (MIDA_CASELLA.x + 6), 90))
	esquerra.add_child(descripcio)

	# Dreta: estat de la partida
	var dreta := VBoxContainer.new()
	dreta.add_theme_constant_override("separation", 10)
	cos.add_child(dreta)
	dreta.add_child(_titol_seccio("La partida"))
	estat = _text_ric(Vector2(400, 460))
	dreta.add_child(estat)

func _titol_seccio(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.55))
	return l

func _text_ric(mida: Vector2) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = false
	r.scroll_active = true
	r.custom_minimum_size = mida
	r.add_theme_font_size_override("normal_font_size", 16)
	r.add_theme_font_size_override("bold_font_size", 16)
	var fons := StyleBoxFlat.new()
	fons.bg_color = Color(0, 0, 0, 0.25)
	fons.set_corner_radius_all(6)
	fons.set_content_margin_all(10)
	r.add_theme_stylebox_override("normal", fons)
	return r

# ─────────────── Obrir / tancar

func _unhandled_input(event: InputEvent):
	if visible:
		if event.is_action_pressed("inventari") or event.is_action_pressed("ui_cancel"):
			tancar()
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventari") and MenuPausa.en_partida() and not MenuPausa.visible:
		obrir()
		get_viewport().set_input_as_handled()

func obrir():
	if visible or not MenuPausa.en_partida():
		return
	visible = true
	Engine.time_scale = 1.0
	get_tree().paused = true
	_omplir_objectes()
	_omplir_estat()

func tancar():
	visible = false
	get_tree().paused = false

# ─────────────── Objectes

func _omplir_objectes():
	for fill in graella.get_children():
		fill.queue_free()
	var llista := [["diners", Inventari.diners]]
	var ids: Array = Inventari.items.keys()
	ids.sort()
	for id in ids:
		if Inventari.items[id] > 0:
			llista.append([id, Inventari.items[id]])
	for entrada in llista:
		graella.add_child(_casella(entrada[0], entrada[1]))
	# Caselles buides fins a omplir dues files, perquè sembli una motxilla
	for i in range(llista.size(), maxi(COLS * 2, llista.size())):
		graella.add_child(_casella("", 0))
	if seleccionat.is_empty() or not (seleccionat == "diners" or Inventari.tenir(seleccionat) > 0):
		seleccionat = "diners"
	_mostrar_descripcio(seleccionat)

func _casella(id: String, quantitat: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = MIDA_CASELLA
	b.focus_mode = Control.FOCUS_ALL
	if id.is_empty():
		b.disabled = true
		return b
	var info := {"nom": "Diners", "icona": "🪙", "descripcio": "Els guanyes servint vermut i superant onades. Serveixen per comprar acabats per a la casa."} if id == "diners" else CatalegObjectes.info(id)
	b.text = info.icona
	b.add_theme_font_size_override("font_size", 30)
	b.tooltip_text = info.nom
	var q := Label.new()
	q.text = str(quantitat)
	q.add_theme_font_size_override("font_size", 14)
	q.add_theme_color_override("font_outline_color", Color.BLACK)
	q.add_theme_constant_override("outline_size", 4)
	q.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	q.offset_left = -40
	q.offset_top = -22
	q.offset_right = -6
	q.offset_bottom = -2
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(q)
	b.pressed.connect(_mostrar_descripcio.bind(id))
	b.mouse_entered.connect(_mostrar_descripcio.bind(id))
	return b

func _mostrar_descripcio(id: String):
	seleccionat = id
	var info := {"nom": "Diners", "icona": "🪙", "descripcio": "Els guanyes servint vermut i superant onades. Serveixen per comprar acabats per a la casa."} if id == "diners" else CatalegObjectes.info(id)
	var quantitat: int = Inventari.diners if id == "diners" else Inventari.tenir(id)
	descripcio.text = "[b]%s %s[/b]  ×%d\n%s" % [info.icona, info.nom, quantitat, info.descripcio]

# ─────────────── Estat de la partida

func _omplir_estat():
	var dia: int = GestorTemps.dia_actual
	var hora: float = GestorTemps.hora_actual
	var t := ""

	# Hora i dia
	t += "[b]🕒 %s, %02d:%02d[/b] · Setmana %d\n" % [GestorOnades.DIES[GestorOnades.dia_setmana(dia)], int(hora), int((hora - int(hora)) * 60), GestorOnades.setmana(dia)]
	t += "❤ Vida: %d / %d\n\n" % [SalutJugador.vida_actual, SalutJugador.vida_maxima]

	# Temps
	t += "[color=#ffcc8c][b]El temps[/b][/color]\n"
	t += "Ara: %s %s\n" % [Meteorologia.icona(), Meteorologia.nom()]
	t += "Avui: %s\n" % _previsio(dia)
	t += "Demà: %s\n\n" % _previsio(dia + 1)

	# Onades
	t += "[color=#ffcc8c][b]Les onades[/b][/color]\n"
	t += _text_onada(dia, hora) + "\n"
	t += _setmana(dia) + "\n\n"

	# Vermuteria
	t += "[color=#ffcc8c][b]La vermuteria[/b][/color]\n"
	var servei := Progres.servei_de(dia)
	if not servei.is_empty():
		t += "Avui ja has obert: %d clients, +%d 🪙" % [servei.clients, servei.guanys]
		if servei.enfadats > 0:
			t += ", %d %s" % [servei.enfadats, "enfadat" if servei.enfadats == 1 else "enfadats"]
		t += " ✓\n"
	elif GestorTemps.es_hora_de_servei():
		t += "Avui encara no has obert (pots fins a les 20:00)\n"
	else:
		t += "Tancada fins demà\n"
	t += "🍷 Vermuts disponibles: %d\n\n" % Barrica.vermuts_disponibles()

	# Hort
	t += "[color=#ffcc8c][b]L'hort[/b][/color]\n" + _text_hort()
	estat.text = t

func _previsio(dia: int) -> String:
	var d := Meteorologia.temps_del_dia(dia)
	var tipus: int = d.tipus
	var text := "%s %s" % [Meteorologia.ICONES[tipus], Meteorologia.NOMS[tipus]]
	if tipus == Meteorologia.Tipus.PLUJA or tipus == Meteorologia.Tipus.TEMPESTA:
		text += " (de %s a %s)" % [_hora(d.inici), _hora(d.fi)]
	elif tipus == Meteorologia.Tipus.BOIRA:
		text += " (fins a mig matí)"
	return text

func _hora(h: float) -> String:
	return "%02d:%02d" % [int(h), int((h - int(h)) * 60)]

func _text_onada(dia: int, hora: float) -> String:
	if GestorOnades.activa:
		return "🌙 [b]En curs[/b]: onada del %s · %d/%d enemics" % [GestorOnades.nom_del_dia(GestorOnades.dia_onada), GestorOnades.morts, GestorOnades.total]
	var dia_nit := dia if hora >= 12.0 else dia - 1
	if GestorTemps.es_nit():
		var r := Progres.onada_de(dia_nit)
		if not r.is_empty():
			return "Onada d'aquesta nit: " + ("superada ✓" if r.superada else "resistida (%d/%d)" % [r.morts, r.total])
		return "🌙 Nit tranquil·la" if not GestorOnades.hi_ha_onada(dia_nit) else "🌙 És de nit: surt a defensar l'hort!"
	if not GestorOnades.hi_ha_onada(dia):
		return "Aquesta nit és lliure: bon moment per preparar-se"
	var falten := 20.0 - hora
	return "Aquesta nit: onada %d de 5 · falten %d h %02d min" % [GestorOnades.dia_setmana(dia) + 1, int(falten), int((falten - int(falten)) * 60)]

## Dl ✓  Dt ✓  Dc ▶  Dj ·  Dv ·  Ds –  Dg –
func _setmana(dia: int) -> String:
	var dilluns := dia - GestorOnades.dia_setmana(dia)
	var parts := []
	for i in 7:
		var d := dilluns + i
		var nom: String = DIES_CURTS[i]
		var marca := ""
		if i >= 5:
			marca = "[color=#8899aa]–[/color]"
		elif d < dia:
			var r := Progres.onada_de(d)
			marca = "·" if r.is_empty() else ("[color=#88ee88]✓[/color]" if r.superada else "[color=#ee8877]✗[/color]")
		elif d == dia:
			marca = "[color=#ffdd66]▶[/color]"
		else:
			marca = "○"
		parts.append("%s %s" % [nom, marca])
	return "  ".join(parts)

func _text_hort() -> String:
	var cultius := get_tree().get_nodes_in_group("cultius")
	var total := 0
	var madurs := 0
	var amb_set := 0
	if not cultius.is_empty():
		for c in cultius:
			total += 1
			if c.es_madur(): madurs += 1
			if c.necessita_aigua(): amb_set += 1
	else:
		# Dins de casa els cultius no hi són: els comptem de la partida desada
		var f := FileAccess.open("user://mundo_cultius.save", FileAccess.READ)
		var dades = JSON.parse_string(f.get_as_text()) if f else null
		if dades is Dictionary:
			for c in dades.get("cultius", []):
				total += 1
				if int(c.get("estat", 0)) >= 4: madurs += 1
				elif not c.get("regat", false): amb_set += 1
	if total == 0:
		return "Encara no has plantat res\n"
	return "🌿 %d cultius · %d madurs · 💧 %d amb set\n" % [total, madurs, amb_set]
