extends Node
## Quin temps fa. Cada dia té un temps (sempre el mateix per al mateix dia, no cal desar-lo):
## clar, ennuvolat, pluja, tempesta o boira. La pluja i la tempesta només cauen durant
## unes hores del dia; la boira és de matinada i s'aixeca cap al migdia.
## Els valors (pluja, núvols, boira, vent) canvien suaument perquè no hi hagi salts.

signal temps_canviat(tipus: Tipus)

enum Tipus { CLAR, ENNUVOLAT, PLUJA, TEMPESTA, BOIRA }

const NOMS := ["Clar", "Ennuvolat", "Pluja", "Tempesta", "Boira"]
const ICONES := ["☀", "☁", "🌧", "⛈", "🌫"]
## Probabilitat de cada temps (en tants per cent)
const PROBABILITATS := [45, 22, 17, 7, 9]
const VENT := [0.05, 0.09, 0.13, 0.24, 0.03]
const VELOCITAT_TRANSICIO := 0.4   # per segon real

var tipus: Tipus = Tipus.CLAR
var pluja := 0.0        # 0..1 intensitat
var nuvols := 0.0       # 0..1 quant enfosqueix
var boira := 0.0        # 0..1
var vent := 0.05
var es_tempesta := false

func _process(delta):
	var o := objectiu(GestorTemps.dia_actual, GestorTemps.hora_actual)
	var pas: float = VELOCITAT_TRANSICIO * delta
	pluja = move_toward(pluja, o.pluja, pas)
	nuvols = move_toward(nuvols, o.nuvols, pas)
	boira = move_toward(boira, o.boira, pas * 0.5)
	vent = move_toward(vent, o.vent, pas * 0.2)
	es_tempesta = o.tempesta and pluja > 0.3
	if o.tipus != tipus:
		tipus = o.tipus
		temps_canviat.emit(tipus)

## El temps que fa un dia concret: tipus i, si plou, entre quines hores
func temps_del_dia(dia: int) -> Dictionary:
	if dia <= 1:
		return {"tipus": Tipus.CLAR, "inici": 0.0, "fi": 0.0}   # el primer dia, sempre bo
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("temps del dia %d" % dia)   # un text: números seguits donarien llavors massa semblants
	var tirada := rng.randi_range(0, 99)
	var t := Tipus.CLAR
	var acumulat := 0
	for i in PROBABILITATS.size():
		acumulat += PROBABILITATS[i]
		if tirada < acumulat:
			t = i as Tipus
			break
	var inici := rng.randf_range(7.0, 17.0)
	return {"tipus": t, "inici": inici, "fi": inici + rng.randf_range(2.5, 6.0)}

## Els valors cap on ha d'anar el temps ara mateix
func objectiu(dia: int, hora: float) -> Dictionary:
	var d := temps_del_dia(dia)
	var o := {"tipus": d.tipus, "pluja": 0.0, "nuvols": 0.0, "boira": 0.0, "vent": VENT[d.tipus], "tempesta": false}
	match d.tipus:
		Tipus.ENNUVOLAT:
			o.nuvols = 0.5
		Tipus.PLUJA, Tipus.TEMPESTA:
			var plou: bool = hora >= d.inici and hora < d.fi
			o.nuvols = 0.9 if plou else 0.5
			o.pluja = (1.0 if d.tipus == Tipus.TEMPESTA else 0.6) if plou else 0.0
			o.tempesta = d.tipus == Tipus.TEMPESTA and plou
			if not plou:
				o.tipus = Tipus.ENNUVOLAT
				o.vent = VENT[Tipus.ENNUVOLAT]
		Tipus.BOIRA:
			# Densa de matinada, s'aixeca entre les 9 i les 12
			o.boira = 1.0 - clampf((hora - 9.0) / 3.0, 0.0, 1.0) if hora >= 4.0 else 0.0
			o.nuvols = 0.3 * o.boira
			if o.boira <= 0.0:
				o.tipus = Tipus.CLAR
	return o

func nom() -> String:
	return NOMS[tipus]

func icona() -> String:
	return ICONES[tipus]
