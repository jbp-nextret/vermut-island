extends CanvasLayer
## Consola de trucs per provar el joc (només executant des de l'editor o en compilacions
## de depuració). S'obre i es tanca amb la tecla º (la de sota d'Esc) o F10.
## Escriu `ajuda` per veure les comandes. Tab completa, ↑/↓ recorren l'historial.
## Mentre és oberta, el joc s'atura.

const FITXER_HISTORIAL := "user://trucs_historial.txt"

## nom -> [arguments, descripció]
const COMANDES := {
	"ajuda": ["", "Aquesta llista"],
	"hora": ["<0-24>", "Posa aquesta hora (si ja ha passat, l'endemà)"],
	"dia": ["", "Les 8 del matí (de l'endemà si cal)"],
	"nit": ["", "Les 21 h: comença l'onada si n'hi ha"],
	"dema": ["", "Passa al dia següent a les 6"],
	"temps": ["<x>", "Velocitat del rellotge (1 = normal, 10 = deu vegades més ràpid)"],
	"aturar_temps": ["", "Atura o reprèn el rellotge"],
	"diners": ["<n>", "Dona monedes"],
	"donar": ["<objecte> [n]", "Dona un objecte (Tab completa el nom)"],
	"objectes": ["[filtre]", "Llista els identificadors d'objectes"],
	"kit": ["", "El kit de proves (F4)"],
	"xp": ["<n>", "Dona experiència al jugador"],
	"punts": ["<n>", "Dona punts d'habilitat"],
	"curar": ["", "Vida i mana al màxim"],
	"deu": ["", "Invulnerable i mana infinit (activa/desactiva)"],
	"rapid": ["[x]", "Multiplica la velocitat del jugador (sense número: 3; 1 = normal)"],
	"tp": ["<x> <z> | casa | illa <n>", "Teletransporta el jugador"],
	"matar": ["", "Mata tots els enemics"],
	"cultius": ["", "Tots els cultius madurs"],
	"regar": ["", "Rega tots els cultius"],
	"criatura": ["<espècie> [nivell]", "Fa sortir una criatura salvatge al costat"],
	"capturar": ["<espècie> [nivell]", "Afegeix una criatura domesticada a la col·lecció"],
	"planols": ["", "Aprèn tots els plànols"],
	"barriques": ["", "Totes les barriques a punt"],
	"descansat": ["", "Treu el cansament i et deixa descansat"],
	"meteo": ["<clar|ennuvolat|pluja|tempesta|boira|auto>", "Força el temps que fa"],
	"fps": ["", "Mostra o amaga el comptador de rendiment (F3)"],
	"netejar": ["", "Esborra la consola"],
}

var velocitat_jugador := 1.0
var deu := false

var panell: PanelContainer
var sortida: RichTextLabel
var entrada: LineEdit
var historial: Array[String] = []
var pos_historial := 0
var pausat_abans := false

func _ready():
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not OS.is_debug_build():
		set_process_input(false)
		return
	_construir()
	_carregar_historial()

func _construir():
	panell = PanelContainer.new()
	panell.anchor_right = 1.0
	panell.anchor_bottom = 0.45
	var estil := StyleBoxFlat.new()
	estil.bg_color = Color(0.03, 0.04, 0.06, 0.88)
	estil.border_color = Color(0.45, 0.85, 0.5, 0.6)
	estil.border_width_bottom = 2
	estil.set_content_margin_all(10)
	panell.add_theme_stylebox_override("panel", estil)
	add_child(panell)
	var col := VBoxContainer.new()
	panell.add_child(col)
	sortida = RichTextLabel.new()
	sortida.bbcode_enabled = true
	sortida.scroll_following = true
	sortida.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sortida.add_theme_font_size_override("normal_font_size", 15)
	sortida.add_theme_font_size_override("bold_font_size", 15)
	col.add_child(sortida)
	entrada = LineEdit.new()
	entrada.placeholder_text = "Escriu una comanda (ajuda) · Tab completa · ↑↓ historial · º per tancar"
	entrada.add_theme_font_size_override("font_size", 16)
	entrada.text_submitted.connect(_executar_text)
	entrada.gui_input.connect(_tecla_entrada)
	col.add_child(entrada)
	escriure("[color=#9fe39f]🧪 Consola de trucs.[/color] Escriu [b]ajuda[/b] per veure les comandes.")

