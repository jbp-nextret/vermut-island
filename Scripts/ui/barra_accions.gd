extends CanvasLayer
class_name BarraAccions
## Barra d'accions a baix al centre: la barra ràpida (9 caselles, vegeu BarraRapida) i,
## a la dreta, els botons de la motxilla, les habilitats, el mapa i el bestiari.
## A sobre surten el nom del botó (en passar-hi el ratolí), les instruccions del mode
## actiu i els avisos de les eines.

var jugador: Node
var plantador: Plantador
var regador: Regador
var llaurador: Llaurador
var llancador: Llancador

var fila: HBoxContainer
var label_info: Label
var label_avis: Label
var tween_avis: Tween
var nom_sobre := ""
var botons := {}
var a_punt := {}
var caselles: Array[CasellaBarra] = []
var progres_abans := {}

func _ready():
	fila = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 4)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(fila)
	fila.anchor_left = 0.5
	fila.anchor_right = 0.5
	fila.anchor_top = 1.0
	fila.anchor_bottom = 1.0
	fila.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fila.grow_vertical = Control.GROW_DIRECTION_BEGIN
	fila.offset_bottom = -6

	# Barra ràpida: 9 caselles configurables (1–9, rodeta o clic; Tab per a la roda)
	for i in BarraRapida.CASELLES:
		var c := CasellaBarra.new(i)
		c.clicada.connect(func(index):
			if GameState.pot_atacar():
				BarraRapida.seleccionar(index))
		c.ratoli_a_sobre.connect(func(es_sobre, nom): _on_ratoli_a_sobre(es_sobre, nom))
		fila.add_child(c)
		caselles.append(c)
	BarraRapida.canviada.connect(func():
		for c in caselles:
			c.actualitzar())
	var separador := Control.new()
	separador.custom_minimum_size = Vector2(14, 0)
	separador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(separador)
	_boto("motxilla", "🎒", "inventari", Color(0.95, 0.8, 0.5), "Motxilla (configura la barra ràpida)", func(): MenuInventari.obrir())
	_boto("habilitats", "🌟", "habilitats", Color(1.0, 0.85, 0.4), "Habilitats", func(): MenuHabilitats.obrir())
	_boto("mapa", "🗺️", "mapa", Color(0.6, 0.85, 0.95), "Mapa", func(): Mapa.obrir())
	_boto("bestiari", "📖", "bestiari", Color(0.95, 0.75, 0.55), "Bestiari", func(): Bestiari.obrir())

	label_info = _label(11, Color(0.92, 0.95, 1.0))
	add_child(label_info)
	label_avis = _label(11, Color(1, 0.55, 0.5))
	add_child(label_avis)
	label_avis.modulate.a = 0.0
	for l in [label_info, label_avis]:
		l.anchor_left = 0.0
		l.anchor_right = 1.0
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	label_info.offset_top = -80
	label_info.offset_bottom = -64
	label_avis.offset_top = -96
	label_avis.offset_bottom = -80

	regador.avis.connect(_mostrar_avis)
	jugador.mana_insuficient.connect(func(): _mostrar_avis("No tens prou mana"))
	jugador.magia_bloquejada.connect(func():
		_mostrar_avis("Encara no saps llançar boles de foc (Habilitats → Màgia d'atac)")
		_sacsejar_eina("foc"))
	Inventari.motxilla_plena.connect(func(_item): _mostrar_avis("La motxilla és plena (amplia-la a Mundà → Motxilla gran)"))
	llaurador.avis.connect(_mostrar_avis)
	EventBus.avis.connect(_mostrar_avis)
	llancador.avis.connect(_mostrar_avis)
	if jugador.has_signal("magia_no_disponible"):
		jugador.magia_no_disponible.connect(func(): _sacsejar_eina("foc"))

func _sacsejar_eina(id: String):
	for i in BarraRapida.CASELLES:
		if BarraRapida.accio(BarraRapida.caselles[i]) == id:
			caselles[i].sacsejar()

## Progrés (recàrrega) de cada eina de la barra
func _progres(id: String) -> float:
	match BarraRapida.accio(id):
		"espasa":
			return jugador.combat.progres_tall()
		"foc":
			return jugador.progres_magia() if Progressio.te("bola_foc") else 1.0
		"regar":
			return regador.progres()
		"llaurar":
			return llaurador.progres()
		"olives_marinades", "vermut_hipnotic":
			return llancador.progres()
	return 1.0

