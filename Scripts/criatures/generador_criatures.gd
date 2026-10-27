extends Node
class_name GeneradorCriatures
## Posa criatures salvatges a les illetes (i alguna a la illa principal) i en fa sortir
## de noves quan en domestiques o se n'escapen, sempre lluny del jugador.

const PER_ILLETA := 2
const A_LA_PRINCIPAL := 2
const INTERVAL := 25.0
const DISTANCIA_MINIMA := 16.0   # no apareixen davant del jugador

var mon: Node3D
var gridmap: GridMap
var zones := []       # [{nom, celles: Array[Vector3i], maxim, zona: "illetes"|"principal", criatures: []}]
var temps := 0.0
var rng := RandomNumberGenerator.new()

func configurar(p_mon: Node3D, p_gridmap: GridMap):
	mon = p_mon
	gridmap = p_gridmap

func afegir_zona(nom: String, celles: Array, maxim: int, tipus_zona: String):
	if celles.is_empty():
		return
	zones.append({"nom": nom, "celles": celles, "maxim": maxim, "zona": tipus_zona, "criatures": []})

## El centre de les cel·les d'una zona (per posar-hi les icones al mapa)
func centre_zona(z: Dictionary) -> Vector2:
	if not z.has("centre"):
		var suma := Vector2.ZERO
		for c in z.celles:
			suma += Vector2(c.x + 0.5, c.z + 0.5)
		z.centre = suma / maxf(1.0, z.celles.size())
	return z.centre

func _ready():
	rng.randomize()
	# Al principi: totes plenes (encara que el jugador sigui a prop, que és l'inici)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for z in zones:
		for i in z.maxim:
			_apareixer(z, false)

func _process(delta):
	temps += delta
	if temps < INTERVAL:
		return
	temps = 0.0
	for z in zones:
		z.criatures = z.criatures.filter(func(c): return is_instance_valid(c) and c.is_in_group("criatures_salvatges"))
		if z.criatures.size() < z.maxim:
			_apareixer(z, true)

func _apareixer(z: Dictionary, lluny_del_jugador: bool):
	var e := _triar_especie(z.zona)
	if e == null:
		return
	var jugador := get_tree().get_first_node_in_group("player") as Node3D
	for intent in 12:
		var cella: Vector3i = z.celles[rng.randi() % z.celles.size()]
		var pos := gridmap.to_global(gridmap.map_to_local(cella)) + Vector3.UP * 0.55
		if lluny_del_jugador and jugador and Criatura._pla(jugador.global_position - pos).length() < DISTANCIA_MINIMA:
			continue
		if mon.has_method("zona_de_conreu_a_prop") and mon.zona_de_conreu_a_prop(pos, 3.0):
			continue
		if z.criatures.any(func(altra): return is_instance_valid(altra) and altra.global_position.distance_to(pos) < 3.0):
			continue
		var casa := mon.get_node_or_null("Casa") as Node3D
		if casa and Criatura._pla(casa.global_position - pos).length() < 6.0:
			continue
		var c := Criatura.crear(e)
		mon.add_child(c)
		c.global_position = pos
		c.casa = pos
		c.pos_anterior = pos
		z.criatures.append(c)
		return

func _triar_especie(zona: String) -> EspecieCriatura:
	var candidates: Array = Criatures.especies.values().filter(func(e): return e.zona == "totes" or e.zona == zona)
	if candidates.is_empty():
		return null
	var total := 0.0
	for e in candidates:
		total += e.frequencia
	var r := rng.randf() * total
	for e in candidates:
		r -= e.frequencia
		if r <= 0.0:
			return e
	return candidates.back()
