@tool
extends StaticBody3D
class_name Moll
## Moll de fusta provisional, fet de taulons (es pot substituir per un model propi).
## Va cap a -X des de l'origen: el tram de terra sempre hi és; el tram de mar només quan
## s'ha completat `missio` (abans només s'hi veuen els pals, trencat).

@export var missio := "fusta_moll"
@export var llargada_terra := 9.5:
	set(v): llargada_terra = v; _reconstruir()
@export var llargada_mar := 8.0:
	set(v): llargada_mar = v; _reconstruir()
@export var amplada := 1.6:
	set(v): amplada = v; _reconstruir()
## Alçada de la part de dalt dels taulons (l'herba és a 1.0)
@export var alcada := 1.02:
	set(v): alcada = v; _reconstruir()
@export var fons := -1.0   ## on acaben els pals
@export var color_fusta := Color(0.55, 0.37, 0.22):
	set(v): color_fusta = v; _reconstruir()

const AMPLE_TAULO := 0.4
const GRUIX := 0.14

var tram_mar: Node3D
var forma_mar: CollisionShape3D

func _ready():
	add_to_group("moll")
	_reconstruir()
	if not Engine.is_editor_hint() and not missio.is_empty():
		Missions.missio_completada.connect(func(_m): _actualitzar())

func arreglat() -> bool:
	return Engine.is_editor_hint() or missio.is_empty() or Missions.completada(missio)

func _actualitzar():
	if tram_mar:
		tram_mar.visible = arreglat()
		forma_mar.disabled = not arreglat()

func _reconstruir():
	if not is_inside_tree():
		return
	for c in get_children():
		if c.has_meta("generat"):
			remove_child(c)
			c.queue_free()
	var fusta := StandardMaterial3D.new()
	fusta.albedo_color = color_fusta
	fusta.roughness = 1.0
	var fosca := StandardMaterial3D.new()
	fosca.albedo_color = color_fusta.darkened(0.35)
	fosca.roughness = 1.0

	var tram_terra := _tram(0.0, llargada_terra, fusta)
	tram_mar = _tram(-llargada_mar, 0.0, fusta)
	_forma(tram_terra, 0.0, llargada_terra)
	forma_mar = _forma(tram_mar, -llargada_mar, 0.0)

	# Pals al llarg del tram de mar (es veuen encara que el moll estigui trencat)
	var pals := Node3D.new()
	pals.set_meta("generat", true)
	add_child(pals)
	var pal := CylinderMesh.new()
	pal.top_radius = 0.1
	pal.bottom_radius = 0.1
	pal.height = alcada + 0.15 - fons
	var x := -llargada_mar + 0.2
	while x < 1.0:
		for costat in [-1.0, 1.0]:
			var m := MeshInstance3D.new()
			m.mesh = pal
			m.material_override = fosca
			m.position = Vector3(x, (alcada + 0.15 + fons) / 2.0, costat * (amplada / 2.0 - 0.05))
			pals.add_child(m)
		x += 2.6
	_actualitzar()

## Taulons travessers entre x0 i x1 (amb una mica d'irregularitat)
func _tram(x0: float, x1: float, material: Material) -> Node3D:
	var tram := Node3D.new()
	tram.set_meta("generat", true)
	add_child(tram)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x0 * 100.0) + 7
	var x := x0
	while x < x1 - 0.01:
		var ample := minf(AMPLE_TAULO - 0.04, x1 - x)
		var caixa := BoxMesh.new()
		caixa.size = Vector3(ample, GRUIX, amplada + rng.randf_range(-0.08, 0.08))
		var m := MeshInstance3D.new()
		m.mesh = caixa
		var mat := material.duplicate() as StandardMaterial3D
		mat.albedo_color = mat.albedo_color.lightened(rng.randf_range(-0.08, 0.08))
		m.material_override = mat
		m.position = Vector3(x + ample / 2.0, alcada - GRUIX / 2.0 + rng.randf_range(-0.012, 0.0), rng.randf_range(-0.04, 0.04))
		tram.add_child(m)
		x += AMPLE_TAULO
	return tram

func _forma(tram: Node3D, x0: float, x1: float) -> CollisionShape3D:
	var forma := CollisionShape3D.new()
	forma.set_meta("generat", true)
	var caixa := BoxShape3D.new()
	caixa.size = Vector3(x1 - x0, GRUIX, amplada)
	forma.shape = caixa
	forma.position = Vector3((x0 + x1) / 2.0, alcada - GRUIX / 2.0, 0.0)
	add_child(forma)
	return forma
