extends Area3D

func conte_punt(posicio: Vector3) -> bool:
	# Comprova si un punt 3D és dins l'Area3D
	var posicio_local = to_local(posicio)
	var shape = $CollisionShape3D.shape
	
	if shape is BoxShape3D:
		var mida = shape.size / 2.0
		return abs(posicio_local.x) <= mida.x and \
			   abs(posicio_local.y) <= mida.y + 1.0 and \
			   abs(posicio_local.z) <= mida.z
	
	return false
