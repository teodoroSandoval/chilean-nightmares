extends Control
signal on_dialogs_complete
signal on_all_clients_complete
@export var dialog_base: Control
@export var client_dialog_text: RichTextLabel
@export var change_container: Control
@export var change_hint_text: RichTextLabel
@export var client_image: TextureRect
@export var client_default_texture: Texture2D
@export var coin_manager: Control
@export var time_per_letter: float = 0.05
@export var correct_image: TextureRect
@export var incorrect_image: TextureRect
@export var coins_pooling: Node
@export var game_data: GameData

var game_running: bool = false
var playing_text: bool = false
var infinite_mode: bool = false
var current_dialogs: Array[String] = []
var current_dialog_index: int = 0
var current_letter_index: int = 0

var client_list: Array[ClientRequest] = []
var index_list: Array[int] = []
var current_client_index: int = 0
var letter_time_accumulator: float = 0.0
var current_request_cost: int = 0
var change_money_objective: int = 0
var sales: int = 0
var score: int = 0
func _ready() -> void:
	dialog_base.modulate.a = 0.0
	client_dialog_text.text = ""
	client_image.modulate.a = 0.0
	correct_image.modulate.a = 0.0
	incorrect_image.modulate.a = 0.0
	change_hint_text.text = "0"
	time_per_letter = game_data.time_per_letter_request

func enable_inputs() -> void:
	InputManager.gameplay_give_change.triggered.connect(_give_change)
	InputManager.gameplay_return_change.triggered.connect(_return_container_coins)
	InputManager.ui_submit.triggered.connect(_progress_dialog)


func disable_inputs() -> void:
	# InputManager.disable_input_Gameplay()
	# InputManager.on_gameplay_Navigation_pressed.disconnect()
	InputManager.gameplay_give_change.triggered.disconnect(_give_change)
	InputManager.gameplay_return_change.triggered.disconnect(_return_container_coins)
	InputManager.ui_submit.triggered.disconnect(_progress_dialog)

func _process(delta: float) -> void:
	if playing_text:
		letter_time_accumulator += delta
		if letter_time_accumulator >= time_per_letter:
			letter_time_accumulator = 0.0
			current_letter_index += 1
			if current_letter_index <= current_dialogs[current_dialog_index].length():
				client_dialog_text.text = current_dialogs[current_dialog_index].substr(0, current_letter_index)
			else:
				playing_text = false

func _progress_dialog() -> void:
	print("Progressing dialog...")
	if playing_text:
		if current_letter_index < current_dialogs[current_dialog_index].length():
			current_letter_index = current_dialogs[current_dialog_index].length()
			client_dialog_text.text = current_dialogs[current_dialog_index]
			playing_text = false
	else:
		if current_dialog_index < current_dialogs.size() - 1:
			current_dialog_index += 1
			current_letter_index = 0
			client_dialog_text.text = ""
			playing_text = true
		else:
			print("Dialog sequence complete.")
			on_dialogs_complete.emit()

func start_dialog_sequence() -> void:
	print("Starting initial dialog sequence on client manager...")
	var current_character : CharacterData = client_list[index_list[current_client_index]].character_data
	if current_character and current_character.character_frame:
		client_image.texture = current_character.character_frame
	else:
		client_image.texture = client_default_texture
	client_image.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_callback(_on_client_image_tween_complete)
	tween.tween_property(client_image, "modulate:a", 1.0, 0.5)

	InputManager.switch_to_UI()

func _on_client_image_tween_complete() -> void:
	client_dialog_text.text = ""
	client_dialog_text.show()
	_tween_initial_dialog_in()

func _tween_initial_dialog_in() -> void:
	dialog_base.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_callback(_on_initial_dialog_tween_complete)
	tween.tween_property(dialog_base, "modulate:a", 1.0, 0.5)

func _on_initial_dialog_tween_complete() -> void:
	if client_list[index_list[current_client_index]].initial_dialogs.size() > 0:
		on_dialogs_complete.connect(_start_request)
		_play_dialogs(client_list[index_list[current_client_index]].initial_dialogs)
	else:
		_start_request()

