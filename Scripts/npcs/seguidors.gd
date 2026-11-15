extends RefCounted
class_name Seguidors
## Per als que et segueixen (companys del grup i criatures): quan s'han quedat massa lluny
## no apareixen de cop al teu costat, sinó en un punt de terra fora de la pantalla, des
## d'on vénen caminant (corrent) fins a tu.

const DISTANCIES := [8.0, 10.0, 12.0, 6.5]
const ANGLES := [0.0, 30.0, -30.0, 60.0, -60.0, 100.0, -100.0, 150.0, -150.0, 180.0]

## Un punt fora de la vista des d'on es pot arribar caminant al jugador, o null si no n'hi ha
static func punt_fora_de_vista(qui: Node3D, jugador: Node3D) -> Variant:
	if not qui.is_inside_tree() or jugador == null:
		return null
	var camera := qui.get_viewport().get_camera_3d()
	var mon := qui.get_tree().current_scene
	var aigua: float = mon.nivell_aigua() if mon and mon.has_method("nivell_aigua") else -INF
	var espai := qui.get_world_3d().direct_space_state
	var exclou: Array[RID] = [jugador.get_rid()]
	if qui is CollisionObject3D:
		exclou.append(qui.get_rid())
	# Primer, pel costat d'on venia
	var dir := Vector3(qui.global_position.x - jugador.global_position.x, 0.0, qui.global_position.z - jugador.global_position.z)
	if dir.length() < 0.1:
		dir = Vector3.BACK
	dir = dir.normalized()
	for distancia in DISTANCIES:
		for angle in ANGLES:
			var p: Vector3 = jugador.global_position + dir.rotated(Vector3.UP, deg_to_rad(angle)) * distancia
			var terra = _terra(espai, p, exclou, aigua)
			if terra == null or absf(terra.y - jugador.global_position.y) > 2.5:
				continue
			if camera and camera.is_position_in_frustum(terra + Vector3.UP * 0.6):
				continue
			if _cami_per_terra(espai, jugador.global_position, terra, exclou, aigua):
				return terra
	return null

## On toca a terra (per sobre de l'aigua), o null
static func _terra(espai: PhysicsDirectSpaceState3D, p: Vector3, exclou: Array[RID], aigua: float) -> Variant:
	var raig := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 5.0, p + Vector3.DOWN * 6.0, 1)
	raig.exclude = exclou
	var cop := espai.intersect_ray(raig)
	if cop.is_empty() or cop.normal.y < 0.7 or cop.position.y < aigua - 0.3:
		return null
	return cop.position

## Que hi hagi terra tot el camí (no una altra illa a l'altra banda de l'aigua)
static func _cami_per_terra(espai: PhysicsDirectSpaceState3D, des_de: Vector3, fins: Vector3, exclou: Array[RID], aigua: float) -> bool:
	var passos := ceili(Vector2(fins.x - des_de.x, fins.z - des_de.z).length() / 1.2)
	for i in range(1, passos):
		var t := float(i) / passos
		var terra = _terra(espai, des_de.lerp(fins, t), exclou, aigua)
		if terra == null or absf(terra.y - des_de.lerp(fins, t).y) > 2.5:
			return false
	return true