# ─────────────── Obrir i tancar

func _input(event: InputEvent):
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k := event as InputEventKey
	if k.physical_keycode == KEY_QUOTELEFT or k.physical_keycode == KEY_F10:
		get_viewport().set_input_as_handled()
		alternar()
	elif visible and k.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		alternar()

func alternar():
	visible = not visible
	if visible:
		pausat_abans = get_tree().paused
		get_tree().paused = true
		entrada.clear()
		entrada.call_deferred("grab_focus")
	else:
		entrada.release_focus()
		get_tree().paused = pausat_abans

func _process(_delta):
	if deu:
		SalutJugador.invulnerable_fins = Time.get_ticks_msec() / 1000.0 + 1.0
		var j = _jugador()
		if j and j.has_method("mana_max"):
			j.mana = j.mana_max()

# ─────────────── Entrada

func _tecla_entrada(event: InputEvent):
	if not (event is InputEventKey and event.pressed):
		return
	match (event as InputEventKey).keycode:
		KEY_UP:
			_historial(-1)
			entrada.accept_event()
		KEY_DOWN:
			_historial(1)
			entrada.accept_event()
		KEY_TAB:
			_completar()
			entrada.accept_event()

func _historial(pas: int):
	if historial.is_empty():
		return
	pos_historial = clampi(pos_historial + pas, 0, historial.size())
	entrada.text = historial[pos_historial] if pos_historial < historial.size() else ""
	entrada.caret_column = entrada.text.length()

## Completa la comanda o, per a donar / criatura / capturar / meteo, l'argument
func _completar():
	var parts := entrada.text.split(" ")
	var opcions: Array = []
	var prefix: String = parts[parts.size() - 1]
	if parts.size() == 1:
		opcions = COMANDES.keys()
	elif parts.size() == 2:
		match parts[0]:
			"donar":
				opcions = _ids_objectes()
			"criatura", "capturar":
				opcions = Criatures.especies.keys()
			"meteo":
				opcions = ["clar", "ennuvolat", "pluja", "tempesta", "boira", "auto"]
			"tp":
				opcions = ["casa", "illa"]
	var encerts := opcions.filter(func(o): return str(o).begins_with(prefix))
	if encerts.is_empty():
		return
	if encerts.size() == 1:
		parts[parts.size() - 1] = encerts[0]
		entrada.text = " ".join(parts) + " "
	else:
		escriure("[color=#888]%s[/color]" % "  ".join(encerts))
		var comu: String = encerts[0]
		for e in encerts:
			while not str(e).begins_with(comu):
				comu = comu.left(-1)
		parts[parts.size() - 1] = comu
		entrada.text = " ".join(parts)
	entrada.caret_column = entrada.text.length()

func _executar_text(text: String):
	text = text.strip_edges()
	entrada.clear()
	if text.is_empty():
		return
	escriure("[color=#7fd1ff]> %s[/color]" % text)
	if historial.is_empty() or historial[-1] != text:
		historial.append(text)
		_guardar_historial()
	pos_historial = historial.size()
	executar(text)

func escriure(text: String):
	if sortida:
		sortida.append_text(text + "\n")
	print_rich(text)

func _error(text: String):
	escriure("[color=#ff8a80]%s[/color]" % text)

func _ok(text: String):
	escriure("[color=#9fe39f]%s[/color]" % text)

# ─────────────── Comandes

