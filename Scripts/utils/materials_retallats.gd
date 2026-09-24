extends Node3D
class_name MaterialsRetallats
## Converteix els materials transparents ("Blend") d'un model en retallats (alpha scissor).
##
## Els objectes transparents no escriuen profunditat i Godot els ordena pel seu centre,
## així que l'aigua o altres objectes transparents es poden pintar per sobre d'on no toca.
## Per al pixel art no cal transparència suau: amb retallar per l'alfa n'hi ha prou.
##
## Posa aquest script a l'arrel d'una escena de model, o crida MaterialsRetallats.aplicar(node).
## (La solució definitiva és exportar el material des de Blender en mode "Alpha Clip".)

func _ready():
	aplicar(self)

static func aplicar(node: Node) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in node.mesh.get_surface_count():
			var material = node.get_active_material(i)
			# Els materials "Blend" de Blender arriben com a Alpha o com a Alpha + depth pre-pass
			if material is BaseMaterial3D and material.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA, BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS]:
				var retallat: BaseMaterial3D = material.duplicate()
				retallat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				retallat.alpha_scissor_threshold = 0.5
				node.set_surface_override_material(i, retallat)
	for fill in node.get_children():
		aplicar(fill)
