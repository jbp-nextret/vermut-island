@tool
extends Resource
class_name EspecieCriatura
## Una espècie de criatura que es pot domesticar (s'edita a l'inspector de Godot).
## Els fitxers són a Resources/criatures/ i es carreguen sols.
##
## Com es captura:
##  - Herbívores: s'acosten a menjar les olives marinades que els llances. Mentre mengen,
##    t'hi pots acostar i domesticar-les.
##  - Carnívores (o qualsevol): el vermut hipnòtic les deixa atordides uns segons.
##    Les més fortes (força 4 o més) l'aguanten si no les has debilitat abans.
##  - Llavors, a prop: F i el minijoc de l'anell.

enum Dieta { HERBIVORA, CARNIVORA }
enum Caracter { POREGOSA, TRANQUILLA, AGRESSIVA }
## Què fa quan et segueix
enum Ajuda { ATACAR, REGAR, BUSCAR, LLUM, VELOCITAT, DEFENSA }

const NOMS_HABILITAT := {
	Ajuda.ATACAR: "Lluita al teu costat",
	Ajuda.REGAR: "Rega els cultius amb set",
	Ajuda.BUSCAR: "De tant en tant troba coses",
	Ajuda.LLUM: "Fa llum de nit",
	Ajuda.VELOCITAT: "Corres més",
	Ajuda.DEFENSA: "Reps menys mal",
}

@export var id := ""
@export var nom := ""
@export_multiline var descripcio := ""
@export var dieta: Dieta = Dieta.HERBIVORA
@export var caracter: Caracter = Caracter.TRANQUILLA
## 1 (fàcil) a 5 (molt difícil): més vida, el minijoc és més llarg i ràpid,
## i a partir de 4 cal debilitar-la abans perquè l'hipnosi faci efecte
@export_range(1, 5) var forca := 1
@export var vida := 30
@export var velocitat := 2.2
@export var dany := 8
@export var habilitat: Ajuda = Ajuda.BUSCAR
## Quant fa l'habilitat: mal per cop (ATACAR), +% velocitat (VELOCITAT, 0.12 = 12 %),
## −% de mal rebut (DEFENSA), segons entre troballes (BUSCAR), energia de la llum (LLUM)
@export var valor_habilitat := 1.0
## BUSCAR: què pot trobar (ids de l'inventari)
@export var troballes: PackedStringArray = ["llavor_raim", "fibra"]
## Probabilitat relativa d'aparèixer
@export var frequencia := 1.0
## On surt: a la illa principal, a les illetes o a tot arreu
@export_enum("illetes", "principal", "totes") var zona := "illetes"

@export_group("Aspecte")
## El sprite (mirant a la dreta). Buit: se'n dibuixa un de provisional amb `color`.
@export var sprite: Texture2D
@export var color := Color(0.5, 0.75, 0.35)
@export var mida := 1.0

func text_habilitat() -> String:
	var t: String = NOMS_HABILITAT[habilitat]
	match habilitat:
		Ajuda.VELOCITAT, Ajuda.DEFENSA:
			t += " (%d %%)" % roundi(valor_habilitat * 100.0)
	return t

func text_dieta() -> String:
	return "Herbívora 🫒" if dieta == Dieta.HERBIVORA else "Carnívora 🍷"

func text_caracter() -> String:
	return ["Poruga", "Tranquil·la", "Agressiva"][caracter]

func text_zona() -> String:
	return {"illetes": "Les illetes", "principal": "La illa principal", "totes": "Arreu"}.get(zona, zona)

## Com es pot capturar (consell del bestiari)
func text_captura() -> String:
	var t := "Llança-li olives marinades i, mentre menja, acosta't." if dieta == Dieta.HERBIVORA else "Atordeix-la amb vermut hipnòtic."
	if forca >= 4:
		t += " És molt forta: debilita-la abans (menys de la meitat de vida)."
	return t

## La silueta (per a les que encara no has vist)
func silueta() -> Texture2D:
	var clau := id + "_silueta"
	if not _textures.has(clau):
		var img := textura().get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		for x in img.get_width():
			for y in img.get_height():
				if img.get_pixel(x, y).a > 0.1:
					img.set_pixel(x, y, Color(0.12, 0.11, 0.16))
		_textures[clau] = ImageTexture.create_from_image(img)
	return _textures[clau]

# ─────────────── Sprite provisional

static var _textures := {}

## El sprite de l'espècie, o un de provisional (una boleta amb ulls) fet amb el color
func textura() -> Texture2D:
	if sprite:
		return sprite
	if not _textures.has(id):
		_textures[id] = ImageTexture.create_from_image(_dibuixar())
	return _textures[id]

func _dibuixar() -> Image:
	const M := 32
	var img := Image.create(M, M, false, Image.FORMAT_RGBA8)
	var fosc := color.darkened(0.45)
	var clar := color.lightened(0.25)
	var carnivora := dieta == Dieta.CARNIVORA
	var centre := Vector2(16, 19)
	var radi := Vector2(11.5, 9.5) if not carnivora else Vector2(12.5, 9.0)
	# Orelles: punxegudes les carnívores, rodones les herbívores
	for x in M:
		for y in M:
			var p := Vector2(x + 0.5, y + 0.5)
			var dins := ((p - centre) / radi).length() <= 1.0
			var orella := false
			for costat in [-1.0, 1.0]:
				var base := centre + Vector2(costat * 6.0, -radi.y + 1.5)
				if carnivora:
					var d := p - base
					orella = orella or (d.y < 0 and d.y > -6.5 and absf(d.x) < (6.5 + d.y) * 0.45)
				else:
					orella = orella or p.distance_to(base + Vector2(0, -1.5)) < 2.8
			var pota := y >= 27 and y <= 29 and (absf(x + 0.5 - 11) < 2.0 or absf(x + 0.5 - 21) < 2.0)
			if dins or orella or pota:
				var c := color
				if p.y < centre.y - 3 and dins:
					c = clar
				if pota:
					c = fosc
				img.set_pixel(x, y, c)
	# Contorn fosc
	var copia := img.duplicate() as Image
	for x in M:
		for y in M:
			if copia.get_pixel(x, y).a > 0.0:
				continue
			for v in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + v
				if q.x >= 0 and q.y >= 0 and q.x < M and q.y < M and copia.get_pixelv(q).a > 0.0:
					img.set_pixel(x, y, fosc.darkened(0.3))
					break
	# Ulls (mirant a la dreta)
	for ull in [Vector2i(17, 16), Vector2i(23, 16)]:
		for dx in range(-1, 2):
			for dy in range(-2, 2):
				img.set_pixel(ull.x + dx, ull.y + dy, Color.WHITE)
		img.set_pixel(ull.x + 1, ull.y, Color(0.08, 0.06, 0.1))
		img.set_pixel(ull.x + 1, ull.y - 1, Color(0.08, 0.06, 0.1))
	# Galtes o dents
	if carnivora:
		img.set_pixel(22, 22, Color.WHITE)
		img.set_pixel(25, 22, Color.WHITE)
	else:
		img.set_pixel(14, 20, Color(1.0, 0.6, 0.6))
		img.set_pixel(26, 20, Color(1.0, 0.6, 0.6))
	return img
