extends Node
## Descans (autoload): el son del jugador. Les hores que portes despert i com has dormit
## canvien la velocitat, la recuperació de mana i vida i l'experiència que guanyes.
##
##   Despert:  0–18 h normal · 18 h Cansat · 24 h Esgotat · 30 h et desmaies
##   Dormir:   menys de 3 h  becaina (recupera una mica, treu poc cansament)
##             3–5 h         poc (recupera força, però quedes Endormiscat)
##             6–9 h         bé (ho recupera tot i quedes Descansat)
##             10 h o més    massa (ho recupera tot, però quedes Ensopit i perds el dia)
## Les hores són de joc, i dins de casa el rellotge no corre.

signal estat_canviat

const FITXER := "user://descans.save"

const HORES_CANSAT := 18.0
const HORES_ESGOTAT := 24.0
const HORES_DESMAI := 30.0

## Efectes temporals després de dormir: nom, icona, durada (h), velocitat, mana, xp i text
const EFECTES := {
	"descansat": {"nom": "Descansat", "icona": "✨", "hores": 16.0, "velocitat": 0.10, "mana": 0.25, "xp": 0.10,
		"text": "+10 % velocitat, +25 % mana i +10 % experiència"},
	"endormiscat": {"nom": "Endormiscat", "icona": "🥱", "hores": 8.0, "velocitat": 0.0, "mana": -0.15, "xp": -0.10,
		"text": "−15 % mana i −10 % experiència"},
	"ensopit": {"nom": "Ensopit", "icona": "😪", "hores": 6.0, "velocitat": -0.15, "mana": -0.20, "xp": 0.0,
		"text": "−15 % velocitat i −20 % mana"},
}
## I els de no dormir
const CANSAT := {"nom": "Cansat", "icona": "😴", "velocitat": -0.10, "mana": -0.30, "xp": -0.10,
	"text": "−10 % velocitat, −30 % mana i −10 % experiència. Ves a dormir!"}
const ESGOTAT := {"nom": "Esgotat", "icona": "😵", "velocitat": -0.25, "mana": -0.60, "xp": -0.25,
	"text": "−25 % velocitat, −60 % mana, no recuperes vida i −25 % experiència. Si no dorms, et desmaiaràs!"}

var ultim_despertar := 0.0   # hora absoluta (dia × 24 + hora) en què et vas despertar
var efecte := ""              # "descansat", "endormiscat", "ensopit" o ""
var efecte_fins := 0.0
var estat_anterior := ""
var desmaiant := false

func _ready():
	ultim_despertar = Celler.ara()
	_carregar()

func hores_despert() -> float:
	return maxf(0.0, Celler.ara() - ultim_despertar)

## L'estat que mana ara mateix ({} si cap): primer el cansament, després l'efecte del son
func estat() -> Dictionary:
	var h := hores_despert()
	if h >= HORES_ESGOTAT:
		return ESGOTAT
	if h >= HORES_CANSAT:
		return CANSAT
	if not efecte.is_empty() and Celler.ara() < efecte_fins:
		return EFECTES[efecte]
	return {}

## Hores que queden de l'efecte del son (0 si no n'hi ha)
func hores_efecte() -> float:
	if efecte.is_empty() or hores_despert() >= HORES_CANSAT:
		return 0.0
	return maxf(0.0, efecte_fins - Celler.ara())

func mult_velocitat() -> float:
	return 1.0 + float(estat().get("velocitat", 0.0))

func mult_mana() -> float:
	return 1.0 + float(estat().get("mana", 0.0))

func mult_xp() -> float:
	return 1.0 + float(estat().get("xp", 0.0))

func pot_regenerar_vida() -> bool:
	return hores_despert() < HORES_ESGOTAT

# ─────────────── Dormir

