extends Node2D

@onready var timer: Timer = $Timer

const CARD_BACK_TEXTURE: Texture2D = preload("res://assets/other/backside.png")

var cardslist = {1: [], 2: [], 3: []}
var hovered_cards = []
var current_card = null
var active_tweens = {}
var move_tweens = {}

var numbers = range(11).map(func(i): return str(i))
var specials = ["m5", "p3", "x2", "death", "m10", "skip", "discard"]
var allcards = numbers + specials

var score = 0
var playerturn = 1
var time_remaining = 30
var timeout_effect_active = false
var timeout_losing_player = 0

var plusthree = null
var timestwo = null
var skip = null
var plays_remaining = {1: 1, 2: 1}
var action_in_progress = false


func _ready() -> void:
	var draw_area := $Draw/Area2D as Area2D
	draw_area.input_pickable = true
	draw_area.input_event.connect(_on_draw_input_event)

	var card1
	var card2
	for i in range(6):
		card1 = allcards[randi_range(0, allcards.size() - 1)]
		card2 = allcards[randi_range(0, allcards.size() - 1)]
		if card1 == "death" or card2 == "death":
			allcards.erase("death")
		addcard(card1, 2)
		addcard(card2, 1)

	_update_card_faces()
	_update_timer_display()

	timer.stop()
	timer.one_shot = true
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timeout)
	timer.start()


func _on_timeout() -> void:
	if timeout_effect_active:
		return

	$Clock1/ClockArrow.rotate(deg_to_rad(45))
	$Clock2/ClockArrow.rotate(deg_to_rad(45))

	time_remaining -= 1
	_update_timer_display()

	if time_remaining <= 0:
		timer.stop()
		timeout_effect_active = true
		_start_timeout_effect()
	else:
		timer.start()


func _update_timer_display() -> void:
	var tens := int(time_remaining / 10)
	var ones := int(time_remaining % 10)

	$timerthing/num1.texture = load("res://assets/timernums/%s.png" % tens) as Texture2D
	$timerthing/num2.texture = load("res://assets/timernums/%s.png" % ones) as Texture2D


func _start_timeout_effect() -> void:
	timeout_losing_player = playerturn
	var other_player := 2 if timeout_losing_player == 1 else 1
	var penalty_count := randi_range(2, 3)

	var losing_hand := _container_for_player(timeout_losing_player)
	var discard_pile := _container_for_player(3)

	var cards_to_return: Array[Node2D] = []
	var return_count := mini(penalty_count, discard_pile.get_child_count())

	for i in range(return_count):
		var index := discard_pile.get_child_count() - 1 - i
		cards_to_return.append(discard_pile.get_child(index) as Node2D)

	await get_tree().create_timer(0.5).timeout

	_animate_timeout_clock_arrows(penalty_count)

	var lose_count := mini(penalty_count, losing_hand.get_child_count())
	for i in range(lose_count):
		if losing_hand.get_child_count() == 0:
			break

		var random_index := randi_range(0, losing_hand.get_child_count() - 1)
		var card := losing_hand.get_child(random_index) as Node2D
		await _fade_out_card(card)

	for card in cards_to_return:
		if is_instance_valid(card) and card.get_parent() == discard_pile:
			await _animate_card_move(card, other_player, true)

	await get_tree().create_timer(penalty_count * 0.15 + 0.2).timeout
	_finish_timeout_effect(other_player)


func _fade_out_card(card: Node2D) -> void:
	if not is_instance_valid(card):
		return

	var player: int = card.get_meta("player", 0)
	if not cardslist.has(player):
		return

	var card_type: String = card.get_meta("cardtype", "")

	hovered_cards.erase(card)
	if current_card == card:
		current_card = null

	if active_tweens.has(card):
		active_tweens[card].kill()
		active_tweens.erase(card)

	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 0.0, 1)
	await tween.finished

	if not is_instance_valid(card):
		return

	cardslist[player].erase(card_type)
	card.get_parent().remove_child(card)
	card.queue_free()

	_reflow_cards(player)
	_update_hover()


func _finish_timeout_effect(next_player: int) -> void:
	playerturn = next_player
	time_remaining = 30
	timeout_effect_active = false

	_update_timer_display()
	_update_card_faces()

	timer.wait_time = 1.0
	timer.start()