func _play_dialogs(dialogs: Array[String]) -> void:
	playing_text = true
	current_dialogs = GameManager.get_translated_strings(self as Control, dialogs)
	current_dialog_index = 0
	current_letter_index = 0

func _start_request() -> void:
	print("starting request")
	if on_dialogs_complete.is_connected(_start_request):
		on_dialogs_complete.disconnect(_start_request)
	var requestText = generate_current_request_text()
	current_request_cost = get_current_request_cost()
	change_money_objective = client_list[index_list[current_client_index]].money - current_request_cost
	on_dialogs_complete.connect(_start_coins_minigame)
	_play_dialogs([requestText])
func _start_coins_minigame() -> void:
	print("_start_coins_minigame")
	if on_dialogs_complete.is_connected(_start_coins_minigame):
		on_dialogs_complete.disconnect(_start_coins_minigame)
	change_hint_text.text = str(change_money_objective)
	score = coin_manager.score
	coin_manager._start_game()
	coin_manager.score = score
	coin_manager.enable_inputs()
	InputManager.switch_to_Gameplay()

func set_client_list(clients: Array[ClientRequest]) -> void:
	client_list = clients
	current_client_index = 0
	
	_init_index_list()
	if infinite_mode:
		_shuffle_index_list()
func _init_index_list() -> void:
	index_list.clear()
	for i in range(client_list.size()):
		index_list.append(i)
func _shuffle_index_list() -> void:
	index_list.shuffle()
func _start_game() -> void:
	print("Starting client manager game...")
	game_running = true
	start_dialog_sequence()
func re_start_game() -> void:
	print("Restarting client manager game...")
	current_client_index = 0
	coin_manager._reset()
	_start_game()


func get_current_request_cost() -> int:
	var total_cost = 0
	for item_stack in client_list[index_list[current_client_index]].requested_items:
		total_cost += item_stack.item.item_value * item_stack.quantity
	return total_cost
func generate_current_request_text() -> String:
	var finalText : String = ""
	var requested_items: Array[ItemStack] = client_list[index_list[current_client_index]].requested_items

	# TODO: fix translation error
	var segmentA: String = tr("i want")
	var segmentB: String = tr("i pay with")
	finalText = segmentA + " "
	for item_stack in requested_items:
		finalText += get_quantity_to_text(item_stack.quantity) + \
		" " + get_pluralyzed_item_name(item_stack.item.item_name, item_stack.quantity) + \
		" ($" + str(item_stack.item.item_value * item_stack.quantity) + ")" + \
		# ", " + tr("i_pay_with") + " $" + str(client_list[current_client_index].money)
		", " + segmentB + " $" + str(client_list[index_list[current_client_index]].money)
	return finalText.strip_edges()
const QUANTITY_NAMES: Array[String] = [
	"cero",
	"un",
	"dos",
	"tres",
	"cuatro",
	"cinco",
	"seis",
	"siete",
	"ocho",
	"nueve",
	"diez"
]
func get_quantity_to_text(quantity: int) -> String:
	if quantity >= 1 and quantity < QUANTITY_NAMES.size():
		return tr(QUANTITY_NAMES[quantity])
	return str(quantity)

func get_pluralyzed_item_name(item_name: String, quantity: int) -> String:
	if quantity == 1:
		return tr(item_name)
	return tr(item_name) + "s"

func _check_change_money_submit(instance: Node) -> void:
	var money_in_continer: int = 0
	for coin_instance in on_change_container_coins:
		money_in_continer += coin_instance.coinValue
	if money_in_continer == change_money_objective:
		_play_correct_submission_sequence()
		_clear_container_coins()
	else:
		# Incorrect amount submitted
		if money_in_continer > change_money_objective:
			if incorrect_image.modulate.a != 0.0:
				return # prevent button spamming saturation
			# Submitted too much money
			_play_incorrect_submission_sequence()

			get_tree().create_timer(0.05).timeout.connect(_return_container_coins)
			# _return_container_coins()
		else:
			pass
			# Submitted too little money
			# _play_incorrect_submission_sequence()


