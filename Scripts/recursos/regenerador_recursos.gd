extends Node
class_name RegeneradorRecursos
## Fa sortir recursos nous cada dia, com a Stardew Valley: brots d'arbre que creixen fins
## a fer-se grans, roques i herba. Cada zona (les illetes i, amb menys densitat, l'illa
## principal) té una densitat objectiu; cada dia se'n creen uns quants fins arribar-hi.
## Els recursos creats així es desen amb la partida.

## Recursos per cel·la d'herba de la zona
const DENSITAT := {
	RecursNatural.Tipus.ARBRE: 1.0 / 16.0,
	RecursNatural.Tipus.ROCA: 1.0 / 25.0,
	RecursNatural.Tipus.HERBA: 1.0 / 7.0,
}
## Quants en poden sortir cada dia (per zona i tipus)
const NOUS_PER_DIA := {
	RecursNatural.Tipus.ARBRE: 2,
	RecursNatural.Tipus.ROCA: 1,
	RecursNatural.Tipus.HERBA: 3,
}
const DISTANCIA_ENTRE_RECURSOS := 1.6
const DISTANCIA_CASA := 7.0
const ESCENA_ROCA := preload("res://Scenes/recursos/roca.tscn")

var mon: Node3D
var gridmap: GridMap
## [{nom, factor (multiplica la densitat), celles: Array[Vector3i]}]
var zones: Array = []
## Còpies de l'arbre i l'herba de l'escena, fetes en carregar el món. No es fan servir
## els originals directament: si el Tree1 estava talat (amagat) o semitransparent,
## totes les còpies sortien igual (invisibles).
var model_arbre: Node3D
var model_herba: Node3D
var rng := RandomNumberGenerator.new()
var ultim_dia := -1
var recursos: Array[RecursNatural] = []

func configurar(p_mon: Node3D, p_gridmap: GridMap, p_model_arbre: Node3D, p_model_herba: Node3D):
	mon = p_mon
	gridmap = p_gridmap
	model_arbre = _plantilla(p_model_arbre)
	model_herba = _plantilla(p_model_herba)
	rng.randomize()

## Una còpia neta del model: visible, opac, a la mida d'adult i sense el seu Recurs
func _plantilla(model: Node3D) -> Node3D:
	if model == null:
		return null
	var copia := model.duplicate() as Node3D
	var recurs := copia.get_node_or_null("Recurs")
	if recurs:
		copia.remove_child(recurs)
		recurs.free()
	copia.visible = true
	if copia is GeometryInstance3D:
		copia.transparency = 0.0
	copia.set_meta("alcada_sobre_terra", model.get_meta("alcada_sobre_terra", 0.0))
	return copia

func _exit_tree():
	for m in [model_arbre, model_herba]:
		if is_instance_valid(m) and not m.is_inside_tree():
			m.free()

func afegir_zona(nom: String, celles: Array, factor: float = 1.0):
	zones.append({"nom": nom, "factor": factor, "celles": celles})

func _process(_delta):
	var dia: int = GestorTemps.dia_actual
	if dia != ultim_dia:
		var primer_cop := ultim_dia < 0
		ultim_dia = dia
		regenerar(primer_cop and recursos.is_empty())

## Omple les zones fins a la densitat. `inicial`: la primera vegada, de cop i amb arbres
## de totes les mides (si no, hi hauria només brots)
func regenerar(inicial := false):
	recursos = recursos.filter(func(r): return is_instance_valid(r))
	for zi in zones.size():
		var zona: Dictionary = zones[zi]
		for tipus in DENSITAT:
			var objectiu := floori(zona.celles.size() * DENSITAT[tipus] * zona.factor)
			var actuals := recursos.filter(func(r): return r.get_meta("zona", -1) == zi and r.tipus == tipus).size()
			var nous := objectiu - actuals
			if not inicial:
				nous = mini(nous, NOUS_PER_DIA[tipus])
			for i in nous:
				var cella = _cella_lliure(zona.celles)
				if cella == null:
					break
				var etapa := 0
				if tipus == RecursNatural.Tipus.ARBRE and inicial:
					etapa = rng.randi_range(0, 2)
				crear(tipus, cella, etapa, GestorTemps.dia_actual, zi)

