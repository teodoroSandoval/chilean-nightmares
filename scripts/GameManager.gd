extends Node3D
class_name GameManager

enum GameState    { MENU, PLAYING, PAUSED, VICTORY, GAMEOVER, DIALOG }
enum GameMode    { STORY_MODE, INFINITE_MODE, ARCADE_MODE, VERSUS_MODE }
# CoinMerge coin_merge  # Include the CoinMerge script to access its functionality
var state         : int   = GameState.MENU

@export var game_data: GameData

@export_category("Main Sections")
@export var dialog_base: Label
# @export var quiosc_base: Label
# @export var customization_base: Label
# @export var versus_base: Label

@export_category("Managers")
# @export var store_coin_manager: Control
# @export var store_client_manager: Control
@export var dialog_manager: Label
@export var player: PlayerManager

@export_category("Popups")
# @export var intro_popup: Control
# @export var pause_popup: Control
# @export var victory_popup: Control
# @export var gameover_popup: Control
# @export var settings_popup: Control
var is_showing_ui: bool = false
## Texturas de monedas/billetes. Deben estar en res://assets/coins/
const COIN_VALUES : Array[int] = [10, 50, 100, 500, 1000, 2000, 5000, 10000, 20000]
const COIN_TEXTURES : Array[String] = [
	"res://assets/coins/10pesos.png",
	"res://assets/coins/50pesos.png",
	"res://assets/coins/100pesos.png",
	"res://assets/coins/500pesos.png",
	"res://assets/coins/1000.png",
	"res://assets/coins/2000.png",
	"res://assets/coins/5000.png",
	"res://assets/coins/10000.png",
	"res://assets/coins/20000.png",
]
const COIN_COLORS : Array[Color] = [
	Color(0.95, 0.78, 0.08),   # 10    — amarillo (fallback sin textura)
	Color(0.95, 0.42, 0.08),   # 50    — naranja
	Color(0.88, 0.18, 0.18),   # 100   — rojo
	Color(0.20, 0.50, 0.95),   # 500   — azul
	Color(0.15, 0.80, 0.35),   # 1000  — verde
	Color(0.95, 0.60, 0.15),   # 2000  — marrón
	Color(0.05, 0.88, 0.88),   # 5000  — cian
	Color(0.95, 0.28, 0.72),   # 10000 — magenta
	Color(0.65, 0.10, 0.82),   # 20000 — morado
]
const CELL_SIZE       : int = 97

static var _game_mode : GameMode = GameMode.STORY_MODE
static var _coin_tex_cache : Array[Texture2D] = []
static func _load_textures() -> void:
	GameManager._coin_tex_cache.clear()
	for path in GameManager.COIN_TEXTURES:
		if ResourceLoader.exists(path):
			GameManager._coin_tex_cache.append(load(path) as Texture2D)
		else:
			GameManager._coin_tex_cache.append(null)
static func get_coin_texture_by_id(id: int) -> Texture2D:
	if GameManager._coin_tex_cache.size() == 0:
		_load_textures()
	if GameManager._coin_tex_cache.size() > id and id >= 0:
		return GameManager._coin_tex_cache[id]
	return null
static func get_coin_value_by_id(id: int) -> int:
	if id >= 0 and id < COIN_VALUES.size():
		return COIN_VALUES[id]
	return 0
static func get_coin_color_by_id(id: int) -> Color:
	if id >= 0 and id < COIN_COLORS.size():
		return COIN_COLORS[id]
	return Color(1, 1, 1)
var current_story_chapter: int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# pause_popup.hide()
	# victory_popup.hide()
	# gameover_popup.hide()
	# intro_popup.hide()
	# settings_popup.hide()

	dialog_base.hide()
	# quiosc_base.hide()
	# customization_base.hide()
	# versus_base.hide()

	# intro_popup._set_texts(store_coin_manager.level, store_coin_manager._get_current_level_objective(), store_coin_manager.high_score)
	# intro_popup.show()
	# store_coin_manager.on_gameover.connect(_show_gameover)
	# store_client_manager.on_all_clients_complete.connect(_show_victory)
	# _set_up_inputs()

	# InputManager.switch_to_Gameplay()
	# InputManager._hide_mouse()
	if player:
		player._resume_movement()
	# _start_game_mode()
	# get_tree().create_timer(0.05).timeout.connect(_start_game_mode)
	# pause_popup.resume.connect(_on_pause_menu_resume) # Hookup resume signal from Pause Menu


func _start_game_mode() -> void:
	match GameManager._game_mode:
		GameMode.STORY_MODE:
			# Start from dialog
			current_story_chapter = 0  # For now, always start at chapter 1
			# _start_chapter()
		GameMode.INFINITE_MODE:
			# skip dialogs
			# _start_quiosc_infinite()
			pass
		GameMode.ARCADE_MODE:
			# Initialize arcade mode specifics
			# _start_arcade()
			pass
		GameMode.VERSUS_MODE:
			# Initialize versus mode specifics
			pass
	# Todo: load saved level state and start the game accordingle, for now start always at level 1
# func _set_up_inputs() -> void:
# 	InputManager.gameplay_pause.triggered.connect(_pause_game)
func _start_chapter() -> void:
	if(current_story_chapter >= game_data.get_chapters_count()):
		_to_title_screen()
		return
	var current_chapter_data = game_data.get_chapter(current_story_chapter)
	dialog_manager.reset_dialog();

	if(current_chapter_data.initial_dialogs.size() > 0):
		_start_dialog(current_chapter_data.initial_dialogs, _start_quiosc)
	else:
		_start_quiosc()
func _end_chapter() -> void:

	var current_chapter_data = game_data.get_chapter(current_story_chapter)
	dialog_manager.reset_dialog();

	current_story_chapter += 1
	if(current_chapter_data.ending_dialogs.size() > 0):
		_start_dialog(current_chapter_data.ending_dialogs, _start_chapter)
	else:
		_start_chapter()

func _start_dialog(dialogs: Array[Dialog], after_dialog_callback: Callable) -> void:
	state = GameState.DIALOG
	dialog_base.show()
	dialog_manager.show_dialog(dialogs)
	dialog_manager.on_finished.connect(after_dialog_callback)
	# InputManager.switch_to_UI()

func _start_quiosc() -> void:
	pass

# func _action_throw() -> void:
#     # Implement the throw action here
#     pass
func _to_credits_screen() -> void:
	get_tree().change_scene_to_file("res://scenes/Credits.tscn")

func _to_title_screen() -> void:
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
func _show_settings() -> void:
	# settings_popup.show()
	pass
func _hide_settings() -> void:
	# settings_popup.hide()
	pass
func _save_and_quit() -> void:
	get_tree().quit()
static func get_translated_strings(context : Control, strings: Array[String]) -> Array[String]:
	var translated_strings: Array[String] = []
	for s in strings:
		translated_strings.append(context.tr(s))
	return translated_strings