## Es crida després d'avançar el rellotge. Recupera vida i mana i deixa l'efecte que toqui.
## Retorna el text del resultat (per a la pantalla negra).
func dormir(hores: float) -> String:
	# El rellotge ja ha avançat: les hores que portaves despert abans d'anar a dormir
	var abans := maxf(0.0, hores_despert() - hores)
	var recupera := 1.0
	var queda_despert := 0.0
	var text := ""
	if hores < 3.0:
		recupera = 0.3
		queda_despert = maxf(0.0, abans - hores * 3.0)
		efecte = ""
		text = "Becaina: recuperes una mica, però el cansament no se'n va del tot."
	elif hores < 6.0:
		recupera = 0.6
		queda_despert = maxf(0.0, abans - hores * 3.0)
		_posar_efecte("endormiscat")
		text = "Has dormit poc. 🥱 Endormiscat: %s." % EFECTES.endormiscat.text
	elif hores < 10.0:
		_posar_efecte("descansat")
		text = "Has dormit bé! ✨ Descansat: %s." % EFECTES.descansat.text
	else:
		_posar_efecte("ensopit")
		text = "Has dormit massa... 😪 Ensopit: %s." % EFECTES.ensopit.text
	ultim_despertar = Celler.ara() - queda_despert
	SalutJugador.curar(ceili(SalutJugador.vida_maxima * recupera))
	var j = get_tree().get_first_node_in_group("jugador")
	if j and j.has_method("mana_max"):
		j.mana = minf(j.mana_max(), j.mana + j.mana_max() * recupera)
	_guardar()
	estat_canviat.emit()
	return text

func _posar_efecte(id: String):
	efecte = id
	efecte_fins = Celler.ara() + EFECTES[id].hores

# ─────────────── Avisos i desmai

func _process(_delta):
	var e := estat()
	var nom: String = e.get("nom", "")
	if nom != estat_anterior:
		if nom == CANSAT.nom:
			EventBus.avis.emit("😴 Estàs cansat: %s" % CANSAT.text)
		elif nom == ESGOTAT.nom:
			EventBus.avis.emit("😵 Estàs esgotat: %s" % ESGOTAT.text)
		estat_anterior = nom
		estat_canviat.emit()
	if hores_despert() >= HORES_DESMAI and not desmaiant and not GameState.dins_casa \
			and get_tree().get_first_node_in_group("jugador") and not get_tree().paused:
		_desmaiar()

## Et desmaies on siguis: dorms 8 hores a terra, sense descansar bé, i algú et pispa monedes
func _desmaiar():
	desmaiant = true
	var capa := CanvasLayer.new()
	capa.layer = 60
	capa.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child(capa)
	var fos := ColorRect.new()
	fos.color = Color(0, 0, 0, 0)
	fos.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa.add_child(fos)
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 30)
	l.modulate.a = 0.0
	fos.add_child(l)
	get_tree().paused = true
	var t := capa.create_tween()
	t.tween_property(fos, "color:a", 1.0, 1.2)
	t.tween_callback(func():
		GestorTemps.avancar_fins(fposmod(GestorTemps.hora_actual + 8.0, 24.0))
		var perdudes := mini(50, Inventari.diners / 10)
		if perdudes > 0:
			Inventari.gastar_diners(perdudes)
		efecte = ""
		ultim_despertar = Celler.ara() - 8.0   # no has descansat bé
		SalutJugador.curar(ceili(SalutJugador.vida_maxima * 0.3))
		_guardar()
		l.text = "😵 T'has desmaiat de cansament...\n\nDorms 8 hores a terra%s.\nVes a dormir al llit!" % ((" i et pispen %d 🪙" % perdudes) if perdudes > 0 else ""))
	t.tween_property(l, "modulate:a", 1.0, 0.4)
	t.tween_interval(2.5)
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	t.tween_property(fos, "color:a", 0.0, 0.8)
	t.tween_callback(func():
		get_tree().paused = false
		capa.queue_free()
		desmaiant = false
		estat_canviat.emit())

# ─────────────── Desat

func _guardar():
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"ultim_despertar": ultim_despertar, "efecte": efecte, "efecte_fins": efecte_fins}))

func _carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		ultim_despertar = float(d.get("ultim_despertar", ultim_despertar))
		efecte = str(d.get("efecte", ""))
		efecte_fins = float(d.get("efecte_fins", 0.0))
