extends Node
class_name TransparenciaOcultadors
## Fa semitransparents els objectes que tapen el personatge (la casa, els arbres...).
##
## Els objectes que es poden fer transparents són al grup "ocultables". Un objecte tapa
## el personatge si, vist des de la càmera, el personatge cau dins de la seva silueta
## aproximada (el rectangle que ocupa a la pantalla) i és més a prop de la càmera.

const OPACITAT_TAPANT := 0.45   # quant es veu l'objecte quan tapa (0 = invisible)
const VELOCITAT := 6.0          # rapidesa del fos
const MARGE := 0.15             # fracció del rectangle que no compta (vores)

var jugador: Node3D
var transparencies := {}   # objecte -> transparència actual (0 = opac)
var originals := {}        # malla -> [material de cada superfície abans de fer-la transparent]

func _process(delta):
	if not is_instance_valid(jugador):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var vista := camera.global_transform.affine_inverse()
	var punt_jugador: Vector3 = jugador.posicio_visual if "posicio_visual" in jugador else jugador.global_position
	# Dos punts del personatge: els peus i el cap
	var punts := [punt_jugador + Vector3.UP * 0.3, punt_jugador + Vector3.UP * 1.3]
	var profunditat_jugador := -(vista * punt_jugador).z

	for objecte in get_tree().get_nodes_in_group("ocultables"):
		var tapa := false
		var caixa := _caixa(objecte)
		if caixa.size != Vector3.ZERO and -(vista * caixa.get_center()).z < profunditat_jugador:
			var rect := _rectangle_pantalla(camera, caixa)
			rect = rect.grow_individual(-rect.size.x * MARGE, -rect.size.y * MARGE, -rect.size.x * MARGE, 0.0)
			for p in punts:
				if not camera.is_position_behind(p) and rect.has_point(camera.unproject_position(p)):
					tapa = true
		var objectiu := 1.0 - OPACITAT_TAPANT if tapa else 0.0
		var actual: float = transparencies.get(objecte, 0.0)
		if is_equal_approx(actual, objectiu):
			continue
		actual = move_toward(actual, objectiu, VELOCITAT * delta)
		transparencies[objecte] = actual
		for m in _malles(objecte):
			_aplicar(m, actual)

## La caixa que ocupa l'objecte al món (unint totes les seves malles)
func _caixa(objecte: Node) -> AABB:
	var resultat := AABB()
	var primer := true
	for m in _malles(objecte):
		var c: AABB = m.global_transform * m.get_aabb()
		resultat = c if primer else resultat.merge(c)
		primer = false
	return resultat

func _malles(objecte: Node) -> Array:
	var llista := objecte.find_children("*", "GeometryInstance3D", true, false)
	if objecte is GeometryInstance3D:
		llista.append(objecte)
	return llista

func _rectangle_pantalla(camera: Camera3D, caixa: AABB) -> Rect2:
	var rect := Rect2()
	for i in 8:
		var p := camera.unproject_position(caixa.get_endpoint(i))
		rect = Rect2(p, Vector2.ZERO) if i == 0 else rect.expand(p)
	return rect

## Les malles amb material estàndard reben una còpia del material en mode semitransparent
## (funciona amb tots els renderitzadors); en tornar a opac, recuperen el seu material.
## La resta (sprites amb shader propi) fan servir la propietat `transparency`.
func _aplicar(m: GeometryInstance3D, transparencia: float):
	if not m is MeshInstance3D or m.mesh == null:
		m.transparency = transparencia
		return
	var malla := m as MeshInstance3D
	if transparencia <= 0.001:
		if originals.has(malla):
			for i in originals[malla].size():
				malla.set_surface_override_material(i, originals[malla][i])
			originals.erase(malla)
		return
	if not originals.has(malla):
		var llista := []
		for i in malla.mesh.get_surface_count():
			llista.append(malla.get_surface_override_material(i))
			var actiu := malla.get_active_material(i)
			if actiu is BaseMaterial3D:
				var copia: BaseMaterial3D = actiu.duplicate()
				copia.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				malla.set_surface_override_material(i, copia)
		originals[malla] = llista
	for i in malla.mesh.get_surface_count():
		var mat := malla.get_surface_override_material(i)
		if mat is BaseMaterial3D and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
			mat.albedo_color.a = 1.0 - transparencia
