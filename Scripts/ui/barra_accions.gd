extends CanvasLayer
class_name BarraAccions
## Barra d'accions a baix al centre. Cada botó es pot fer servir amb la seva tecla o
## clicant-lo amb el ratolí:
##   ✨ mode combat · 💨 estocada · 🔥 bola de foc  |  🌱 plantar · 💧 regar · ⛏ llaurar
## A sobre surten el nom del botó (en passar-hi el ratolí), les instruccions del mode
## actiu i els avisos de les eines.

var jugador: Node
var plantador: Plantador
var regador: Regador
var llaurador: Llaurador

var fila: HBoxContainer
var label_info: Label
var label_avis: Label
var tween_avis: Tween
var nom_sobre := ""
var botons := {}
var a_punt := {}

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

	_boto("combat", "✨", "mode_combat", Color(0.55, 0.85, 1.0), "Mode combat (clic: tall)", func(): jugador.toggle_mode_combat())
	_boto("estocada", "💨", "", Color(0.6, 0.85, 1.0), "Estocada", func(): jugador._atac_magic("estocada", jugador._direccio_mirada()), "Dret")
	_boto("foc", "🔥", "atac_magia", Color(1.0, 0.55, 0.15), "Bola de foc", func(): jugador.disparar_bola_foc(jugador._direccio_mirada()))
	var separador := Control.new()
	separador.custom_minimum_size = Vector2(14, 0)
	separador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(separador)
	_boto("plantar", "🌱", "plantar", Color(0.55, 0.95, 0.5), "Plantar (mantén P: triar cultiu)", func(): plantador.alternar())
	_boto("regar", "💧", "regar", Color(0.45, 0.75, 1.0), "Regar", _alternar.bind(regador))
	_boto("llaurar", "⛏", "llaurar", Color(0.85, 0.65, 0.35), "Llaurar", _alternar.bind(llaurador))
	var separador2 := Control.new()
	separador2.custom_minimum_size = Vector2(14, 0)
	separador2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fila.add_child(separador2)
	_boto("motxilla", "🎒", "inventari", Color(0.95, 0.8, 0.5), "Motxilla", func(): MenuInventari.obrir())
	_boto("habilitats", "🌟", "habilitats", Color(1.0, 0.85, 0.4), "Habilitats", func(): MenuHabilitats.obrir())

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
	Inventari.motxilla_plena.connect(func(_item): _mostrar_avis("La motxilla és plena (amplia-la a Mundà → Motxilla gran)"))
	llaurador.avis.connect(_mostrar_avis)
	if jugador.has_signal("magia_no_disponible"):
		jugador.magia_no_disponible.connect(func(): botons.foc.sacsejar())

func _alternar(eina: Node):
	if eina.actiu:
		eina.sortir()
	else:
		eina.entrar()

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
	_actualitzar("combat", en_combat, jugador.combat.progres_tall())
	_actualitzar("estocada", true, jugador.combat.progres_estocada())
	_actualitzar("foc", true, jugador.progres_magia())
	_actualitzar("plantar", plantador.actiu, 1.0)
	_actualitzar("regar", regador.actiu, regador.progres())
	_actualitzar("llaurar", llaurador.actiu, llaurador.progres())
	_actualitzar("motxilla", true, 1.0)
	_actualitzar("habilitats", true, 1.0)
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
	elif llaurador.actiu:
		label_info.text = "Clic: llaurar · Arrossega: àrea · Clic dret: sortir"
	elif en_combat and not plantador.actiu:
		label_info.text = "Clic: tall · Clic dret: estocada · E: bola de foc"
	else:
		label_info.text = ""

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