func _animate_timeout_clock_arrows(tick_count: int) -> void:
	var losing_arrow: Node2D
	var other_arrow: Node2D

	if timeout_losing_player == 1:
		losing_arrow = $Clock1/ClockArrow
		other_arrow = $Clock2/ClockArrow
	else:
		losing_arrow = $Clock2/ClockArrow
		other_arrow = $Clock1/ClockArrow

	var losing_start := losing_arrow.rotation
	var other_start := other_arrow.rotation
	var step := deg_to_rad(45.0)

	var tween := create_tween()

	for i in range(tick_count):
		var step_number := i + 1
		tween.tween_property(
			losing_arrow,
			"rotation",
			losing_start + step * step_number,
			0.15
		)
		tween.parallel().tween_property(
			other_arrow,
			"rotation",
			other_start - step * step_number,
			0.15
		)

	await tween.finished


func _animate_card_move(card: Node2D, to_player: int, fade_in: bool) -> void:
	if not is_instance_valid(card):
		return

	var from_player: int = card.get_meta("player", 0)
	if not cardslist.has(from_player) or not cardslist.has(to_player):
		return

	var new_hand := _container_for_player(to_player)
	var card_type: String = card.get_meta("cardtype", "")

	if active_tweens.has(card):
		active_tweens[card].kill()
		active_tweens.erase(card)

	hovered_cards.erase(card)
	if current_card == card:
		current_card = null

	if to_player == 3:
		_disconnect_hover(card)

	cardslist[from_player].erase(card_type)
	cardslist[to_player].append(card_type)

	var start_global_position := card.global_position
	card.reparent(new_hand, true)
	card.set_meta("player", to_player)

	if to_player == 1 or to_player == 2:
		_connect(card)

	_reflow_cards(from_player)
	_reflow_cards(to_player)

	var destination := card.global_position
	card.global_position = start_global_position

	if fade_in:
		card.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(card, "global_position", destination, 2)

	if fade_in:
		tween.parallel().tween_property(card, "modulate:a", 1.0, 0.35)

	await tween.finished

	card.modulate.a = 1.0
	_update_card_faces()


func _on_draw_input_event(
	_viewport: Viewport,
	event: InputEvent,
	_shape_idx: int
) -> void:
	if timeout_effect_active or action_in_progress:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		draw_card()


func draw_card() -> void:
	if timeout_effect_active or action_in_progress:
		return

	if playerturn != 1 and playerturn != 2:
		return

	if allcards.is_empty():
		print("No cards available to draw")
		return

	var card_type: String = str(allcards[randi_range(0, allcards.size() - 1)])
	addcard(card_type, playerturn)

	score += 5
	_update_score_display()

	if score >= 67:
		print("player ", playerturn, " lost")
		get_tree().paused = true
		return

	if card_type == "death":
		allcards.erase("death")

	_finish_player_action()
	print("Drew ", card_type, "; next player: ", playerturn)


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

	_update_card_faces()


func move_card(card: Node2D, to_player: int) -> void:
	if card == null or not is_instance_valid(card):
		return
	if not cardslist.has(to_player):
		return

	var from_player: int = card.get_meta("player", 0)
	if not cardslist.has(from_player) or from_player == to_player:
		return

	var new_hand := _container_for_player(to_player)
	var card_type: String = card.get_meta("cardtype", "")

	if active_tweens.has(card):
		active_tweens[card].kill()
		active_tweens.erase(card)

	hovered_cards.erase(card)
	if current_card == card:
		current_card = null

	if to_player == 3:
		_disconnect_hover(card)
	else:
		_connect(card)

	cardslist[from_player].erase(card_type)
	cardslist[to_player].append(card_type)

	var start_position := card.global_position
	card.reparent(new_hand, true)
	card.set_meta("player", to_player)

	_reflow_cards(from_player)
	_reflow_cards(to_player)

	var destination := card.global_position
	card.global_position = start_position
	card.z_index = 100

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card, "global_position", destination, 0.5)

	move_tweens[card] = tween
	tween.finished.connect(_on_play_tween_finished.bind(card))

	_update_hover()
	_update_card_faces()


func _on_play_tween_finished(card: Node2D) -> void:
	if not is_instance_valid(card):
		return

	move_tweens.erase(card)

	var player: int = card.get_meta("player", 0)
	if player == 3:
		_reflow_cards(3)


