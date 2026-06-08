# GameManager.gd
extends Node

signal day_advanced(day: int)

var current_day := 0
var plots: Array[PlotTile3D] = []

func register_plot(plot: PlotTile3D) -> void:
	plots.append(plot)

func advance_day() -> void:
	current_day += 1
	for plot in plots:
		plot.advance_day()
	day_advanced.emit(current_day)

func open_seed_selector(plot: PlotTile3D) -> void:
	# Obre la UI de selecció de llavors i connecta el resultat
	var ui = preload("res://UI/SeedSelector.tscn").instantiate()
	ui.seed_selected.connect(func(seed): plot.plant(seed))
	get_tree().root.add_child(ui)
