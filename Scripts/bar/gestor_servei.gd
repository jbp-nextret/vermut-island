extends Node
class_name GestorServei
## Controla una sessió de servei: obre la vermuteria, fa entrar clients
## mentre queden seients lliures i tanca quan s'acaba el temps.

signal servei_obert
signal servei_tancat
signal temps_actualitzat(segons_restants: float)
signal comanda_feta(poring: Poring, producte: String)

const PORING := preload("res://Scenes/Poring.tscn")

@export var durada := 300.0          # 5 minuts
@export var interval_min := 4.0      # segons entre clients
@export var interval_max := 9.0

var porta: Marker3D
var obert := false
var temps_restant := 0.0
var temps_seguent_client := 0.0

# Resum del servei actual (es mostra en tancar)
var clients_servits := 0
var clients_enfadats := 0
var guanys := 0

func alternar() -> void:
	if obert:
		tancar()
	else:
		obrir()

func obrir() -> void:
	if obert or not GameState.pot_obrir_vermuteria():
		return
	obert = true
	clients_servits = 0
	clients_enfadats = 0
	guanys = 0
	temps_restant = durada
	temps_seguent_client = 1.0   # el primer client arriba gairebé de seguida
	GameState.mode = GameState.Mode.SERVEI
	servei_obert.emit()
	temps_actualitzat.emit(temps_restant)

func tancar() -> void:
	if not obert:
		return
	obert = false
	for p in get_tree().get_nodes_in_group("porings"):
		p.marxar()
	GameState.mode = GameState.Mode.EXPLORAR
	# Com a Dave the Diver: després del servei ja és de nit
	GestorTemps.avancar_fins(GestorTemps.hora_nit)
	servei_tancat.emit()

func _process(delta: float) -> void:
	if not obert:
		return
	temps_restant -= delta
	temps_actualitzat.emit(maxf(temps_restant, 0.0))
	if temps_restant <= 0.0:
		tancar()
		return
	temps_seguent_client -= delta
	if temps_seguent_client <= 0.0:
		temps_seguent_client = randf_range(interval_min, interval_max)
		_fer_entrar_client()

func _fer_entrar_client() -> void:
	if porta == null:
		push_warning("GestorServei: falta assignar la porta")
		return
	var lliures := get_tree().get_nodes_in_group("seats").filter(func(s): return s.is_free())
	if lliures.is_empty():
		return
	var p: Poring = PORING.instantiate()
	get_parent().add_child(p)
	p.global_position = porta.global_position
	p.setup(lliures.pick_random(), porta.global_position)
	p.order_placed.connect(func(po, producte): comanda_feta.emit(po, producte))
	p.ha_pagat.connect(_on_client_ha_pagat)
	p.ha_marxat_enfadat.connect(func(_po): clients_enfadats += 1)
	p.left.connect(func(_po): _avancar_seguent_client())

func _on_client_ha_pagat(_poring: Poring, quantitat: int) -> void:
	clients_servits += 1
	guanys += quantitat

# Quan un client marxa, el següent no tarda gaire a entrar
func _avancar_seguent_client() -> void:
	if obert:
		temps_seguent_client = minf(temps_seguent_client, randf_range(1.5, 3.0))

func _exit_tree() -> void:
	# Si sortim de la casa amb el bar obert, que el joc no quedi en mode servei
	if obert:
		GameState.mode = GameState.Mode.EXPLORAR
