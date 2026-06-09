extends Node

var items = {}

func afegir(item: String, quantitat: int = 1):
	if items.has(item):
		items[item] += quantitat
	else:
		items[item] = quantitat
	print("Inventari: ", items)

func tenir(item: String) -> int:
	return items.get(item, 0)
