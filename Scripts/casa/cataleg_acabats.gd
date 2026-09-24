class_name CatalegAcabats
## Tots els acabats que es poden comprar per a la casa.
## (preload i no DirAccess: així també funciona en el joc exportat)

const TERRA_PER_DEFECTE := "terra_rajola"
const PARET_PER_DEFECTE := "paret_blanc"

const TOTS := [
	preload("res://Resources/acabats/terra_rajola.tres"),
	preload("res://Resources/acabats/terra_fusta_clara.tres"),
	preload("res://Resources/acabats/terra_fusta_fosca.tres"),
	preload("res://Resources/acabats/terra_terracota.tres"),
	preload("res://Resources/acabats/terra_marbre.tres"),
	preload("res://Resources/acabats/paret_blanc.tres"),
	preload("res://Resources/acabats/paret_blau.tres"),
	preload("res://Resources/acabats/paret_verd.tres"),
	preload("res://Resources/acabats/paret_mostassa.tres"),
	preload("res://Resources/acabats/paret_rosa.tres"),
	preload("res://Resources/acabats/paret_vermut.tres"),
]

static func de_superficie(superficie: AcabatInterior.Superficie) -> Array:
	return TOTS.filter(func(a): return a.superficie == superficie)

static func per_id(id: String) -> AcabatInterior:
	for a in TOTS:
		if a.id == id:
			return a
	return null
