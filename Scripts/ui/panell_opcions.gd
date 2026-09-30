extends PanelContainer
class_name PanellOpcions
## Panell d'opcions (el fan servir el menú de pausa i el menú principal).
## Pestanyes: So, Gràfics, Joc i Controls. Tot es desa sol al SettingsManager.

signal tancat

var pestanyes: TabContainer
var boto_tecla_esperant: Button = null
var accio_esperant := ""
var botons_tecles := {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS   # funciona amb el joc en pausa
	theme = EstilMenus.tema()
	add_theme_stylebox_override("panel", EstilMenus.caixa_fons())
	custom_minimum_size = Vector2(560, 440)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	add_child(columna)

	var titol := Label.new()
	titol.text = "Opcions"
	titol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titol.add_theme_font_size_override("font_size", 28)
	columna.add_child(titol)

	pestanyes = TabContainer.new()
	pestanyes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columna.add_child(pestanyes)
	_pestanya_so()
	_pestanya_grafics()
	_pestanya_joc()
	_pestanya_controls()

	var peu := HBoxContainer.new()
	peu.alignment = BoxContainer.ALIGNMENT_CENTER
	peu.add_theme_constant_override("separation", 12)
	columna.add_child(peu)
	var restaurar := Button.new()
	restaurar.text = "Valors per defecte"
	restaurar.pressed.connect(_restaurar)
	peu.add_child(restaurar)
	var tornar := Button.new()
	tornar.text = "Tornar"
	tornar.pressed.connect(func(): tancat.emit())
	peu.add_child(tornar)
	tornar.call_deferred("grab_focus")

# ─────────────── Pestanyes

func _pestanya(nom: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = nom
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pestanyes.add_child(scroll)
	var llista := VBoxContainer.new()
	llista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	llista.add_theme_constant_override("separation", 10)
	scroll.add_child(llista)
	return llista

func _pestanya_so():
	var l := _pestanya("So")
	_control_lliscant(l, "Volum general", "volum_general")
	_control_lliscant(l, "Música", "volum_musica")
	_control_lliscant(l, "Efectes", "volum_efectes")

func _pestanya_grafics():
	var l := _pestanya("Gràfics")
	_interruptor(l, "Pantalla completa (F11)", "pantalla_completa")
	_interruptor(l, "Sincronització vertical (VSync)", "vsync")
	_interruptor(l, "Postprocessat (F10)", "postprocessat")
	_interruptor(l, "Vores al voltant dels objectes", "vores")
	_interruptor(l, "Pluja i partícules del temps", "particules_meteo")
	_control_lliscant(l, "Sacseig de càmera", "sacseig")

func _pestanya_joc():
	var l := _pestanya("Joc")
	_interruptor(l, "Números de dany", "numeros_dany")
	_interruptor(l, "Ajudes de controls a la pantalla", "ajudes")

func _pestanya_controls():
	var l := _pestanya("Controls")
	var nota := Label.new()
	nota.text = "Clica una acció i prem la tecla nova (Esc per cancel·lar)."
	nota.add_theme_font_size_override("font_size", 14)
	nota.modulate = Color(1, 1, 1, 0.7)
	l.add_child(nota)
	for a in SettingsManager.ACCIONS_REMAPEJABLES:
		var fila := HBoxContainer.new()
		var nom := Label.new()
		nom.text = a[1]
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fila.add_child(nom)
		var b := Button.new()
		b.custom_minimum_size = Vector2(140, 0)
		b.text = SettingsManager.tecla_de(a[0])
		b.pressed.connect(_esperar_tecla.bind(a[0], b))
		fila.add_child(b)
		botons_tecles[a[0]] = b
		l.add_child(fila)

# ─────────────── Controls reutilitzables

func _interruptor(pare: Control, text: String, clau: String):
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = SettingsManager.valor(clau)
	c.toggled.connect(func(actiu): SettingsManager.canviar(clau, actiu))
	c.set_meta("clau", clau)
	pare.add_child(c)

func _control_lliscant(pare: Control, text: String, clau: String):
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	var nom := Label.new()
	nom.text = text
	nom.custom_minimum_size = Vector2(190, 0)
	fila.add_child(nom)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = SettingsManager.valor(clau)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.set_meta("clau", clau)
	fila.add_child(s)
	var percentatge := Label.new()
	percentatge.custom_minimum_size = Vector2(50, 0)
	percentatge.text = "%d %%" % roundi(s.value * 100)
	fila.add_child(percentatge)
	s.value_changed.connect(func(v):
		percentatge.text = "%d %%" % roundi(v * 100)
		SettingsManager.canviar(clau, v))
	pare.add_child(fila)

# ─────────────── Canviar tecles

func _esperar_tecla(accio: String, boto: Button):
	if boto_tecla_esperant:
		boto_tecla_esperant.text = SettingsManager.tecla_de(accio_esperant)
	accio_esperant = accio
	boto_tecla_esperant = boto
	boto.text = "Prem una tecla…"

func _input(event: InputEvent):
	if boto_tecla_esperant == null or not (event is InputEventKey) or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	if event.physical_keycode != KEY_ESCAPE:
		SettingsManager.remapejar(accio_esperant, event)
	boto_tecla_esperant.text = SettingsManager.tecla_de(accio_esperant)
	boto_tecla_esperant = null
	accio_esperant = ""

## Si l'Esc no s'ha fet servir per a una tecla, tanca el panell
func _unhandled_input(event: InputEvent):
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		tancat.emit()

func _restaurar():
	SettingsManager.restaurar_per_defecte()
	for node in find_children("*", "", true, false):
		if not node.has_meta("clau"):
			continue
		var clau: String = node.get_meta("clau")
		if node is CheckButton:
			node.set_pressed_no_signal(SettingsManager.valor(clau))
		elif node is HSlider:
			node.value = SettingsManager.valor(clau)
	for accio in botons_tecles:
		botons_tecles[accio].text = SettingsManager.tecla_de(accio)