func executar(text: String):
	var parts := text.split(" ", false)
	var c := parts[0].to_lower()
	var a := parts.slice(1)
	match c:
		"ajuda", "help":
			for nom in COMANDES:
				escriure("[b]%s[/b] %s  [color=#aaa]— %s[/color]" % [nom, COMANDES[nom][0], COMANDES[nom][1]])
		"hora":
			if a.is_empty() or not a[0].is_valid_float():
				return _error("Ús: hora <0-24>")
			_anar_a_hora(fposmod(a[0].to_float(), 24.0))
		"dia":
			_anar_a_hora(8.0)
		"nit":
			_anar_a_hora(21.0)
		"dema":
			GestorTemps.passar_dia()
			GestorTemps.hora_actual = 6.0
			_ok("Dia %d, 6:00" % GestorTemps.dia_actual)
		"temps":
			var x := a[0].to_float() if not a.is_empty() else 1.0
			if x <= 0.0:
				return _error("Ús: temps <x> (més gran que 0)")
			GestorTemps.durada_dia = 1800.0 / x
			_ok("Rellotge ×%s: un dia dura %s s" % [x, GestorTemps.durada_dia])
		"aturar_temps":
			GestorTemps.pausat = not GestorTemps.pausat
			_ok("Rellotge %s" % ("aturat" if GestorTemps.pausat else "en marxa"))
		"diners":
			var n := _enter(a, 0, 1000)
			Inventari.afegir_diners(n)
			_ok("+%d 🪙 (en tens %d)" % [n, Inventari.diners])
		"donar":
			if a.is_empty():
				return _error("Ús: donar <objecte> [n]")
			var n := _enter(a, 1, 1)
			Inventari.afegir(a[0], n, true)
			_ok("+%d %s %s" % [n, CatalegObjectes.info(a[0]).icona, a[0]])
		"objectes":
			var filtre: String = a[0] if not a.is_empty() else ""
			escriure("  ".join(_ids_objectes().filter(func(i): return filtre in i)))
		"kit":
			Diagnostic._kit_de_proves()
			_ok("Kit de proves")
		"xp":
			var n := _enter(a, 0, 100)
			Progressio.guanyar_xp_directa(n, "trucs")
			_ok("+%d XP (nivell %d)" % [n, Progressio.nivell])
		"punts":
			var n := _enter(a, 0, 5)
			Progressio.punts += n
			Progressio.guardar()
			Progressio.habilitats_canviades.emit()
			_ok("+%d punts d'habilitat (en tens %d)" % [n, Progressio.punts])
		"curar":
			SalutJugador.restaurar_salut()
			var j = _jugador()
			if j and j.has_method("mana_max"):
				j.mana = j.mana_max()
			_ok("Vida i mana al màxim")
		"deu":
			deu = not deu
			_ok("Mode déu %s" % ("activat" if deu else "desactivat"))
		"rapid":
			velocitat_jugador = a[0].to_float() if not a.is_empty() else (1.0 if velocitat_jugador > 1.0 else 3.0)
			_ok("Velocitat del jugador ×%s" % velocitat_jugador)
		"tp":
			_teletransportar(a)
		"matar":
			var n := 0
			for e in get_tree().get_nodes_in_group("enemics"):
				if e.has_method("morir"):
					e.morir()
					n += 1
			_ok("%d enemics morts" % n)
		"cultius":
			var n := 0
			for cu in get_tree().get_nodes_in_group("cultius"):
				if "estat_actual" in cu and not cu.recollit:
					cu.estat_actual = 4   # Cultiu.Estat.MADUR
					cu.actualitzar_sprite()
					n += 1
			_ok("%d cultius madurs" % n)
		"regar":
			var n := 0
			for cu in get_tree().get_nodes_in_group("cultius"):
				if "regat" in cu:
					cu.regat = true
					if cu.has_method("_actualitzar_humitat"):
						cu._actualitzar_humitat()
					n += 1
			_ok("%d cultius regats" % n)
		"criatura":
			_criatura(a, false)
		"capturar":
			_criatura(a, true)
		"planols":
			var n := 0
			while Fabricacio.aprendre_planol_nou() != null:
				n += 1
			_ok("%d plànols nous" % n)
		"barriques":
			for b in Celler.barriques:
				Celler.barriques[b].fi = Celler.ara()
			Celler._canvi("")
			_ok("Barriques a punt")
		"descansat":
			Descans.ultim_despertar = Celler.ara()
			Descans._posar_efecte("descansat")
			Descans._guardar()
			Descans.estat_canviat.emit()
			_ok("Descansat")
		"meteo":
			var noms := ["clar", "ennuvolat", "pluja", "tempesta", "boira"]
			if a.is_empty() or not (a[0] in noms or a[0] == "auto"):
				return _error("Ús: meteo <%s|auto>" % "|".join(noms))
			Meteorologia.forcat = -1 if a[0] == "auto" else noms.find(a[0])
			_ok("Temps: %s" % a[0])
		"fps":
			Diagnostic.visible = not Diagnostic.visible
		"netejar", "clear", "cls":
			sortida.clear()
		_:
			_error("No conec «%s». Escriu ajuda." % c)

