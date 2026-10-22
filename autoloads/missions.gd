extends Node
## Gestor de missions. Les missions són Resources a Resources/missions/ (vegeu missio.gd).
## Es desa a user://missions.save.
##
## Per fer-ho servir des dels diàlegs de Dialogic:
##   if Missions.pot_lliurar("fusta_moll"):      ja ho té tot: toca lliurar-la
##   elif Missions.activa("fusta_moll"):         l'està fent
##   elif Missions.disponible("fusta_moll"):     la pot acceptar
##   elif Missions.completada("fusta_moll"):     ja l'ha fet
##   do Missions.acceptar("fusta_moll")
##   do Missions.lliurar("fusta_moll")           gasta els objectes i dona les recompenses

signal missio_acceptada(missio: Missio)
signal objectiu_completat(missio: Missio, index: int)
signal missio_llesta(missio: Missio)          # tots els objectius fets: cal tornar al donant
signal missio_completada(missio: Missio)
signal missions_canviades

const CARPETA := "res://Resources/missions/"
const FITXER := "user://missions.save"

var missions := {}   # id -> Missio
## id -> {"estat": "activa"|"completada", "progres": [int, ...]}
var estat := {}

func _ready():
	_carregar_missions()
	carregar()
	Progressio.accio_feta.connect(_on_accio_feta)
	Inventari.items_canviats.connect(_comprovar_portar)

func _carregar_missions():
	for fitxer in ResourceLoader.list_directory(CARPETA):
		if fitxer.ends_with(".tres") or fitxer.ends_with(".res"):
			var m = load(CARPETA + fitxer)
			if m is Missio and not m.id.is_empty():
				missions[m.id] = m

func missio(id: String) -> Missio:
	return missions.get(id)

# ─────────────── Consultes (també des dels diàlegs)

func activa(id: String) -> bool:
	return estat.get(id, {}).get("estat", "") == "activa"

func completada(id: String) -> bool:
	return estat.get(id, {}).get("estat", "") == "completada"

func iniciada(id: String) -> bool:
	return estat.has(id)

## Es pot acceptar: no s'ha començat i es compleixen les condicions
func disponible(id: String) -> bool:
	var m := missio(id)
	if m == null or iniciada(id):
		return false
	for previa in m.missions_previes:
		if not completada(previa):
			return false
	for r in m.requisits:
		if r and not r.complert():
			return false
	return true

## Té tots els objectius fets i ja la pot lliurar
func pot_lliurar(id: String) -> bool:
	if not activa(id):
		return false
	var m := missio(id)
	for i in m.objectius.size():
		if progres(id, i) < m.objectius[i].objectiu():
			return false
	return true

## Progrés d'un objectiu (els de PORTAR es miren a la motxilla en el moment)
func progres(id: String, index: int) -> int:
	var m := missio(id)
	if m == null or not iniciada(id):
		return 0
	var o: ObjectiuMissio = m.objectius[index]
	if completada(id):
		return o.objectiu()
	if o.tipus == ObjectiuMissio.Tipus.PORTAR:
		return Inventari.tenir(o.objecte)
	var p: Array = estat[id].progres
	return p[index] if index < p.size() else 0

func missions_actives() -> Array:
	return estat.keys().filter(func(id): return activa(id) and missions.has(id)).map(func(id): return missions[id])

func missions_completades() -> Array:
	return estat.keys().filter(func(id): return completada(id) and missions.has(id)).map(func(id): return missions[id])

## Què es mostra sobre el cap d'un NPC: "?" si li pots lliurar una missió, "!" si en té
## una per donar, "…" si és l'objectiu d'una conversa, o "" si res
func marcador_npc(npc_id: String) -> String:
	for m in missions.values():
		if m.donant == npc_id and pot_lliurar(m.id):
			return "?"
	for m in missions.values():
		if m.donant == npc_id and disponible(m.id):
			return "!"
	for m in missions_actives():
		for i in m.objectius.size():
			var o: ObjectiuMissio = m.objectius[i]
			if o.tipus == ObjectiuMissio.Tipus.PARLAR and o.npc == npc_id and progres(m.id, i) < 1:
				return "…"
	return ""

# ─────────────── Accions (també des dels diàlegs)

func acceptar(id: String) -> void:
	if not disponible(id):
		return
	var m := missio(id)
	var p := []
	p.resize(m.objectius.size())
	p.fill(0)
	estat[id] = {"estat": "activa", "progres": p}
	missio_acceptada.emit(m)
	_canvi()
	_comprovar_portar()

## Lliura la missió: gasta els objectes que demanava i dona les recompenses
func lliurar(id: String) -> void:
	if not pot_lliurar(id):
		return
	var m := missio(id)
	for o in m.objectius:
		if o.tipus == ObjectiuMissio.Tipus.PORTAR:
			Inventari.treure(o.objecte, o.quantitat)
	estat[id].estat = "completada"
	if m.diners > 0:
		Inventari.afegir_diners(m.diners)
	for o in m.objectes:
		Inventari.afegir(o, int(m.objectes[o]))
	if m.xp > 0:
		Progressio.guanyar_xp_directa(m.xp, "missio")
	missio_completada.emit(m)
	_canvi()

# ─────────────── El que fa el jugador

func parlat_amb(npc_id: String) -> void:
	_avancar(ObjectiuMissio.Tipus.PARLAR, func(o): return o.npc == npc_id, 1)

func arribat(lloc: String) -> void:
	_avancar(ObjectiuMissio.Tipus.ARRIBAR, func(o): return o.lloc == lloc, 1)

func _on_accio_feta(motiu: String, quantitat: int) -> void:
	# "enemic_petit" també compta com a "enemic"
	var accio := "enemic" if motiu == "enemic_petit" else motiu
	_avancar(ObjectiuMissio.Tipus.ACCIO, func(o): return o.accio == accio, quantitat)

func _avancar(tipus: int, coincideix: Callable, quantitat: int) -> void:
	var canviat := false
	for m in missions_actives():
		var p: Array = estat[m.id].progres
		for i in m.objectius.size():
			var o: ObjectiuMissio = m.objectius[i]
			if o.tipus != tipus or not coincideix.call(o) or p[i] >= o.objectiu():
				continue
			p[i] = mini(p[i] + quantitat, o.objectiu())
			canviat = true
			if p[i] >= o.objectiu():
				objectiu_completat.emit(m, i)
		if canviat and pot_lliurar(m.id):
			missio_llesta.emit(m)
	if canviat:
		_canvi()

## Els objectius de PORTAR depenen de la motxilla: avisa quan es completen
var _portar_avisats := {}
func _comprovar_portar() -> void:
	for m in missions_actives():
		for i in m.objectius.size():
			var o: ObjectiuMissio = m.objectius[i]
			if o.tipus != ObjectiuMissio.Tipus.PORTAR:
				continue
			var clau := "%s:%d" % [m.id, i]
			var fet := Inventari.tenir(o.objecte) >= o.quantitat
			if fet and not _portar_avisats.get(clau, false):
				objectiu_completat.emit(m, i)
				if pot_lliurar(m.id):
					missio_llesta.emit(m)
			_portar_avisats[clau] = fet
	missions_canviades.emit()

func _canvi():
	missions_canviades.emit()
	guardar()

# ─────────────── Desar / carregar

func guardar() -> void:
	var f := FileAccess.open(FITXER, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(estat))

func carregar() -> void:
	var f := FileAccess.open(FITXER, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		estat = {}
		for id in d:
			var e: Dictionary = d[id]
			estat[id] = {"estat": str(e.get("estat", "activa")), "progres": Array(e.get("progres", [])).map(func(v): return int(v))}