func _boto(clau: String, simbol: String, accio: String, color: Color, nom: String, callback: Callable, tecla_fixa := ""):
	var tecla := tecla_fixa
	if tecla.is_empty():
		for ev in InputMap.action_get_events(accio):
			if ev is InputEventKey:
				tecla = ev.as_text_physical_keycode()
	var b := IconaAccio.new(simbol, tecla, color, nom)
	b.clicat.connect(func():
		if GameState.pot_atacar():
			callback.call())
	b.ratoli_a_sobre.connect(_on_ratoli_a_sobre.bind(nom))
	fila.add_child(b)
	botons[clau] = b
	a_punt[clau] = true

func _on_ratoli_a_sobre(sobre: bool, nom: String):
	if sobre:
		nom_sobre = nom
	elif nom_sobre == nom:
		nom_sobre = ""

func _process(_delta):
	visible = GameState.pot_atacar()
	if not visible:
		return
	var en_combat: bool = jugador.estat == 1   # Estat.COMBAT
	var triada := BarraRapida.seleccionada()
	for i in caselles.size():
		var c := caselles[i]
		var id: String = BarraRapida.caselles[i]
		c.seleccionada = i == triada
		var p := _progres(id)
		if p >= 1.0 and progres_abans.get(i, 1.0) < 1.0 and BarraRapida.accio(id) != "espasa":
			c.bategar()   # s'acaba de recarregar
		progres_abans[i] = p
		c.progres = p
		if Engine.get_process_frames() % 15 == i:
			c.actualitzar()   # quantitats i si està disponible
		c.queue_redraw()
	_actualitzar("motxilla", true, 1.0)
	_actualitzar("habilitats", true, 1.0)
	_actualitzar("mapa", true, 1.0)
	_actualitzar("bestiari", true, 1.0)
	# Si tens punts per gastar, el botó d'habilitats batega
	if Progressio.punts > 0 and Engine.get_process_frames() % 120 == 0:
		botons.habilitats.bategar()

	# Nom del botó sota el ratolí, o què pots fer en el mode actiu
	label_info.visible = SettingsManager.valor("ajudes") or not nom_sobre.is_empty()
	if not nom_sobre.is_empty():
		label_info.text = nom_sobre
	elif plantador.actiu:
		label_info.text = "" if plantador.roda_oberta else "Clic: plantar · Arrossega: àrea · Q/E: canviar · Clic dret: sortir"
	elif regador.actiu:
		label_info.text = "Clic: regar · Clic dret: sortir"
	elif llancador.actiu:
		var info := CatalegObjectes.info(llancador.objecte())
		label_info.text = "%s %s: %d · Clic: llançar · Q/E: canviar · Clic dret: sortir" % [info.icona, info.nom, llancador.quantitat()]
	elif llaurador.actiu:
		label_info.text = "Clic: llaurar · Arrossega: àrea · Clic dret: sortir" if llaurador.pot_arrossegar() else "Clic: llaurar · Clic dret: sortir"
	elif BarraRapida.mode_eina == "talar":
		label_info.text = "🪓 Clic sobre un arbre: talar · Clic dret: deixar-ho"
	elif BarraRapida.mode_eina == "picar":
		label_info.text = "⛏️ Clic sobre una roca: picar · Clic dret: deixar-ho"
	elif BarraRapida.mode_foc:
		label_info.text = "Clic: bola de foc · Clic dret: deixar-ho"
	elif en_combat and not plantador.actiu:
		label_info.text = "Clic: tall · Clic dret: estocada" + (" · E: bola de foc" if Progressio.te("bola_foc") else "")
	else:
		label_info.text = "1–9: eines · Tab (mantenir): roda d'eines"

func _actualitzar(clau: String, activa: bool, progres: float):
	var b: IconaAccio = botons[clau]
	b.activa = activa
	b.progres = progres
	if progres >= 1.0 and not a_punt[clau] and clau != "combat":
		b.bategar()   # s'acaba de recarregar
	a_punt[clau] = progres >= 1.0
	b.queue_redraw()

func _mostrar_avis(text: String):
	label_avis.text = text
	if tween_avis:
		tween_avis.kill()
	label_avis.modulate.a = 1.0
	tween_avis = create_tween()
	tween_avis.tween_interval(1.0)
	tween_avis.tween_property(label_avis, "modulate:a", 0.0, 0.4)

func _label(mida: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", mida)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	return l
