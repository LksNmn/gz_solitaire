
extends Node

# this node creates the deck, shuffles the cards and keeps track of the individual stacks and handles the "dragon" buttons and behaviour
var deck = []
var stack = []
var cards = []
var aces = [[],[],[]]
var temp_storage = [null,null,null]
var final_storage = [null,null,null]
var canremove = [false,false,false]

# rechecking
var recheck_requested
var game_over = false

# meta stuff
var accepts_input = false
onready var seed_input = get_node("LineEdit")
onready var seed_display = get_node("Label")

# animation stuff
var somethings_animating = false
var shuffling = false
var shuffling_stack = 0
var animation_speed = 0.3

# location parameters
var stacked_offset = 20
var stack_spacing = 30
var top_offset = 160
var card_width = 80
var card_height = 120
var screen_size = Vector2()
var card_size = Vector2()
var scale

# stats
var statfilepath = "user://stats.sav"
var stats = {
	wins = 0,
	games = 0
	}

# buttons
onready var buttonred = get_node("Button")
onready var buttongreen = get_node("Button2")
onready var buttonblue = get_node("Button3")
onready var win_label = get_node("Label2")
onready var stats_label = get_node("Statslabel")


func _ready():
	# try to load stats
	if not load_stats():
		print("stats not loaded")
		save_stats()
	elif stats.games == 0:
		save_stats()
	update_stats_label()
	get_tree().connect("screen_resized", self, "_on_screen_resized")
	var newseed = rand_seed(OS.get_unix_time())[1]
	seed(newseed)
	seed_display.text = "Current seed: " + str(newseed)
	update_sizes()
	update_button_visibility()
	# initialise stacks
	stack = [[],[],[],[],[],[],[],[]]
	generate_deck()
	shuffling = true
	update()
	set_process(true)
	set_process_input(true)

func update_stats_label():
	stats_label.text = "Games won: " + str(stats.wins)

func load_stats():
	var statfile = File.new()
	if not statfile.file_exists(statfilepath):
		print("no stats file found")
		return false
	# Open file
	if statfile.open(statfilepath, File.READ) != 0:
	    print("Error opening file")
	    return false
	var parseresult = JSON.parse(statfile.get_as_text())
	if parseresult.error != OK:
		print(parseresult.result)
		print("failed to parse JSON")
		return false
	stats = parseresult.result
	print("stats loaded")
	return true

func save_stats():
	# open directory
	var gamedir = Directory.new()
	gamedir.change_dir("user://")
	# Open a file
	var statfile = File.new()
	if statfile.open(statfilepath, File.WRITE) != 0:
	    print("Error opening file")
	    return
	
	statfile.store_line(JSON.print(stats))
	print("stats saved to " + gamedir.get_current_dir())
	statfile.close()

func reset_game(newseed = OS.get_unix_time()):
	accepts_input = false
	win_label.visible = false
	seed(newseed)
	seed_display.text = "Current seed: " + str(newseed)
	# clear board
	for card in cards:
		card.queue_free()
	for card in deck:
		card.queue_free()
	# reset lists
	deck = []
	stack = [[],[],[],[],[],[],[],[]]
	cards = []
	aces = [[],[],[]]
	shuffling_stack = 0
	temp_storage = [null,null,null]
	final_storage = [null,null,null]
	canremove = [false,false,false]
	generate_deck()
	stats.games += 1
	save_stats()
	shuffling = true

func _process(delta):
	if !somethings_animating:
		if recheck_requested:
			recheck()
		if shuffling:
			if deck.size():
				var card_index = randi() % deck.size()
				var shuffeled_card = deck[card_index]
				deck.remove(card_index)
				cards.append(shuffeled_card)
				shuffeled_card.z_index = deck.size()
				shuffeled_card.set_location(Vector2(shuffling_stack,stack[shuffling_stack].size()), true, get_final_slot_position(-1) ,animation_speed / 4)
				shuffling_stack += 1
				if shuffling_stack > stack.size() - 1:
					shuffling_stack = 0
			if deck.size() == 0:
				shuffling = false
				accepts_input = true
				game_over = false
				recheck()
		
		
	somethings_animating = false


func generate_deck():
	# generate all cards
	var card_class = preload("res://card.gd")
	for type in range(0,3): # for all suits
		for value in range(1,10):
			var new_card = card_class.new()
			new_card.set_type(type)
			new_card.set_value(value)
			new_card.game = self
			add_child(new_card)
			deck.append(new_card)
		for dragon in range(0,4):
			var new_card = card_class.new()
			new_card.set_type(type)
			new_card.set_value(0)
			new_card.game = self
			add_child(new_card)
			deck.append(new_card)
	# and add the "joker"
	var new_card = card_class.new()
	new_card.set_type(3)
	new_card.set_value(0)
	new_card.game = self
	add_child(new_card)
	deck.append(new_card)

