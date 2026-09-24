class_name AssignadorTaules
## Reparteix les barres entre els seients: cada barra fa de taula d'un sol seient,
## i cada seient pot fer servir una barra del costat (no en diagonal).
##
## Busca el repartiment que dona taula a més seients (aparellament bipartit).
## Així, si una cadira pot fer servir dues barres i una altra només una,
## la primera cedeix la compartida en lloc de deixar la segona sense taula.

const DISTANCIA := 1.05   # una cel·la de distància

## `posicions`: on és cada seient. `preferides`: índex de la barra que ja tenia (o -1),
## perquè en recalcular els seients no canviïn de taula sense motiu.
## Retorna, per a cada seient, l'índex de la seva barra dins `barres`, o -1.
static func assignar(posicions: Array, preferides: Array, barres: Array) -> Array:
	var veines := []
	for i in posicions.size():
		var llista := []
		for j in barres.size():
			if _al_costat(posicions[i], barres[j].global_position):
				llista.append(j)
		var preferida: int = preferides[i]
		if preferida != -1 and llista.has(preferida):
			llista.erase(preferida)
			llista.push_front(preferida)
		veines.append(llista)

	var seient_de_barra := []
	seient_de_barra.resize(barres.size())
	seient_de_barra.fill(-1)
	for i in posicions.size():
		_buscar_barra(i, veines, seient_de_barra, {})

	var resultat := []
	resultat.resize(posicions.size())
	resultat.fill(-1)
	for j in barres.size():
		if seient_de_barra[j] != -1:
			resultat[seient_de_barra[j]] = j
	return resultat

static func _buscar_barra(i: int, veines: Array, seient_de_barra: Array, visitades: Dictionary) -> bool:
	for j in veines[i]:
		if visitades.has(j):
			continue
		visitades[j] = true
		# Barra lliure, o el seient que la té pot passar-se'n a una altra
		if seient_de_barra[j] == -1 or _buscar_barra(seient_de_barra[j], veines, seient_de_barra, visitades):
			seient_de_barra[j] = i
			return true
	return false

static func _al_costat(a: Vector3, b: Vector3) -> bool:
	return Vector2(a.x - b.x, a.z - b.z).length() <= DISTANCIA
