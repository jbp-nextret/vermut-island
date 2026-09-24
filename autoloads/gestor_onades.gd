extends Node
## Onades de la setmana: una cada nit de dilluns a divendres, cada cop més difícil.
## Les nits de dissabte i diumenge són lliures per preparar-se.
## Cada setmana nova, les onades tenen més enemics i més vida.

signal onada_comencada(info: Dictionary)
signal nit_lliure(info: Dictionary)
signal onada_acabada(resum: Dictionary)

const DIES := ["Dilluns", "Dimarts", "Dimecres", "Dijous", "Divendres", "Dissabte", "Diumenge"]

const ENEMICS := {
	"ratpenat_petit": preload("res://Scenes/Enemic.tscn"),
	"ratpenat": preload("res://Scenes/EnemicVolador.tscn"),
}

## Composició de la primera setmana, de dilluns (0) a divendres (4)
const ONADES := [
	{"ratpenat_petit": 3},
	{"ratpenat_petit": 5},
	{"ratpenat_petit": 5, "ratpenat": 2},
	{"ratpenat_petit": 7, "ratpenat": 3},
	{"ratpenat_petit": 9, "ratpenat": 6},
]

const MES_ENEMICS_PER_SETMANA := 0.3   # +30 % d'enemics cada setmana
const MES_VIDA_PER_SETMANA := 0.2      # +20 % de vida cada setmana
const PART_DE_LA_NIT_SPAWNEJANT := 0.55  # els enemics arriben durant la primera meitat de la nit
const DINERS_PER_ENEMIC := 2
const BONUS_PER_NIVELL := 8           # bonus per superar l'onada: 8, 16... 40 (divendres), × setmana

var dia_onada := -1        # dia (GestorTemps.dia_actual) en què va començar la nit de l'onada
var activa := false
var pendents: Array[String] = []
var vius: Array[String] = []   # tipus dels enemics que hi ha ara mateix al món
var total := 0
var morts := 0
var cultius_perduts := 0
var multiplicador_vida := 1.0
var interval := 2.0
var temps_seguent := 0.0

var spawner: Node3D = null

# ─────────────── Calendari

static func dia_setmana(dia: int) -> int:
	return posmod(dia - 1, 7)

static func setmana(dia: int) -> int:
	return (dia - 1) / 7 + 1

static func hi_ha_onada(dia: int) -> bool:
	return dia_setmana(dia) < 5

## La nit comença un dia i acaba l'endemà: la de dilluns va de dilluns a les 20 h a dimarts a les 6 h
func dia_de_la_nit() -> int:
	return GestorTemps.dia_actual if GestorTemps.hora_actual >= 12.0 else GestorTemps.dia_actual - 1

func nom_del_dia(dia: int) -> String:
	return DIES[dia_setmana(dia)]

# ─────────────── Spawner del món

func registrar_spawner(node: Node3D) -> void:
	spawner = node
	# Si havíem sortit del món amb enemics vius, tornen a venir
	pendents.append_array(vius)
	vius.clear()

func desregistrar_spawner(node: Node3D) -> void:
	if spawner == node:
		spawner = null

# ─────────────── Cicle

func _process(delta: float) -> void:
	if not is_instance_valid(spawner):
		return   # només hi ha onades quan el jugador és al món
	if GestorTemps.es_nit():
		var dia := dia_de_la_nit()
		if dia != dia_onada:
			_comencar(dia)
		if activa:
			_spawnejar(delta)
			if pendents.is_empty() and vius.is_empty():
				_acabar(true)
	elif activa:
		_acabar(false)   # ha arribat l'alba

func _comencar(dia: int) -> void:
	dia_onada = dia
	var info := {"dia": nom_del_dia(dia), "numero": dia_setmana(dia) + 1, "setmana": setmana(dia)}
	if not hi_ha_onada(dia):
		activa = false
		nit_lliure.emit(info)
		return

	var n := setmana(dia) - 1
	pendents.clear()
	for tipus in ONADES[dia_setmana(dia)]:
		var quantitat := int(ceil(ONADES[dia_setmana(dia)][tipus] * (1.0 + MES_ENEMICS_PER_SETMANA * n)))
		for i in quantitat:
			pendents.append(tipus)
	pendents.shuffle()
	vius.clear()
	total = pendents.size()
	morts = 0
	cultius_perduts = 0
	multiplicador_vida = 1.0 + MES_VIDA_PER_SETMANA * n

	# Els enemics arriben repartits al llarg de la primera part de la nit
	var durada_nit: float = GestorTemps.durada_dia * (10.0 / 24.0)
	interval = maxf(0.4, durada_nit * PART_DE_LA_NIT_SPAWNEJANT / total)
	temps_seguent = 1.5
	activa = true
	info["total"] = total
	onada_comencada.emit(info)

func _spawnejar(delta: float) -> void:
	if pendents.is_empty():
		return
	temps_seguent -= delta
	if temps_seguent > 0.0:
		return
	temps_seguent = interval
	var tipus: String = pendents.pop_back()
	var enemic: Node = spawner.spawnejar(ENEMICS[tipus], multiplicador_vida)
	enemic.set_meta("tipus_onada", tipus)
	vius.append(tipus)

func _acabar(superada: bool) -> void:
	activa = false
	var fugits := vius.size()
	for enemic in get_tree().get_nodes_in_group("enemics"):
		if enemic.has_method("fugir"):
			enemic.fugir()
	vius.clear()
	pendents.clear()

	var bonus := BONUS_PER_NIVELL * (dia_setmana(dia_onada) + 1) * setmana(dia_onada) if superada else 0
	var diners := morts * DINERS_PER_ENEMIC + bonus
	if diners > 0:
		Inventari.afegir_diners(diners)
	onada_acabada.emit({
		"dia": nom_del_dia(dia_onada),
		"superada": superada,
		"morts": morts,
		"total": total,
		"fugits": fugits,
		"cultius_perduts": cultius_perduts,
		"diners": diners,
		"bonus": bonus,
	})

# ─────────────── Avisos dels enemics i cultius

func enemic_mort(enemic: Node) -> void:
	if not enemic.has_meta("tipus_onada"):
		return
	vius.erase(enemic.get_meta("tipus_onada"))
	morts += 1

func cultiu_perdut() -> void:
	if activa:
		cultius_perduts += 1

## Text curt per al HUD
func estat_text() -> String:
	if activa:
		return "🌙 Onada del %s (%d/5) · Enemics: %d/%d" % [nom_del_dia(dia_onada), dia_setmana(dia_onada) + 1, morts, total]
	var avui: int = GestorTemps.dia_actual
	if GestorTemps.es_nit():
		return "🌙 Nit tranquil·la"
	if hi_ha_onada(avui):
		return "Aquesta nit: onada %d de 5" % (dia_setmana(avui) + 1)
	return "Aquesta nit és lliure: prepara't per a la setmana!"
