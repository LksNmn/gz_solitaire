extends Node2D

var type = 0
var value = 1
var size = Vector2(80,120)
var location = Vector2(-1,-1) # -1, -1 refers to the initial position on the deck
var selected = false
var colour = Color(1,1,1,1)
var game
var outline_thickness = 3
var substack = [self]
var moving = false
var in_temp_storage = 0 # int from 0 - 3, indicating which temp slot is occupied by this card
var in_final_storage = false

# cosmetics
var animating = false
var animation_timer = 0
var animation_time = 0
var old_position = Vector2(0,0)
var desired_position = Vector2(0,0)

const RED = Color(1,0.7,0.7,1)
const GREEN = Color(0.7,1,0.7,1)
const BLUE = Color(0.7,0.7,1,1)
const WHITE = Color(1,1,1,1)
const TYPECOLOURS = [RED,GREEN,BLUE,WHITE]

var label
var big_label


func _ready():
	# initialise labels
	var font = preload("res://fonts/new_dynamicfont.tres")
	var font2 = preload("res://fonts/new_dynamicfont2.tres")
	font2.set_size(30)
	font.set_size(80)
	label = Label.new()
	big_label = Label.new()
	label.text = str(value)
	big_label.text = str(value)
	big_label.rect_position = game.card_size/4
	z_index = 0
	if value == 0:
		label.text = "ACE"
		big_label.text = "A"
	if type == 3:
		label.text = "JOKER"
		big_label.text = "J"
	label.add_color_override("font_color", Color(0,0,0))
	label.add_font_override("font", font2)
	big_label.add_color_override("font_color", Color(0,0,0))
	big_label.add_font_override("font", font)
	add_child(label)
	add_child(big_label)
	position = game.get_deck_position()
	
	set_process_input(true)
	set_process(true)

func _process(delta):
	if animating:
		game.somethings_animating = true
		animation_timer += delta
		interpolate_position()

func _input(event):
	if game.accepts_input:
		# pressing LMB
		if Input.is_action_just_pressed("ui_select"):
			if is_hovering():
				get_substack()
				if can_move():
					moving = true
					
					# if card was in temp storage, free up slot while moving
					if in_temp_storage:
						game.temp_storage[in_temp_storage -1] = null
		# letting go of LMB
		if !Input.is_action_pressed("ui_select"):
			if moving:
				# check if stack has been moved to another stack
				for stack in game.stack:
					for card in stack:
						if card != self:
							if card.is_in_area(get_center_global()):
								if can_stack(card,self):
									set_location(card.location + Vector2(0,1))
									moving = false
									break
				# is there an empty stack it can be moved to?
				for i in range(game.stack.size()):
					if game.stack[i].size() == 0:
						if game.point_is_in_stack_base(get_center_global(),i):
							set_location(Vector2(i,0))
							break
				# can it be moved to storage?
				if substack.size() == 1:
					var temp_slot = game.position_in_temp(get_center_global())
					if temp_slot != null:
						move_to_temp_storage(temp_slot)
					var final_slot = game.position_in_final(get_center_global())
					if final_slot != null:
						move_to_final_storage(final_slot)
				# move back to old location
				if in_temp_storage:
					move_to_temp_storage(in_temp_storage - 1)
				else:
					set_location(location)
				moving = false
				game.recheck()
		# moving mouse
		if event is InputEventMouseMotion:
			if moving:
				translate_stack(event.relative)


func _draw():
	draw_rect(Rect2(Vector2(-outline_thickness,-outline_thickness),game.card_size + Vector2(2,2) * outline_thickness), Color(0,0,0,1))
	draw_rect(Rect2(Vector2(0,0),game.card_size),colour)

func set_location(new_loc, animated = false, from_position = position, duration = game.animation_speed, recheckneeded = false):
	moving = false
	if recheckneeded:
		#get_substack()
		pass
	for i in range(substack.size()):
		var card = substack[i]
		# check if card is in final
		if card.in_final_storage == false:
			# remove card from old stack
			game.remove_from_stack(card,card.location.x)
			card.location = new_loc + Vector2(0,1)*(i)
			# and add to new stack
			game.append_to_stack(card,card.location.x)
			var new_position = Vector2(card.location.x * (game.card_width + game.stack_spacing) + game.card_width / 2, card.location.y * game.stacked_offset + game.top_offset)
			if animated:
				start_animation(from_position, new_position, duration)
			else:
				card.position = new_position
			card.z_index = card.location.y
			in_temp_storage = 0

