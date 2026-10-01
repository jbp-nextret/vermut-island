extends Node
## Experiència, nivells i habilitats del jugador. Es desa a user://progressio.save.
##  - guanyar_xp("collir") cada vegada que el jugador fa alguna cosa
##  - cada nivell dona PUNTS_PER_NIVELL punts d'habilitat (un per arbre), que es gasten
##    als arbres (menú K)
##  - valor("dany_espasa") retorna l'efecte total d'una habilitat (rangs × per_rang)

signal xp_guanyada(quantitat: int, motiu: String)
signal nivell_pujat(nivell: int)
signal habilitats_canviades

const FITXER := "user://progressio.save"

## Experiència per cada acció
const XP := {
	"enemic_petit": 8, "enemic": 15, "onada": 30,
	"plantar": 2, "regar": 1, "collir": 5, "llaurar": 1,
	"servir": 4, "obrir_vermuteria": 10,
}

## Un punt per a cada arbre (màgia d'atac, màgia útil i mundà), però es poden gastar on es vulgui
const PUNTS_PER_NIVELL := 3
## Versió del fitxer desat (2: tres punts per nivell)
const VERSIO := 2

const VIDA_BASE := 100
const ESPAIS_BASE := 8

var nivell := 1
var xp := 0
var punts := 0
var habilitats := {}   # id -> rang
var _desat_pendent := false

func _ready():
	carregar()
	call_deferred("_aplicar_efectes")

## Experiència per passar del nivell `n` al següent (40, 113, 208, 320...)
static func xp_per_nivell(n: int) -> int:
	return roundi(40.0 * pow(n, 1.5))

func guanyar_xp(motiu: String, multiplicador: float = 1.0) -> void:
	var quantitat := roundi(XP.get(motiu, 0) * multiplicador)
	if quantitat <= 0:
		return
	xp += quantitat
	xp_guanyada.emit(quantitat, motiu)
	while xp >= xp_per_nivell(nivell):
		xp -= xp_per_nivell(nivell)
		nivell += 1
		punts += PUNTS_PER_NIVELL
		SalutJugador.curar(SalutJugador.vida_maxima)   # pujar de nivell et cura
		nivell_pujat.emit(nivell)
	_desar_aviat()

# ─────────────── Habilitats

func rang(id: String) -> int:
	return habilitats.get(id, 0)

func valor(id: String) -> float:
	var h := ArbreHabilitats.habilitat(id)
	return h.per_rang * rang(id) if h else 0.0

## Si l'habilitat es pot fer servir (com a mínim un rang)
func te(id: String) -> bool:
	return rang(id) > 0

## Per què no es pot millorar ("" si sí que es pot)
func motiu_bloqueig(id: String) -> String:
	var h := ArbreHabilitats.habilitat(id)
	if h == null or h.max <= 0:
		return "Encara no està disponible"
	if rang(id) >= h.max:
		return "Ja està al màxim"
	# Els requisits només compten per desbloquejar-la (el primer rang)
	if rang(id) == 0:
		for r in h.requisits:
			if r and not r.complert():
				return "Cal: " + r.text()
	if punts <= 0:
		return "No tens punts (en guanyes %d per nivell)" % PUNTS_PER_NIVELL
	return ""

func millorar(id: String) -> bool:
	if not motiu_bloqueig(id).is_empty():
		return false
	# En desbloquejar-la, es gasten els objectes o diners que demana
	if rang(id) == 0:
		for r in ArbreHabilitats.habilitat(id).requisits:
			if r:
				r.pagar()
	habilitats[id] = rang(id) + 1
	punts -= 1
	_aplicar_efectes()
	habilitats_canviades.emit()
	guardar()
	return true

## Els efectes que viuen fora del jugador (vida màxima, espais de la motxilla)
func _aplicar_efectes():
	SalutJugador.vida_maxima = VIDA_BASE + roundi(valor("salut_max"))
	SalutJugador.vida_actual = mini(SalutJugador.vida_actual, SalutJugador.vida_maxima)
	SalutJugador.emit_signal("vida_canviat", SalutJugador.vida_actual, SalutJugador.vida_maxima)
	Inventari.max_espais = ESPAIS_BASE + roundi(valor("motxilla"))

# ─────────────── Desar / carregar

func _desar_aviat():
	if not _desat_pendent:
		_desat_pendent = true
		call_deferred("guardar")

func guardar():
	_desat_pendent = false
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"versio": VERSIO, "nivell": nivell, "xp": xp, "punts": punts, "habilitats": habilitats}))

func carregar():
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	nivell = int(d.get("nivell", 1))
	xp = int(d.get("xp", 0))
	punts = int(d.get("punts", 0))
	# Partides d'abans, quan només es guanyava un punt per nivell: els que falten
	if int(d.get("versio", 1)) < 2:
		punts += (nivell - 1) * (PUNTS_PER_NIVELL - 1)
	habilitats = {}
	var h = d.get("habilitats", {})
	if h is Dictionary:
		for id in h:
			habilitats[id] = int(h[id])
