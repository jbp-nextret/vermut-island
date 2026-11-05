extends Node3D
class_name Llit
## El llit (provisional: fet amb codi, es pot substituir per un model propi).
## Va com a fill de l'escena de moble del llit. F a prop: tries fins a quina hora vols
## dormir (MenuDormir). L'origen del moble és a 0,5 per sobre del terra.

func _ready():
	_construir()
	if get_parent().is_in_group("decoracio") or get_parent().is_in_group("mobles_base"):
		add_to_group("interactuables")
		get_parent().add_to_group("llits")

func punt_interaccio() -> Vector3:
	return global_position

func pot_interactuar(jugador: InteraccioJugador) -> bool:
	return not jugador.porta_objecte() and GameState.mode == GameState.Mode.EXPLORAR

func text_interaccio(_jugador: InteraccioJugador) -> String:
	return "Dormir"

func interactuar(_jugador: InteraccioJugador) -> void:
	MenuDormir.obrir(self)

# ─────────────── Model provisional

func _construir():
	var fusta := _material(Color(0.45, 0.28, 0.16))
	var llencol := _material(Color(0.92, 0.9, 0.84))
	var manta := _material(Color(0.62, 0.2, 0.25))
	var coixi := _material(Color(0.98, 0.97, 0.93))
	# Estructura i potes (el terra és a y = -0.5)
	_caixa(Vector3(0.9, 0.18, 0.92), Vector3(0, -0.27, 0), fusta)
	_caixa(Vector3(0.9, 0.5, 0.08), Vector3(0, -0.2, -0.44), fusta)   # capçal
	_caixa(Vector3(0.84, 0.1, 0.84), Vector3(0, -0.13, 0.0), llencol)  # matalàs
	_caixa(Vector3(0.86, 0.06, 0.52), Vector3(0, -0.06, 0.17), manta)  # manta
	_caixa(Vector3(0.5, 0.08, 0.2), Vector3(0, -0.05, -0.26), coixi)   # coixí
	var cos := StaticBody3D.new()
	var forma := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(0.9, 0.5, 0.92)
	forma.shape = b
	forma.position = Vector3(0, -0.25, 0)
	cos.add_child(forma)
	add_child(cos)

func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _caixa(mida: Vector3, pos: Vector3, mat: Material):
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = mida
	m.mesh = bm
	m.material_override = mat
	m.position = pos
	add_child(m)