func update_sizes():
	
	# set proportions
	screen_size = get_viewport().get_visible_rect().size
	
	scale = 1920.0 / screen_size.x
	print(screen_size)
	
	card_width = screen_size.x / 13
	card_height = screen_size.y / 5
	card_size = Vector2(card_width,card_height)
	stacked_offset = screen_size.y / 20
	stack_spacing = card_width / 2
	top_offset = card_height * 1.5
	
func update_button_visibility():
	buttonred.visible = canremove[0]
	buttongreen.visible = canremove[1]
	buttonblue.visible = canremove[2]

func append_to_stack(card, stackindex):
	stack[stackindex].append(card)

func remove_from_stack(card, stackindex):
	if stack[stackindex].has(card):
		stack[stackindex].erase(card)

func position_in_temp(position):
	for i in range(temp_storage.size()):
		if Rect2(Vector2((card_width + stack_spacing) * (i + 1), stacked_offset), Vector2(card_width,card_height)).has_point(position):
			return i

func move_to_temp(card,slot):
	if temp_storage[slot] == null:
		temp_storage[slot] = card


func position_in_final(position):
	for i in range(final_storage.size()):
		if Rect2(Vector2((card_width + stack_spacing) * (i + 5), stacked_offset), Vector2(card_width,card_height)).has_point(position):
			return i

func get_deck_position():
	return get_final_slot_position(-1)

func get_temp_slot_position(slot):
	return Vector2((card_width + stack_spacing) * (slot + 1), stacked_offset)

func get_final_slot_position(slot):
	return Vector2((card_width + stack_spacing) * (slot + 5), stacked_offset)

func point_is_in_stack_base(point,stackindex):
	return Rect2(Vector2((card_width + stack_spacing) * (stackindex) + card_width / 2, top_offset), Vector2(card_width,card_height)).has_point(point)

func _draw():
	# draw temp storage outlines
	for i in range(temp_storage.size()):
		draw_rect(Rect2(Vector2((card_width + stack_spacing) * (i + 1), stacked_offset), Vector2(card_width,card_height)),Color(1,1,1,1),false)
	# draw final storage outlines
	for i in range(final_storage.size()):
		var color = Color(0,0,0,1)
		color[i] = 1
		draw_rect(Rect2(Vector2((card_width + stack_spacing) * (i + 5), stacked_offset), Vector2(card_width,card_height)),color,false)

func lowest_final():
	var lowest = 10
	for i in range(final_storage.size()):
		if final_storage[i] != null:
			lowest = min(lowest, final_storage[i].value)
		else:
			lowest = 0
	return lowest

func recheck():
	# check if cards can be moved to final and if aces can be removed
	recheck_requested = false
	var aces_local = [[],[],[]]
	var lowest_value = lowest_final()
	for card in cards:
		if card.is_uppermost():
			if (card.value <= 2 or card.value == lowest_value + 1 ) and card.type <= 2:
				if card.move_to_final_storage(card.type):
					recheck_requested = true
					somethings_animating = true
					break
			if card.type == 3:
				if card.remove_joker():
					recheck_requested = true
					somethings_animating = true
					break
			# check if aces can be removed
			if card.value == 0 and card.type <= 2:
				aces_local[card.type].append(card)
	for type in range(aces_local.size()):
		if aces_local[type].size() == 4:
			# check if there is an available temp slot
			canremove[type] = false
			for i in range(temp_storage.size()):
				if temp_storage[i] == null:
					canremove[type] = true
				elif temp_storage[i].type == type and temp_storage[i].value == 0:
					canremove[type] = true
		else:
			canremove[type] = false
		# move aces to global scope
		aces = aces_local
	update_button_visibility()
	# win condition
	var remaining_cards = 0
	for individual_stack in stack:
		for card in individual_stack:
			remaining_cards += 1
	if remaining_cards == 0 and game_over == false:
		game_over = true
		print("You Win!")
		win_label.visible = true
		stats.wins += 1
		update_stats_label()
		save_stats()

func _on_screen_resized():
	update_sizes()

func _input(event):
	if event.is_action("restart"):
		get_tree().reload_current_scene()
	if event.is_action("ui_cancel"):
		get_tree().quit()

func remove_aces(type):
	var slot = - 1
	# find where to put them
	for i in range(temp_storage.size()):
		if temp_storage[i] != null:
			if temp_storage[i].type == type and temp_storage[i].value == 0:
				slot = i
				break
	# check again if empty temp slots available (because occupied slots are preferred (cosmetic)
	if slot == -1:
		for i in range(temp_storage.size()):
			if temp_storage[i] == null:
				slot = i
				break
	for card in aces[type]:
		card.remove_ace(slot)
	recheck_requested = true
	#recheck()

func _on_Button_button_up():
	# remove red aces
	remove_aces(0)


func _on_Button2_button_up():
	# remove green aces
	remove_aces(1)


func _on_Button3_button_up():
	# remove blue aces
	remove_aces(2)


func _on_Button4_button_up():
	var input = int(seed_input.text)
	if input == 0:
		input = rand_seed(OS.get_unix_time())[1]
	reset_game(input)


func _on_Speedslider_value_changed(value):
	animation_speed = value
