extends Node

var items = {}

func _ready():
	# Per provar, comencem amb 5 llavors de raïm
	afegir("llavor_raim", 150)
	
func afegir(item: String, quantitat: int = 1):
	if items.has(item):
		items[item] += quantitat
	else:
		items[item] = quantitat
	print("Inventari: ", items)

func tenir(item: String) -> int:
	return items.get(item, 0)