func crear(tipus: int, cella: Vector3i, etapa: int, dia_etapa: int, zona: int) -> RecursNatural:
	var visual: Node3D
	var recurs: RecursNatural
	var terra := _superficie(cella)
	match tipus:
		RecursNatural.Tipus.ROCA:
			visual = ESCENA_ROCA.instantiate()
			mon.add_child(visual)
			visual.global_position = terra
			visual.rotation.y = rng.randf() * TAU
			recurs = visual.get_node("Recurs")
		_:
			var model := model_arbre if tipus == RecursNatural.Tipus.ARBRE else model_herba
			visual = model.duplicate()
			# A la mateixa alçada sobre el terra que el model de l'escena
			var alcada_model: float = model.get_meta("alcada_sobre_terra", 0.0)
			mon.add_child(visual)
			visual.global_position = terra + Vector3.UP * alcada_model
			recurs = RecursNatural.new()
			recurs.terra_y = terra.y
			recurs.alcada_adult = alcada_model
			recurs.name = "Recurs"
			recurs.tipus = tipus
			# Abans d'afegir-lo: en el seu _ready ja es posa a la mida de l'etapa
			recurs.dinamic = true
			recurs.etapa = etapa if tipus == RecursNatural.Tipus.ARBRE else 2
			recurs.dia_etapa = dia_etapa
			if tipus == RecursNatural.Tipus.ARBRE:
				recurs.cops = 3
				recurs.objecte = "fusta"
				recurs.quantitat_min = 2
				recurs.quantitat_max = 4
				recurs.motiu_xp = "talar"
				recurs.dies_per_etapa = 2
			else:
				recurs.cops = 1
				recurs.objecte = "fibra"
				recurs.quantitat_min = 1
				recurs.quantitat_max = 2
				recurs.motiu_xp = "herba"
			visual.add_child(recurs)
	recurs.dinamic = true
	recurs.dia_etapa = dia_etapa
	recurs.set_meta("zona", zona)
	recurs.set_meta("cella", cella)
	if tipus == RecursNatural.Tipus.ARBRE:
		visual.add_to_group("ocultables")
	recursos.append(recurs)
	return recurs

## Una cel·la de la zona on no hi hagi res a prop (ni conreu, ni la casa, ni el jugador)
func _cella_lliure(celles: Array):
	var casa := mon.get_node_or_null("Casa") as Node3D
	var jugador := mon.get_node_or_null("Personatge") as Node3D
	for intent in 12:
		var cella: Vector3i = celles[rng.randi() % celles.size()]
		if gridmap.get_cell_item(cella + Vector3i.UP) != GridMap.INVALID_CELL_ITEM:
			continue
		var p := _superficie(cella)
		if casa and Vector2(p.x - casa.global_position.x, p.z - casa.global_position.z).length() < DISTANCIA_CASA:
			continue
		if jugador and p.distance_to(jugador.global_position) < 3.0:
			continue
		if mon.has_method("zona_de_conreu_a_prop") and mon.zona_de_conreu_a_prop(p, 2.0):
			continue
		var ocupada := false
		for r in get_tree().get_nodes_in_group("recursos"):
			if Vector2(r.global_position.x - p.x, r.global_position.z - p.z).length() < DISTANCIA_ENTRE_RECURSOS:
				ocupada = true
				break
		if not ocupada:
			return cella
	return null

func _superficie(cella: Vector3i) -> Vector3:
	var p := gridmap.to_global(gridmap.map_to_local(cella))
	p.y = gridmap.to_global(Vector3(0, cella.y + 1, 0)).y
	return p

# ─────────────── Desar / carregar

func estat() -> Array:
	var llista := []
	for r in recursos:
		if is_instance_valid(r) and r.disponible():
			var c: Vector3i = r.get_meta("cella")
			llista.append({"tipus": r.tipus, "cella": [c.x, c.y, c.z], "etapa": r.etapa, "dia_etapa": r.dia_etapa, "zona": r.get_meta("zona", 0)})
	return llista

func restaurar(llista: Array):
	for d in llista:
		var c: Array = d.get("cella", [0, 0, 0])
		crear(int(d.get("tipus", 0)), Vector3i(int(c[0]), int(c[1]), int(c[2])), int(d.get("etapa", 2)), int(d.get("dia_etapa", 0)), int(d.get("zona", 0)))
	ultim_dia = GestorTemps.dia_actual   # ja té el que tocava: no omplir de cop
