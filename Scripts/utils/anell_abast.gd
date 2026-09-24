extends Node3D
class_name AnellAbast
## Cercle pla a terra que marca un abast: una vora fina i un farcit molt suau.

static var _materials := {}

static func crear(pare: Node3D, radi: float, color: Color) -> AnellAbast:
	var anell := AnellAbast.new()
	pare.add_child(anell)
	anell.configurar(radi, color)
	anell.position = Vector3.UP * 0.04
	return anell

func configurar(radi: float, color: Color) -> void:
	for fill in get_children():
		fill.queue_free()

	# Vora: un tor molt prim, que ja és horitzontal (pla XZ)
	var vora := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = maxf(0.01, radi - 0.07)
	tor.outer_radius = radi
	tor.rings = 64
	tor.ring_segments = 4
	vora.mesh = tor
	vora.material_override = _material(Color(color.r, color.g, color.b, 0.75))
	vora.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	vora.scale.y = 0.3
	add_child(vora)

	# Farcit: disc gairebé transparent
	var farcit := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radi
	disc.bottom_radius = radi
	disc.height = 0.01
	disc.radial_segments = 48
	disc.rings = 1
	farcit.mesh = disc
	farcit.material_override = _material(Color(color.r, color.g, color.b, 0.08))
	farcit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(farcit)

## Un sol material per color (no se'n crea un de nou per cada cultiu)
static func _material(color: Color) -> StandardMaterial3D:
	var clau := color.to_html()
	if not _materials.has(clau):
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = color
		_materials[clau] = mat
	return _materials[clau]