func _enter(a: Array, i: int, per_defecte: int) -> int:
	return a[i].to_int() if a.size() > i and a[i].is_valid_int() else per_defecte

func _anar_a_hora(h: float):
	GestorTemps.avancar_fins(h)
	_ok("Dia %d, %d:%02d" % [GestorTemps.dia_actual, floori(h), roundi(fposmod(h, 1.0) * 60.0)])

func _jugador() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D

func _ids_objectes() -> Array:
	var ids := CatalegObjectes.OBJECTES.keys()
	for id in Inventari.items:
		if not id in ids:
			ids.append(id)
	ids.sort()
	return ids

func _teletransportar(a: Array):
	var j := _jugador()
	var mon := get_tree().current_scene
	if j == null or mon == null:
		return _error("No hi ha jugador")
	var desti = null
	if a.size() >= 2 and a[0].is_valid_float() and a[1].is_valid_float():
		desti = Vector3(a[0].to_float(), j.global_position.y + 3.0, a[1].to_float())
	elif not a.is_empty() and a[0] == "casa":
		var casa := mon.get_node_or_null("Casa") as Node3D
		if casa:
			desti = casa.global_position + Vector3(0, 2.0, 3.5)
	elif not a.is_empty() and a[0] == "illa":
		var gen = mon.get_node_or_null("GeneradorIlles")
		var n := _enter(a, 1, 1) - 1
		if gen and n >= 0 and n < gen.illes.size():
			desti = gen.illes[n].centre + Vector3.UP * 3.0
		elif gen:
			return _error("Hi ha %d illetes (illa 1..%d)" % [gen.illes.size(), gen.illes.size()])
	if desti == null:
		return _error("Ús: tp <x> <z> | tp casa | tp illa <n>")
	j.global_position = desti
	j.velocity = Vector3.ZERO
	if j.has_method("_reset_interpolacio"):
		j._reset_interpolacio()
	_ok("Ets a (%.1f, %.1f)" % [desti.x, desti.z])

func _criatura(a: Array, domesticada: bool):
	# Accepta el començament del nom (llop -> llop_garriga)
	var ids: Array = Criatures.especies.keys().filter(func(id): return not a.is_empty() and id.begins_with(a[0]))
	if ids.size() != 1:
		return _error("Espècies: %s" % ", ".join(Criatures.especies.keys()))
	var e := Criatures.especie(ids[0])
	var nivell := clampi(_enter(a, 1, 1), 1, 20)
	if domesticada:
		var d := Criatures.capturar(e, nivell)
		_ok("Domesticada: %s (nivell %d)" % [d.get("nom", ids[0]), nivell])
		return
	var j := _jugador()
	if j == null:
		return _error("No hi ha jugador")
	var c := Criatura.crear(e)
	c.nivell = nivell
	get_tree().current_scene.add_child(c)
	var pos := j.global_position + Vector3(2.0, 0.5, 0.0)
	c.global_position = pos
	c.casa = pos
	c.pos_anterior = pos
	_ok("Salvatge: %s (nivell %d)" % [ids[0], nivell])

# ─────────────── Historial (es guarda entre partides)

func _guardar_historial():
	var f := FileAccess.open(FITXER_HISTORIAL, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(historial.slice(-50)))

func _carregar_historial():
	var f := FileAccess.open(FITXER_HISTORIAL, FileAccess.READ)
	if f:
		for l in f.get_as_text().split("\n", false):
			historial.append(l)
	pos_historial = historial.size()
