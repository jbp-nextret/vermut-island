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

const PECA_HERBA := "cube-top"
const PECA_SORRA := "cube-top_005"
const ALCADA_HERBA := 0
const ALCADA_SORRA := -1
const AMPLADA_PLATJA := 1.6

## Les illes generades: [{centre: Vector3, radi: float, herba: Array[Vector3i]}]
var illes: Array = []

func generar(gridmap: GridMap) -> Array:
	illes.clear()
	var lib := gridmap.mesh_library
	var herba := lib.find_item_by_name(PECA_HERBA)
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
		var celles_herba: Array[Vector3i] = []
		var r_total := ceili(radi + AMPLADA_PLATJA + 1.5)
		for dx in range(-r_total, r_total + 1):
			for dz in range(-r_total, r_total + 1):
				var x := roundi(centre.x) + dx
				var z := roundi(centre.y) + dz
				# Vora irregular: la distància es deforma amb soroll
				var d := Vector2(x - centre.x, z - centre.y).length() + soroll.get_noise_2d(x, z) * 1.5
				if d < radi:
					gridmap.set_cell_item(Vector3i(x, ALCADA_HERBA, z), herba)
					celles_herba.append(Vector3i(x, ALCADA_HERBA, z))
				elif d < radi + AMPLADA_PLATJA:
					gridmap.set_cell_item(Vector3i(x, ALCADA_SORRA, z), sorra)
		illes.append({"centre": Vector3(centre.x, 0.0, centre.y), "radi": radi, "herba": celles_herba})
	return illes

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