func _reflow_cards(player: int) -> void:
	var hand := _container_for_player(player)
	var card_count := hand.get_child_count()

	for i in range(card_count):
		var card := hand.get_child(i) as Node2D

		if player == 3:
			card.position = Vector2.ZERO
			card.z_index = i
		else:
			card.position = Vector2(i * -75.0 / card_count, 0)
			card.z_index = -i


func _update_card_faces() -> void:
	for player in [1, 2]:
		var hand := _container_for_player(player)
		for card in hand.get_children():
			var sprite := findchild(card, "Sprite2D") as Sprite2D
			if sprite == null:
				continue

			if player == playerturn:
				var card_type: String = card.get_meta("cardtype", "")
				var path := "res://assets/cards/%s.png" % card_type
				if ResourceLoader.exists(path):
					sprite.texture = load(path) as Texture2D
				else:
					sprite.texture = CARD_BACK_TEXTURE
			else:
				sprite.texture = CARD_BACK_TEXTURE


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


func _update_hover() -> void:
	var valid_cards: Array = []
	for card in hovered_cards:
		if is_instance_valid(card) and not card.is_queued_for_deletion():
			valid_cards.append(card)
	hovered_cards = valid_cards

	if not is_instance_valid(current_card) or current_card.is_queued_for_deletion():
		current_card = null

	var highest_card = null
	for card in hovered_cards:
		if highest_card == null or card.get_index() < highest_card.get_index():
			highest_card = card

	if highest_card == current_card:
		return

	if is_instance_valid(current_card):
		_animate_card(current_card, 0)
		current_card.z_index = -current_card.get_index()

	current_card = highest_card

	if is_instance_valid(current_card):
		current_card.z_index = 100
		_animate_card(current_card, -10)


func _highlight(card: Node) -> void:
	if not hovered_cards.has(card):
		hovered_cards.append(card)
	_update_hover()


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
	if timeout_effect_active or action_in_progress:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if current_card == null:
			return

		var owner: int = current_card.get_meta("player", 0)
		if owner != playerturn:
			return

		if owner == 1 or owner == 2:
			var card_type: String = current_card.get_meta("cardtype", "")
			var other_player := 2 if owner == 1 else 1

			var score_change: int = 0
			var applies_score_modifier := false

			if card_type in numbers:
				score_change = int(card_type)
				applies_score_modifier = true
			else:
				match card_type:
					"m5":
						score_change = -5
						applies_score_modifier = true
					"m10":
						score_change = -10
						applies_score_modifier = true
					"p3":
						plusthree = other_player
					"x2":
						timestwo = other_player
					"death":
						score = 65
					"skip":
						plays_remaining[other_player] = 2
					"discard":
						action_in_progress = true
						await _discard_random_cards(other_player, 2)
						action_in_progress = false

			if applies_score_modifier:
				if plusthree == owner:
					score_change += 3
					plusthree = null

			if timestwo == owner:
				score_change *= 2
				timestwo = null

			score += score_change

			print(card_type, " score ", score)
			_update_score_display()

			if score >= 67:
				print("player ", owner, " lost")
				get_tree().paused = true
				return

			move_card(current_card, 3)

			_finish_player_action()

			_update_card_faces()


func _discard_random_cards(player: int, amount: int) -> void:
	var hand := _container_for_player(player)
	var discard_count := mini(amount, hand.get_child_count())

	for i in range(discard_count):
		if hand.get_child_count() == 0:
			break

		var index := randi_range(0, hand.get_child_count() - 1)
		var card := hand.get_child(index) as Node2D
		await _fade_out_card(card)

func _finish_player_action() -> void:
	var acting_player: int = int(playerturn)

	if int(plays_remaining[acting_player]) > 1:
		plays_remaining[acting_player] = int(plays_remaining[acting_player]) - 1
	else:
		plays_remaining[acting_player] = 1
		playerturn = 2 if acting_player == 1 else 1

	_update_card_faces()


func _update_score_display() -> void:
	var displayed_score: int = maxi(int(score), 0)
	var tens: int = int(displayed_score / 10) % 10
	var ones: int = displayed_score % 10

	$Scorebox/num1.texture = load("res://assets/timernums/%s.png" % tens) as Texture2D
	$Scorebox/num2.texture = load("res://assets/timernums/%s.png" % ones) as Texture2D
