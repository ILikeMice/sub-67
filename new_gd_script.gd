extends Node2D

var cardslist = {1: [], 2: [], 3: []}
var hovered_cards = []
var current_card = null
var active_tweens = {}

var numbers = range(11).map(func(i): return str(i))
var specials = ["m5", "p3", "x2", "death","m10","skip","switch","discard"]
var allcards = numbers + specials

var score = 0
var playerturn = 1


func _ready() -> void:
	for i in range(6):
		addcard(allcards[randi_range(0, allcards.size() - 1)], 2)
		addcard(allcards[randi_range(0, allcards.size() - 1)], 1)


func _container_for_player(player: int) -> Node2D:
	return get_node("Cards_%d" % player) as Node2D


func addcard(card_type: String, player: int) -> void:
	if not cardslist.has(player):
		push_warning("Invalid player: %d" % player)
		return

	var createdcard := Node2D.new()
	var carea := Area2D.new()
	var ccs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var sprite := Sprite2D.new()

	var path := "res://assets/cards/%s.png" % card_type
	if ResourceLoader.exists(path):
		sprite.texture = load(path) as Texture2D
	else:
		push_warning("Card texture not found: %s" % path)

	rect.size = Vector2(37, 50)
	ccs.shape = rect
	carea.add_child(ccs)

	createdcard.add_child(sprite)
	createdcard.add_child(carea)
	createdcard.set_meta("cardtype", card_type)
	createdcard.set_meta("player", player)

	cardslist[player].append(card_type)

	var hand := _container_for_player(player)
	hand.set_meta("player", player)
	hand.add_child(createdcard)
	_reflow_cards(player)

	if player == 1 or player == 2:
		_connect(createdcard)


func move_card(card: Node2D, to_player: int) -> void:
	if card == null or not cardslist.has(to_player):
		return

	var from_player: int = card.get_meta("player", 0)
	if not cardslist.has(from_player) or from_player == to_player:
		return

	var old_hand := _container_for_player(from_player)
	var new_hand := _container_for_player(to_player)
	var card_type: String = card.get_meta("cardtype", "")

	if active_tweens.has(card):
		active_tweens[card].kill()
		active_tweens.erase(card)

	var sprite := findchild(card, "Sprite2D") as Sprite2D
	if sprite != null:
		sprite.position.y = 0

	hovered_cards.erase(card)
	if current_card == card:
		current_card = null

	# Cards moved to player 3 should no longer react to mouse hover.
	if to_player == 3:
		_disconnect_hover(card)

	cardslist[from_player].erase(card_type)
	cardslist[to_player].append(card_type)

	old_hand.remove_child(card)
	new_hand.add_child(card)
	card.set_meta("player", to_player)

	_reflow_cards(from_player)
	_reflow_cards(to_player)
	_update_hover()


func _reflow_cards(player: int) -> void:
	var hand := _container_for_player(player)
	var card_count := hand.get_child_count()

	for i in range(card_count):
		var card := hand.get_child(i) as Node2D

		if player == 3:
			# Stack cards in one position, newest on top.
			card.position = Vector2.ZERO
			card.z_index = i
		else:
			# Preserve the original spacing for players 1 and 2.
			card.position = Vector2(i * -75.0 / card_count, 0)
			card.z_index = -i


func _connect(card: Node) -> void:
	for child in card.get_children():
		if child is Area2D:
			var area := child as Area2D
			var enter_callable := _highlight.bind(card)
			var exit_callable := _unhigh.bind(card)

			if not area.mouse_entered.is_connected(enter_callable):
				area.mouse_entered.connect(enter_callable)
			if not area.mouse_exited.is_connected(exit_callable):
				area.mouse_exited.connect(exit_callable)
			break


func _disconnect_hover(card: Node) -> void:
	for child in card.get_children():
		if child is Area2D:
			var area := child as Area2D
			var enter_callable := _highlight.bind(card)
			var exit_callable := _unhigh.bind(card)

			if area.mouse_entered.is_connected(enter_callable):
				area.mouse_entered.disconnect(enter_callable)
			if area.mouse_exited.is_connected(exit_callable):
				area.mouse_exited.disconnect(exit_callable)
			break


func _unhigh(card: Node) -> void:
	hovered_cards.erase(card)
	_update_hover()


func _highlight(card: Node) -> void:
	if not hovered_cards.has(card):
		hovered_cards.append(card)
	_update_hover()


func _update_hover() -> void:
	var highest_card = null

	for card in hovered_cards:
		if highest_card == null or card.get_index() < highest_card.get_index():
			highest_card = card

	if highest_card == current_card:
		return

	if current_card != null:
		_animate_card(current_card, 0)
		current_card.z_index = -current_card.get_index()

	current_card = highest_card

	if current_card != null:
		current_card.z_index = 100
		_animate_card(current_card, -10)


func _animate_card(card: Node, target_y: float) -> void:
	if active_tweens.has(card):
		active_tweens[card].kill()

	var sprite := findchild(card, "Sprite2D") as Sprite2D
	if sprite == null:
		return

	var target_pos := Vector2(sprite.position.x, target_y)
	var tween := create_tween()
	active_tweens[card] = tween
	tween.tween_property(sprite, "position", target_pos, 0.1)


func findchild(parent: Node, type_name: String) -> Node:
	for child in parent.get_children():
		if child.is_class(type_name):
			return child
	return null


func _input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
		and current_card != null
	):
		var owner: int = current_card.get_meta("player", 0)
		if owner != playerturn: return;
		if owner == 1 or owner == 2:
			print(current_card.get_meta("cardtype"))
			if playerturn == 1:
				playerturn = 2
			elif playerturn == 2:
				playerturn = 1
			print(playerturn)
			if current_card.get_meta("cardtype") in numbers:
				score += int(current_card.get_meta("cardtype"))
			else:
				match current_card.get_meta("cardtype"):
					"m5":
						print("m5")
					"p3":
						print("p3")
					"x2":
						print("x2")
					"death":
						print("death")
					"m10":
						print("m10")
					"skip":
						print("skip")
					"switch":
						print("switch")
					"discard":
						print("discard")
			print(current_card.get_meta("cardtype"), " score ", score)
			move_card(current_card, 3)
