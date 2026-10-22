extends CanvasLayer
class_name HudMissions
## A dalt a la dreta, sota el rellotge: les missions actives amb els objectius.
## Al mig de la pantalla, un avís quan n'acceptes, en completes un objectiu o la lliures.

const MAX_MISSIONS := 3

var llista: RichTextLabel
var cartell: Label
var tween_cartell: Tween
var cua: Array[String] = []

func _ready():
	llista = RichTextLabel.new()
	llista.bbcode_enabled = true
	llista.fit_content = true
	llista.scroll_active = false
	llista.mouse_filter = Control.MOUSE_FILTER_IGNORE
	llista.add_theme_font_size_override("normal_font_size", 13)
	llista.add_theme_font_size_override("bold_font_size", 14)
	llista.add_theme_color_override("default_color", Color(0.95, 0.95, 0.9))
	llista.add_theme_color_override("font_outline_color", Color.BLACK)
	llista.add_theme_constant_override("outline_size", 5)
	llista.anchor_left = 1.0
	llista.anchor_right = 1.0
	llista.offset_left = -300
	llista.offset_right = -10
	llista.offset_top = 48
	llista.offset_bottom = 300
	add_child(llista)

	cartell = Label.new()
	cartell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cartell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cartell.add_theme_font_size_override("font_size", 22)
	cartell.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	cartell.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	cartell.add_theme_constant_override("outline_size", 8)
	cartell.set_anchors_preset(Control.PRESET_TOP_WIDE)
	cartell.offset_top = 120
	cartell.offset_bottom = 190
	cartell.modulate.a = 0.0
	add_child(cartell)

	Missions.missions_canviades.connect(_actualitzar)
	Missions.missio_acceptada.connect(func(m): _avisar("📜 Nova missió\n%s" % m.titol))
	Missions.missio_llesta.connect(func(m): _avisar("✔ %s\nTorna a parlar amb %s" % [m.titol, _nom_npc(m.donant)]))
	Missions.missio_completada.connect(func(m): _avisar("🏆 Missió completada!\n%s" % m.text_recompenses()))
	_actualitzar()

func _process(_delta):
	visible = not GameState.dins_casa and not GameState.en_dialeg

func _actualitzar():
	var t := ""
	var actives := Missions.missions_actives()
	for m in actives.slice(0, MAX_MISSIONS):
		t += "[right][b][color=#ffd98a]%s[/color][/b]\n" % m.titol
		if Missions.pot_lliurar(m.id):
			t += "[color=#9ef59e]▸ Torna a parlar amb %s[/color]\n" % _nom_npc(m.donant)
		else:
			for i in m.objectius.size():
				var o: ObjectiuMissio = m.objectius[i]
				var p := Missions.progres(m.id, i)
				var fet := p >= o.objectiu()
				t += ("[color=#9ef59e]✓ %s[/color]\n" if fet else "• %s\n") % o.text(p)
		t += "[/right]\n"
	if actives.size() > MAX_MISSIONS:
		t += "[right][color=#aaaaaa]+%d missions més (I)[/color][/right]" % (actives.size() - MAX_MISSIONS)
	llista.text = t

func _avisar(text: String):
	cua.append(text)
	if cua.size() == 1:
		_seguent_avis()

func _seguent_avis():
	if cua.is_empty():
		return
	cartell.text = cua[0]
	if tween_cartell:
		tween_cartell.kill()
	cartell.modulate.a = 0.0
	tween_cartell = create_tween()
	tween_cartell.tween_property(cartell, "modulate:a", 1.0, 0.25)
	tween_cartell.tween_interval(2.2)
	tween_cartell.tween_property(cartell, "modulate:a", 0.0, 0.5)
	tween_cartell.tween_callback(func():
		cua.pop_front()
		_seguent_avis())

## El nom que es mostra d'un NPC (el de l'escena, o el seu id)
func _nom_npc(id: String) -> String:
	for n in get_tree().get_nodes_in_group("npcs"):
		if n.id == id:
			return n.nom
	return id.capitalize()
