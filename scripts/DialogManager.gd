extends Label
signal on_finished

@export var name_text: RichTextLabel
@export var dialog_text: RichTextLabel
@export var dialog_box: Control
@export var character_image_0: TextureRect # left
@export var character_image_1: TextureRect # right
@export var character_image_2: TextureRect # center
@export var time_per_letter: float = 0.05
@export var game_data: GameData

var cacheDialogsArray: Array[Dialog] = []
var cacheCurrentDialog: Dialog = null
var cacheTranslatedStrings: Array[String]
var playingText: bool = false
var currentDialogIndex: int = 0
var currentDialogSegmentIndex: int = 0
var currentLetterIndex: int = 0

func _on_visibility_changed() -> void:
	if visible:
		enable_inputs()
	else:
		disable_inputs()
func enable_inputs() -> void:
	if not InputManager.ui_submit.triggered.is_connected(progress_input):
		InputManager.ui_submit.triggered.connect(progress_input)

func disable_inputs() -> void:
	if InputManager.ui_submit.triggered.is_connected(progress_input):
		InputManager.ui_submit.triggered.disconnect(progress_input)
func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	time_per_letter = game_data.time_per_letter_dialog
	_on_visibility_changed()

var time_accumulator: float = 0.0
func _process(delta: float) -> void:
	if playingText and currentLetterIndex < cacheTranslatedStrings[currentDialogSegmentIndex].length():
		time_accumulator += delta
		if time_accumulator >= time_per_letter:
			time_accumulator = 0.0
			currentLetterIndex += 1
			dialog_text.text = cacheTranslatedStrings[currentDialogSegmentIndex].substr(0, currentLetterIndex)
			if currentLetterIndex >= cacheTranslatedStrings[currentDialogSegmentIndex].length():
				_end_segment()

func reset_dialog() -> void:
	name_text.clear()
	dialog_text.clear()
	dialog_box.hide()
	character_image_0.hide()
	character_image_1.hide()
	character_image_2.hide()

func show_dialog(dialogs: Array[Dialog]) -> void:
	cacheDialogsArray = dialogs
	currentDialogIndex = 0
	_show_next_dialog()
	
func _show_next_dialog_segment() -> void:
	if currentDialogSegmentIndex < cacheCurrentDialog.dialogs_texts.size() - 1:
		currentLetterIndex = 0
		dialog_text.text = ""
		currentDialogSegmentIndex += 1
		playingText = true
	else:
		_show_next_dialog()
func _show_next_dialog() -> void:
	if currentDialogIndex < cacheDialogsArray.size():
		cacheCurrentDialog = cacheDialogsArray[currentDialogIndex]
		cacheTranslatedStrings = GameManager.get_translated_strings(self as Control, cacheCurrentDialog.dialogs_texts)
		set_image(cacheCurrentDialog.screen_side, cacheCurrentDialog.character_data)
		dialog_box.show()
		var name_translated = tr(cacheCurrentDialog.character_data.character_name)
		name_text.text = "" # weird bug, without this, the text doesnt updates just after made visible
		name_text.text = name_translated
		dialog_text.text = ""
		# cacheCurrentDialog.character_data.font
		# cacheCurrentDialog.character_data.font_color
		if cacheCurrentDialog.character_data.font:
			dialog_text.add_theme_font_override("normal_font", cacheCurrentDialog.character_data.font)
		if cacheCurrentDialog.character_data.font_color:
			dialog_text.add_theme_color_override("default_color", cacheCurrentDialog.character_data.font_color)
		currentLetterIndex = 0
		currentDialogSegmentIndex = 0
		currentDialogIndex += 1
		playingText = true
	else:
		playingText = false
		on_finished.emit()

func set_image(screen_side: int, character_data: CharacterData) -> void:
	character_image_0.hide()
	character_image_1.hide()
	character_image_2.hide()
	match screen_side:
		0:
			character_image_0.texture = character_data.character_frame
			character_image_0.show()
		1:
			character_image_1.texture = character_data.character_frame
			character_image_1.show()
		2:
			character_image_2.texture = character_data.character_frame
			character_image_2.show()

func progress_input() -> void:
	if playingText:
		_end_segment()
	else:
		_show_next_dialog_segment()
func _end_segment() -> void:
	currentLetterIndex = cacheTranslatedStrings[currentDialogSegmentIndex].length()
	dialog_text.text = cacheTranslatedStrings[currentDialogSegmentIndex]
	playingText = false
