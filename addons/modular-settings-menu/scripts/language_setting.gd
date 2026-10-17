extends OptionElement
func is_valid_locale(locale: String) -> bool:
	var locales: PackedStringArray = TranslationServer.get_loaded_locales()
	return locales.has(locale)
func _init() -> void:
	var currentLocale: String = TranslationServer.get_locale()
	if !is_valid_locale(currentLocale):
		TranslationServer.set_locale("es")
		currentLocale = "es"
		print("setted default locale to es")
	OPTION_LIST_ = get_option_dictionary()
	currentValue = OPTION_LIST_.find_key(currentLocale)
	DEFAULT_VALUE = currentValue

func get_option_dictionary() -> Dictionary:
	var dict: Dictionary = {}
	var locales: PackedStringArray = TranslationServer.get_loaded_locales()
	for locale in locales:
		# dict[locale] = tr("loc_name_" + locale) + "("+locale+")"
		var translatedLocale: String = "loc_name_" + locale
		dict[translatedLocale] = locale
	return dict


func load_settings() -> void:
	super.load_settings()
	print("Loading settings, currentValue: ", currentValue)
	# currentValue
	# currentValue = OPTION_LIST_.find_key(currentLocale)
	# print("on init currentValue: ", currentValue)
	# Check if the resolution element should be disabled
	# call_deferred("check_resolution")


func option_selected(index: int) -> void:
	super.option_selected(index)
	# currentValue = OPTION_LIST_.keys[index]
	# print("Selected option index: ", index)
	# print(currentValue)
	# print(OPTION_LIST_.keys()[index])
	# Check if the resolution element should be disabled
	# check_resolution()


func _apply_settings() -> void:
	print("Current value before applying settings: ", currentValue)
	var selectedLocale = OPTION_LIST_[currentValue]
	print("Applying locale: ", selectedLocale)
	if selectedLocale != null:
		TranslationServer.set_locale(selectedLocale)
	# refresh_options_translation()
	# currentValue = OPTION_LIST_.find_key(selectedLocale)
	# init_element()


# func refresh_options_translation() -> void:
# 	OPTION_LIST_.clear()
# 	OPTION_LIST_ = get_option_dictionary()

func adjust_resolution(sizeScale: float = 1.0) -> void:
	var displaySize: Vector2i =\
		DisplayServer.screen_get_size(
			DisplayServer.window_get_current_screen()
		) * sizeScale
	
	get_window().set_size(displaySize)
	get_viewport().set_size(displaySize)
	get_window().move_to_center()
