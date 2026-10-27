@tool
extends Resource
class_name Recepta
## Una recepta de fabricació (s'edita a l'inspector). Els fitxers són a
## Resources/receptes/ i es carreguen sols.
##   - lloc: on es fa ("taula" = taula de fabricació màgica, "barrica" = la barrica)
##   - planol: si cal haver trobat el plànol (als tresors d'arqueologia) per fer-la
##   - ingredients: id de l'objecte -> quantitat ("vermut" = vermut preparat o raïm)

@export var id := ""
@export var resultat := ""
@export var quantitat := 1
@export var ingredients: Dictionary[String, int] = {}
@export_enum("taula", "barrica") var lloc := "taula"
@export_enum("Construcció", "Eines", "Criatures", "Arqueologia", "Begudes") var categoria := "Construcció"
@export var planol := false
## Ordre dins de la categoria
@export var ordre := 0
