extends Node
class_name GeneradorIlles
## Genera illetes al voltant de l'illa principal, dins del GridMap.
## Amb la mateixa `llavor` surten sempre les mateixes illes (no cal desar-les): canvia-la
## a l'inspector per provar-ne d'altres. Les illes es generen en carregar el món i no
## toquen l'escena.
##
## Cada illa és un nucli d'herba (on sortiran arbres, roques i herba) envoltat d'una
## franja de platja poc fonda. Entre illes hi ha mar fons: no s'hi pot caminar (cal barca).

@export var llavor := 1234
@export var nombre_illes := 5
@export var radi_min := 3.0
@export var radi_max := 6.0
## Distància (en cel·les) entre la vora de l'illa principal i les illetes
@export var separacio_min := 8.0
@export var separacio_max := 18.0
## Fins on pot arribar el mar (el pla "Sea" fa 128×128)
@export var limit_mar := 58.0

const PECA_HERBA := "cube-top"          # només la superfície d'herba
const PECA_COSTAT := "cube-side"        # herba + talús en un costat
const PECA_CANTONADA := "cube-corner-left"   # herba + talús en dos costats
## Orientació de la peça segons quins costats donen a l'aigua (W, E, N, S), com a l'illa principal
const ORIENTACIO_COSTAT := {"S": 0, "N": 10, "E": 16, "W": 22}
const ORIENTACIO_CANTONADA := {"WS": 0, "EN": 10, "ES": 16, "WN": 22}
const PECA_SORRA := "cube-top_005"
const ALCADA_HERBA := 0
const ALCADA_SORRA := -1
const AMPLADA_PLATJA := 1.6

## Les illes generades: [{centre: Vector3, radi: float, herba: Array[Vector3i]}]
var illes: Array = []

func generar(gridmap: GridMap) -> Array:
	illes.clear()
	var lib := gridmap.mesh_library
	var sorra := lib.find_item_by_name(PECA_SORRA)
	var rng := RandomNumberGenerator.new()
	rng.seed = llavor
	var soroll := FastNoiseLite.new()
	soroll.seed = llavor
	soroll.frequency = 0.25

	# On és i com és de gran l'illa principal (les cel·les de terra per sobre del mar)
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for c in gridmap.get_used_cells():
		if c.y >= ALCADA_HERBA:
			mn = Vector2(minf(mn.x, c.x), minf(mn.y, c.z))
			mx = Vector2(maxf(mx.x, c.x), maxf(mx.y, c.z))
	if mn.x == INF:
		return illes
	var centre_principal := (mn + mx) / 2.0
	var radi_principal := (mx - mn).length() / 2.0

	var intents := 0
	while illes.size() < nombre_illes and intents < 200:
		intents += 1
		var radi := rng.randf_range(radi_min, radi_max)
		var angle := rng.randf() * TAU
		var distancia := radi_principal + rng.randf_range(separacio_min, separacio_max) + radi
		var centre := centre_principal + Vector2.from_angle(angle) * distancia
		if absf(centre.x) + radi + AMPLADA_PLATJA > limit_mar or absf(centre.y) + radi + AMPLADA_PLATJA > limit_mar:
			continue
		# Ni a sobre de res que ja hi hagi, ni enganxada a una altra illeta
		var lliure := true
		for altra in illes:
			if Vector2(altra.centre.x, altra.centre.z).distance_to(centre) < radi + altra.radi + 6.0:
				lliure = false
		if not lliure or _hi_ha_terra(gridmap, centre, radi + AMPLADA_PLATJA + 2.0):
			continue
		# 1. La forma: herba al centre i platja al voltant (vora irregular amb soroll)
		var forma := {}      # Vector2i -> true (herba)
		var platja := []
		var r_total := ceili(radi + AMPLADA_PLATJA + 1.5)
		for dx in range(-r_total, r_total + 1):
			for dz in range(-r_total, r_total + 1):
				var x := roundi(centre.x) + dx
				var z := roundi(centre.y) + dz
				var d := Vector2(x - centre.x, z - centre.y).length() + soroll.get_noise_2d(x, z) * 1.5
				if d < radi:
					forma[Vector2i(x, z)] = true
				if d < radi + AMPLADA_PLATJA:
					platja.append(Vector2i(x, z))
		# 2. Treure les cel·les que no tenen peça que encaixi (aigua a costats oposats o a
		#    tres costats): llengües d'una sola cel·la d'amplada
		_netejar_forma(forma)
		if forma.size() < 6:
			continue
		# 3. Sorra a sota de tota l'illa i de la platja; herba amb talussos a les vores
		for p in platja:
			gridmap.set_cell_item(Vector3i(p.x, ALCADA_SORRA, p.y), sorra)
		var celles_herba: Array[Vector3i] = []
		for p in forma:
			_posar_herba(gridmap, forma, p)
			celles_herba.append(Vector3i(p.x, ALCADA_HERBA, p.y))
		illes.append({"centre": Vector3(centre.x, 0.0, centre.y), "radi": radi, "herba": celles_herba})
	return illes

const VEINS := [["W", Vector2i(-1, 0)], ["E", Vector2i(1, 0)], ["N", Vector2i(0, -1)], ["S", Vector2i(0, 1)]]

## Quins costats d'una cel·la donen a l'aigua ("WS", "N"...)
static func _costats_aigua(forma: Dictionary, p: Vector2i) -> String:
	var clau := ""
	for v in VEINS:
		if not forma.has(p + v[1]):
			clau += v[0]
	return clau

## Treu (repetidament) les cel·les que no tenen cap peça adequada
func _netejar_forma(forma: Dictionary) -> void:
	var canvis := true
	while canvis:
		canvis = false
		for p in forma.keys():
			var clau := _costats_aigua(forma, p)
			if clau.length() >= 3 or clau == "WE" or clau == "NS":
				forma.erase(p)
				canvis = true

## La peça d'herba que toca segons els costats que donen a l'aigua
func _posar_herba(gridmap: GridMap, forma: Dictionary, p: Vector2i) -> void:
	var lib := gridmap.mesh_library
	var cella := Vector3i(p.x, ALCADA_HERBA, p.y)
	var clau := _costats_aigua(forma, p)
	var peca := PECA_HERBA
	var orientacio := 0
	if clau.length() == 1:
		peca = PECA_COSTAT
		orientacio = ORIENTACIO_COSTAT[clau]
	elif ORIENTACIO_CANTONADA.has(clau):
		peca = PECA_CANTONADA
		orientacio = ORIENTACIO_CANTONADA[clau]
	gridmap.set_cell_item(cella, lib.find_item_by_name(peca), orientacio)

func _hi_ha_terra(gridmap: GridMap, centre: Vector2, radi: float) -> bool:
	var r := ceili(radi)
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			for y in range(-2, 3):
				if gridmap.get_cell_item(Vector3i(roundi(centre.x) + dx, y, roundi(centre.y) + dz)) != GridMap.INVALID_CELL_ITEM:
					# El fons marí (sorra a -2) no compta: les illes poden anar a sobre seu
					if y > -2:
						return true
	return false