func _give_change() -> void:

	var coin_id = coin_manager.get_coin_in_hand_ID()
	var coin_count = coin_manager.get_coins_in_hand_count()
	
	for i in range(coin_count):
		_spawn_coin_tween_to_change_container(coin_id)
	

var on_change_container_coins: Array[Control] = []
func _spawn_coin_tween_to_change_container(coin_id: int) -> void:
	var coin_instance: Control = coins_pooling.get_instance() as Control
	coin_instance._set_coin(coin_id)
	coin_manager.reset_money_in_hand()
	coin_instance._align_center_to_position(coin_manager.character_chibi._get_coin_global_position())
	var offset: float = 100.0
	var randomOffset: Vector2 = Vector2((0.5 - randf()) * offset, (0.5 - randf()) * offset)
	var root_relative_position_end: Vector2 = change_container.global_position + (change_container.size / 2) + randomOffset
	coin_instance.speed = game_data.coin_speed_change
	coin_instance._move_to_target(root_relative_position_end)
	on_change_container_coins.append(coin_instance)
	coin_instance.on_reached.connect(_check_change_money_submit)
func _play_correct_submission_sequence() -> void:
	# Implement the sequence for correct submission here
	change_hint_text.text = "0"
	sales += current_request_cost
	_tween_in_and_out(correct_image, _start_ending_dialog)
	coin_manager.reset_money_in_hand()
	coin_manager._end_game()
	coin_manager.disable_inputs()
	# coin_manager.set_manual_victory()

func _play_incorrect_submission_sequence() -> void:
	# Implement the sequence for incorrect submission here
	_tween_in_and_out(incorrect_image, Callable())

func _tween_in_and_out(target_node: Node, callback: Callable) -> void:
	target_node.modulate.a = 0.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	if not callback.is_null():
		tween.tween_callback(callback)
	tween.tween_property(target_node, "modulate:a", 1.0, 0.5)
	tween.tween_property(target_node, "modulate:a", 0.0, 0.5)

func _start_ending_dialog() -> void:
	print("playing ending dialogs")
	InputManager.disable_All()
	if client_list[index_list[current_client_index]].ending_dialogs.size() > 0:
		InputManager.switch_to_UI()
		on_dialogs_complete.connect(_tween_out_all)
		_play_dialogs(client_list[index_list[current_client_index]].ending_dialogs)
	else:
		_tween_out_all()
func _tween_out_all() -> void:
	if on_dialogs_complete.is_connected(_tween_out_all):
		on_dialogs_complete.disconnect(_tween_out_all)
	print("tweening all out")
	client_dialog_text.text = ""
	# dialog_base.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(dialog_base, "modulate:a", 0.0, 0.5)
	tween.tween_callback(_start_next_request)
	client_image.modulate.a = 1.0
	var tween2 = create_tween()
	tween2.tween_property(client_image, "modulate:a", 0.0, 0.5)

func _start_next_request() -> void:
	print("attemp to start next quest")
	current_client_index += 1
	if current_client_index < index_list.size():
		print("starting next request")
		current_request_cost = 0
		change_money_objective = 0
		start_dialog_sequence()
	else:
		if infinite_mode:
			current_client_index = 0
			_shuffle_index_list()
			_start_next_request()
		else:
			print("all clients completed")
			score = coin_manager.score
			coin_manager.disable_inputs()
			coin_manager.set_manual_victory()
			game_running = false
			on_all_clients_complete.emit()
func _return_container_coins() -> void:
	coin_manager.return_container_coins(on_change_container_coins.duplicate())
	on_change_container_coins.clear()

func _clear_container_coins() -> void:
	for coin_instance in on_change_container_coins:
		coins_pooling.return_instance(coin_instance)
	on_change_container_coins.clear()

func set_infinite_mode(value: bool) -> void:
	infinite_mode = value
# func set_arcade_mode(value: bool) -> void:
# 	arcade_mode = value