func move_to_temp_storage(slot):
	# check if slot is free
	if game.temp_storage[slot] == null:
		# remove card from old stack
		game.remove_from_stack(self,location.x)
		in_temp_storage = slot + 1
		game.temp_storage[slot] = self
		location = Vector2(-slot,0)
		position = game.get_temp_slot_position(slot)
		z_index = 1

func move_to_final_storage(slot, animated = true, duration = game.animation_speed):
	# check if slot is of correct type
	if slot == type:
		# check if condition is true
		var move = false
		if game.final_storage[slot] == null:
			if  value == 1:
				move = true
		elif value == game.final_storage[slot].value + 1: 
			move = true
		if move:
			# disable mouse dragging
			moving = false
			if in_temp_storage:
				game.temp_storage[in_temp_storage - 1] = null
				in_temp_storage = 0
			#remove from old stack
			game.remove_from_stack(self, location.x)
			in_final_storage = true
			game.final_storage[slot] = self
			location = Vector2(-2,0)
			if animated:
				start_animation(position, game.get_final_slot_position(slot), duration)
			else:
				position = game.get_final_slot_position(slot)
			z_index = value + 15
			return true
	else:
		return false
		

func remove_joker(animated = true, duration = game.animation_speed):
	if type == 3:
		# remove from stack
		game.remove_from_stack(self,location.x)
		# move to joker pos
		if animated:
			start_animation(position,game.get_final_slot_position(-1), duration )
		else:
			position = game.get_final_slot_position(-1)
		# lock card
		in_final_storage = true
		return true

func remove_ace(slot):
	if value == 0:
		# remove from old stack
		game.remove_from_stack(self,location.x)
		# or temp if in temp
		if in_temp_storage:
			game.temp_storage[in_temp_storage -1] = null
		# move card to temp slot and set final with a neat animation
		start_animation(position, game.get_temp_slot_position(slot), 0.3)
		game.temp_storage[slot] = self
		location = Vector2(-slot,0)
		in_final_storage = true

func translate_stack(translation):
	for i in range(substack.size()):
		if substack[i].in_final_storage == false:
			substack[i].z_index = i + 10
			substack[i].position += translation

func set_type(new_type):
	if typeof(new_type) == TYPE_INT and new_type <= 3 and new_type >= 0:
		type = new_type
		set_colour(TYPECOLOURS[new_type])

func set_value(new_value):
	if typeof(new_value) == TYPE_INT and new_value <= 9 and new_value >= 0:
		value = new_value

func is_hovering():
	var local_pos = get_global_mouse_position() - position
	var checksize = game.card_size
	if !is_uppermost():
		checksize = Vector2(game.card_size.x,game.stacked_offset)
	return (local_pos.x > 0 and local_pos.x <= checksize.x and local_pos.y > 0 and local_pos.y <= checksize.y)

func is_in_area(global_position):
	var local_pos = global_position - position
	var checksize = game.card_size
	if !is_uppermost():
		checksize = Vector2(game.card_size.x,game.stacked_offset)
	if(local_pos.x > 0 and local_pos.x <= checksize.x and local_pos.y > 0 and local_pos.y <= checksize.y):
		return self
	else:
		return false

func get_center_global():
	return Vector2(game.card_size/2 + position)

func set_colour(new_colour):
	if typeof(new_colour) == TYPE_COLOR:
		colour = new_colour
		update()

func is_uppermost():
	if game:
		if in_final_storage:
			return false
		if game.stack.size():
			if game.stack[location.x].size() - 1 == location.y:
				return true
		if in_temp_storage:
			return true

func interpolate_position():
	if animation_time > 0:
		position = old_position + (desired_position - old_position) * (animation_timer / animation_time)
	if animation_timer >= animation_time:
		animating = false
		animation_timer = 0
		position = desired_position

func start_animation(from_position, to_position, duration):
	animating = true
	old_position = from_position
	desired_position = to_position
	animation_time = duration

func can_move():
	if in_final_storage:
		return false
	if is_uppermost():
		return true
	else:
		if get_substack():
			return true
	return false

func can_stack(card1, card2):
	if card1.value == card2.value +1 and card1.type != card2.type and card2.value >= 1:
		return true

func get_substack():
	substack = [self]
	if !in_temp_storage:
		for i in range(location.y + 1, game.stack[location.x].size()):
			if can_stack(substack.back(), game.stack[location.x][i]):
				substack.append(game.stack[location.x][i])
			else:
				substack = []
				return false
	return true