class_name CatalegObjectes
## Nom, icona i descripció de cada objecte de l'inventari.
## Els que no hi són es mostren amb el seu identificador i una caixa.

const OBJECTES := {
	"llavor_raim": {"nom": "Llavors", "icona": "🌱", "descripcio": "Llavors per plantar qualsevol cultiu de l'hort. En culls més quan fas collita."},
	"raim": {"nom": "Raïm", "icona": "🍇", "descripcio": "Collit dels ceps. A la barrica el pots posar a fermentar per fer vermut."},
	"fusta": {"nom": "Fusta", "icona": "🪵", "descripcio": "La dels arbres que tales amb la destral màgica. Servirà per construir i fabricar."},
	"fibra": {"nom": "Fibra", "icona": "🌾", "descripcio": "La treus de tallar l'herba amb l'espasa. Servirà per fer cordes i teixits."},
	"pedra": {"nom": "Pedra", "icona": "🪨", "descripcio": "La pices de les roques amb el pic màgic. Servirà per construir."},
	"vermut": {"nom": "Vermut negre", "icona": "🍷", "descripcio": "El vermut de la casa. Es fa fermentant raïm a la barrica (1 dia). Es serveix a la vermuteria i és ingredient d'altres receptes."},
	"vermut_blanc": {"nom": "Vermut blanc", "icona": "🥂", "descripcio": "Més suau i aromàtic: raïm i herbes (fibra) fermentats dia i mig. Els clients en paguen més."},
	"vermut_reserva": {"nom": "Vermut reserva", "icona": "🥃", "descripcio": "Envellit tres dies a la barrica amb un toc d'oliva. El més car de la carta."},
	"eina_espasa": {"nom": "Espasa espectral", "icona": "⚔️", "descripcio": "Eina. Posa-la a la barra ràpida: clic per fer un tall, clic dret per a l'estocada. Talla l'herba i en treu fibra."},
	"eina_destral": {"nom": "Destral màgica", "icona": "🪓", "descripcio": "Eina. Amb ella a la mà, clica un arbre per talar-lo i treure'n fusta (i a vegades olives)."},
	"eina_pic": {"nom": "Pic màgic", "icona": "⛏️", "descripcio": "Eina. Amb ell a la mà, clica una roca per picar-la i treure'n pedra."},
	"corda": {"nom": "Corda", "icona": "🪢", "descripcio": "Fibra trenada. Serveix per fabricar portes, eines i altres coses."},
	"tanca_pedra": {"nom": "Tanca de pedra", "icona": "🧱", "descripcio": "Com la de fusta, però de pedra. També tanca corrals."},
	"galeta_criatura": {"nom": "Galeta de criatura", "icona": "🍪", "descripcio": "Tria-la a la barra ràpida per donar-la a la criatura que et segueix: guanya experiència (+30)."},
	"galeta_daurada": {"nom": "Galeta daurada", "icona": "🥮", "descripcio": "Una llaminadura excepcional: la criatura que et segueix guanya molta experiència (+120)."},
	"vermut_hipnotic_fort": {"nom": "Vermut hipnòtic fort", "icona": "🔮", "descripcio": "Es llança com el vermut hipnòtic, però arriba més lluny i atordeix fins i tot les criatures més fortes sense debilitar-les."},
	"pinzell_arqueoleg": {"nom": "Pinzell d'arqueòleg", "icona": "🖌️", "descripcio": "Mentre el portis, a l'excavació delicada la paret aguanta més i el pinzell la fa trontollar menys."},
	"bruixola_tresors": {"nom": "Brúixola de tresors", "icona": "🧭", "descripcio": "Mentre la portis, el mapa et marca on hi ha punts d'excavació (i si amaguen alguna cosa important)."},
	"planol": {"nom": "Plànol", "icona": "📜", "descripcio": "Un plànol antic: t'ensenya una recepta nova per a la taula de fabricació."},
	"tanca_fusta": {"nom": "Tanca de fusta", "icona": "🪵", "descripcio": "Posa-la a la barra ràpida i clica a terra per construir. Si tanques una zona del tot, es converteix en un corral per a les criatures."},
	"porta_tanca": {"nom": "Porta de tanca", "icona": "🚪", "descripcio": "Una tanca per on es pot passar. Tanca el corral igual que una tanca, i és on hi ha la cistella."},
	"eina_grimori_foc": {"nom": "Grimori de foc", "icona": "🔥", "descripcio": "Eina. Amb ell a la mà, cada clic llança una bola de foc cap al ratolí (gasta mana)."},
	"eina_regadora": {"nom": "Regadora màgica", "icona": "💧", "descripcio": "Eina. Clic sobre la terra per regar-la amb un encanteri. L'aigua es recupera sola o amb la pluja."},
	"eina_aixada": {"nom": "Aixada màgica", "icona": "⛏", "descripcio": "Eina. Llaura l'herba per fer-la cultivable. Si hi ha una marca de terra remoguda, desenterra el que hi ha."},
	"olives": {"nom": "Olives", "icona": "🫒", "descripcio": "De les oliveres de l'illa (a vegades en cauen quan tales un arbre). A la barrica les pots marinar."},
	"olives_marinades": {"nom": "Olives marinades", "icona": "🥗", "descripcio": "Llança-les (L) a prop d'una criatura herbívora: s'hi acostarà a menjar i la podràs domesticar."},
	"vermut_hipnotic": {"nom": "Vermut hipnòtic", "icona": "🧪", "descripcio": "Llança'l (L) a una criatura: la deixa atordida uns segons i la podràs domesticar. Les més fortes, debilita-les abans."},
}

static func info(id: String) -> Dictionary:
	if OBJECTES.has(id):
		return OBJECTES[id]
	# Fòssils i tresors: els defineix l'arqueologia
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre and arbre.root.has_node("Arqueologia"):
		var i: Dictionary = arbre.root.get_node("Arqueologia").info_objecte(id)
		if not i.is_empty():
			return i
	return {"nom": id.capitalize(), "icona": "📦", "descripcio": ""}
