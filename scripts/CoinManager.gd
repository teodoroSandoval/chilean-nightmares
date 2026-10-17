extends Control
## CoinMerge — Juego completo en un solo archivo GDScript.
##
## MECÁNICAS:
## 1. Hileras nuevas aparecen en la PARTE SUPERIOR y bajan empujando todo.
## 2. El jugador está ABAJO y lanza monedas HACIA ARRIBA (a la columna elegida).
## 3. El jugador puede acumular VARIAS monedas del mismo valor en la mano.
## 4. La fusión SOLO ocurre cuando el jugador coloca una moneda — nunca automática.
##
## CONTROLES: ← → moverse | Z agarrar | X soltar/lanzar | ESC pausa

# ─────────────────────────────────────────────────────────────
#  CONSTANTES DE DISEÑO
# ─────────────────────────────────────────────────────────────
const COLS       : int = 7
const ROWS       : int = 9
const START_ROWS : int = 3      # filas pre-pobladas al iniciar

# Posición del tablero en pantalla
const BOARD_X : int = 45
const BOARD_Y : int = 80

# Posición Y del área del jugador (debajo del tablero)
const PLAYER_Y : int = BOARD_Y + ROWS * GameManager.CELL_SIZE + 30

# ─────────────────────────────────────────────────────────────
#  ESTADOS Y TIPOS
# ─────────────────────────────────────────────────────────────
enum State    { MENU, PLAYING, PAUSED, VICTORY, GAMEOVER }
enum CoinType { NORMAL }   # extendible: RANKUP, ERASE, etc.

class CoinData:
	var col     : int
	var row     : int
	var val_idx : int
	var type    : int
	var fall_anim    : int

	func _init(c: int, r: int, v: int, t: int = 0) -> void:
		col     = c
		row     = r
		val_idx = v
		type    = t
		fall_anim = 0

# ─────────────────────────────────────────────────────────────
#  ESTADO GLOBAL
# ─────────────────────────────────────────────────────────────
signal on_gameover
signal on_victory
@export var arcade_sidebar: CenterContainer
@export var score_text: RichTextLabel
@export var target_score_text: RichTextLabel
@export var level_text: RichTextLabel
@export var coin_counter_text: RichTextLabel
@export var combo_text_text: RichTextLabel
@export var progress_bar: ProgressBar
@export var grid_container: GridContainer
@export var grid_marker: Control
@export var character_chibi: Control
@export var row_highlight: ColorRect
@export var animation_coin: Control
@export var game_data: GameData
@export var coins_pooling: Node

var state         : int   = State.MENU
var coins         : Array = [CoinData]          # Array[CoinData] — tablero
var cells         : Array = [Control]          # Array[Control] — ui

## La MANO del jugador: puede contener N monedas, todas del mismo valor.
var hand          : Array = []          # Array[CoinData]
var hand_val_idx  : int   = -1          # -1 = mano vacía

var cursor_col    : int   = COLS / 2
var score         : int   = 0
var high_score    : int   = 0
var level         : int   = 1
var target_score  : int   = 3000
var rise_timer    : float = 0.0
var rise_interval : float = 6.0
var max_val_idx   : int   = 2
var is_resolving   : bool  = false
## Monedas que deben estar presentes en un grupo para que sea válido.
## Solo los grupos que contienen al menos una de estas fichas se resuelven.
var _trigger_coins : Array = []   # Array[CoinData]

var combo_text    : String = ""
var combo_timer   : float  = 0.0
var move_cooldown : float  = 0.0

# Animación de "moneda volando hacia arriba"
var throw_anim_active : bool  = false
var grab_anim_active : bool  = false
var arcade_mode : bool  = false

var _font         : Font# Array[Texture2D] cargadas en _ready
var _grid_initial_position : Vector2
var _grid_shifted_position : Vector2
var shake_distance: float = 4.0
# ─────────────────────────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_grid_initial_position = grid_container.position
	_grid_shifted_position = Vector2(grid_container.position.x, grid_container.position.y - GameManager.CELL_SIZE)
	rise_interval = game_data.grid_rise_interval
	_font = ThemeDB.fallback_font
	combo_text_text.pivot_offset = combo_text_text.size / 2
	_load_highscore()
	GameManager._load_textures()
	_load_cells()
	_clear_grid()
	character_chibi._set_coins_in_hand(0, -1)
	animation_coin.hide()
	hide_arcade_ui()
	grid_marker.hide()
	# _ser_chibi_cursor_position(3) # align to middle collumn
	grid_container.modulate.a = 0
	_reset_game()


func enable_inputs() -> void:
	InputManager.gameplay_move.triggered.connect(_on_movement_input)
	InputManager.gameplay_grab.triggered.connect(_action_grab)
	InputManager.gameplay_throw.triggered.connect(_action_throw)


func disable_inputs() -> void:
	InputManager.gameplay_move.triggered.disconnect(_on_movement_input)
	InputManager.gameplay_grab.triggered.disconnect(_action_grab)
	InputManager.gameplay_throw.triggered.disconnect(_action_throw)
func show_arcade_ui() -> void:
	arcade_sidebar.show()
	progress_bar.show()

func hide_arcade_ui() -> void:
	arcade_sidebar.hide()
	progress_bar.hide()

func _load_cells() -> void:
	cells.clear()
	for i in range(COLS * (ROWS + 1)):
		var cell = grid_container.get_child(i)
		if(cell == null):
			break
		cells.append(cell)
		cell.set_cell_position(i % COLS, i / COLS)
		cell.on_cell_clicked.connect(_on_cell_clicked)

func _on_cell_clicked(col: int, row: int, sender: Control, button_index: int) -> void:
	print("_on_cell_clicked: col=%d, row=%d" % [col, row])
	if state != State.PLAYING:
		return
	cursor_col = col

	if button_index == MOUSE_BUTTON_LEFT: # if the clicked cell is in the player's row
		_action_grab()
	elif button_index == MOUSE_BUTTON_RIGHT:
		_action_throw()

func _update_game(delta: float) -> void:
	_refresh_hud()
	_refresh_coins()
	_refresh_player_area()

func _process(delta: float) -> void:
	_refresh_combo_text(delta)
	if state != State.PLAYING:
		return
	_update_movement(delta)
	_update_falling_row(delta)
	_update_game(delta)

func _update_movement(delta: float) -> void:
	# Movimiento continuo con teclado
	if move_cooldown > 0.0:
		move_cooldown -= delta

func _on_movement_input() -> void:
	var input_vector: Vector2 = InputManager.gameplay_move.value_axis_2d
	# Movimiento continuo con teclado
	if move_cooldown <= 0.0:
		if input_vector.x < 0:
			cursor_col = maxi(0, cursor_col - 1)
			move_cooldown = 0.10
		elif input_vector.x > 0:
			cursor_col = mini(COLS - 1, cursor_col + 1)
			move_cooldown = 0.10
var playing_shake: bool = false
var shake_time_percent: float = 0.75
func _update_falling_row(delta: float) -> void:
	# Hileras nuevas caen desde arriba
	if not is_resolving:
		rise_timer += delta
		if rise_timer >= rise_interval:
			rise_timer = 0.0
			_stop_shake()
			_drop_new_row()   # nueva hilera desde ARRIBA, sin fusión automática
		else:
			if not playing_shake:
				var time_percent: float = rise_timer / rise_interval
				if time_percent >= shake_time_percent:
					_start_shake()
var shake_tween: Tween
func _start_shake() -> void:
	grid_container.position = _grid_initial_position
	playing_shake = true
	shake_tween = create_tween()
	shake_tween.set_trans(Tween.TRANS_SINE)
	shake_tween.set_ease(Tween.EASE_IN_OUT)
	shake_tween.set_loops()
	shake_tween.tween_property(grid_container, "position:y", _grid_initial_position.y + shake_distance, 0.06)
	shake_tween.tween_property(grid_container, "position:y", _grid_initial_position.y, 0.06)
	shake_tween.play()

func _stop_shake() -> void:
	playing_shake = false
	if shake_tween:
		shake_tween.stop()
		shake_tween = null
# ─────────────────────────────────────────────────────────────
#  LÓGICA PRINCIPAL
# ─────────────────────────────────────────────────────────────
func _pause_game() -> void:
	if(state == State.PLAYING):
		state = State.PAUSED
func _resume_game() -> void:
	if(state == State.PAUSED):
		state = State.PLAYING
func _end_game() -> void:
	_stop_shake()
	_tween_grid_container_alpha(0.0, 0.5)
	state = State.MENU
func is_victory() -> bool:
	return state == State.VICTORY
func set_manual_victory() -> void:
	state = State.VICTORY
func reset_money_in_hand() -> void:
	hand.clear()
	hand_val_idx  = -1
	character_chibi._set_coins_in_hand(0, -1)

func _reset()  -> void:
	coins.clear()
	hand.clear()
	_clear_grid()
	hand_val_idx  = -1
	cursor_col    = COLS / 2
	score         = 0
	rise_timer    = 0.0
	is_resolving  = false
	_trigger_coins.clear()
	combo_text    = ""
	combo_timer   = 0.0
	throw_anim_active = false
	grab_anim_active = false
	state = State.MENU

func _start_game() -> void:
	_reset_game()
	state = State.PLAYING
	_fill_start_rows()
	# NO llamamos _resolve() aquí: sin fusión automática al inicio
	_tween_grid_container_alpha(1.0, 0.5)
func _reset_game() -> void:
	coins.clear()
	hand.clear()
	hand_val_idx  = -1
	cursor_col    = COLS / 2
	score         = 0
	rise_timer    = 0.0
	is_resolving  = false
	_trigger_coins.clear()
	combo_text    = ""
	combo_timer   = 0.0
	throw_anim_active = false
	grab_anim_active = false

	var t      : float = float(level - 1) / 9.0
	var t_fast : float = minf(t * 2.0, 1.0)  # alcanza dificultad máx en nivel 5
	rise_interval = lerp(6.0, 1.4, t_fast)   # de 6s entre filas hasta 1.4s
	# Los valores altos aparecen progresivamente desde el nivel 1:
	# nivel 1→idx 2 (hasta 10), nivel 3→idx 5 (hasta 500), nivel 5+→idx 9 (todos)
	max_val_idx   = clampi(3 + int(t_fast * 4.0), 3, 7)
	
	hide_arcade_ui()
	arcade_sidebar.show()
	if arcade_mode:
		# show_arcade_ui()
		target_score  = int(25000.0 * pow(2.0, float(level - 1)))
	else:
		# hide_arcade_ui()
		target_score = 0
func is_running() -> bool:
	return state == State.PLAYING

## Llena las primeras filas al inicio desde la CIMA — sin fusión automática.
func _fill_start_rows() -> void:
	# Llenado variado con distribucion uniforme real.
	# Se evita solo que el mismo valor aparezca 3+ veces seguidas
	# en la misma fila o columna (para que haya mezcla visible pero
	# sin bloquear valores por sus reglas de fusion).
	for r in range(START_ROWS):
		for c in range(COLS):
			coins.append(_varied_coin(c, r))


func _varied_coin(c: int, r: int) -> CoinData:
	# Pool de indices mezclado uniformemente
	var pool : Array[int] = []
	for i in range(max_val_idx + 1):
		pool.append(i)
	pool.shuffle()

	# Rechazar solo si el mismo valor ya aparece 2 veces consecutivas
	# en la fila (izquierda) o en la columna (arriba)
	for idx in pool:
		var left_1  : CoinData = _coin_at(c - 1, r)
		var left_2  : CoinData = _coin_at(c - 2, r)
		var above_1 : CoinData = _coin_at(c, r - 1)
		var above_2 : CoinData = _coin_at(c, r - 2)

		var streak_h : bool = (left_1  != null and left_1.val_idx  == idx
						and left_2  != null and left_2.val_idx  == idx)
		var streak_v : bool = (above_1 != null and above_1.val_idx == idx
						and above_2 != null and above_2.val_idx == idx)

		if not streak_h and not streak_v:
			return CoinData.new(c, r, idx, CoinType.NORMAL)

	# Fallback: primer valor del pool mezclado
	return CoinData.new(c, r, pool[0], CoinType.NORMAL)

## Nueva hilera aparece en la fila 0 (arriba) y empuja todo HACIA ABAJO.
## NO dispara fusiones.
func _drop_new_row() -> void:
	# Derrota: alguna moneda esta en fila ROWS-1, el siguiente empuje la saca del tablero
	for coin in coins:
		if (coin as CoinData).row >= ROWS - 1:
			_game_over()
			return

	# Empujar todas las monedas UNA FILA HACIA ABAJO
	for coin in coins:
		(coin as CoinData).row += 1

	# Insertar nueva fila en la CIMA (row 0) -- SIN fusion automatica
	for col in range(COLS):
		coins.append(_varied_coin(col, 0))

	# shift and tween the whole grid down to reflect the new row
	grid_container.position = _grid_shifted_position
	var _grid_tween = create_tween()
	_grid_tween.set_trans(Tween.TRANS_LINEAR)
	_grid_tween.set_ease(Tween.EASE_IN_OUT)
	_grid_tween.tween_property(grid_container, "position:y", _grid_initial_position.y, 1.0)


## Agarrar: toma la moneda más baja de la columna actual.
## Si la mano ya tiene monedas, solo permite agarrar el mismo valor.
func _action_grab() -> void:
	var coin : CoinData = _bottom_coin_in(cursor_col)
	if coin == null:
		return
	if grab_anim_active or throw_anim_active:
		return

	if hand_val_idx == -1:
		# Mano vacía → agarrar cualquier moneda
		coins.erase(coin)
		hand.append(coin)
		hand_val_idx = coin.val_idx
		grab_anim_active = true

	elif coin.val_idx == hand_val_idx:
		# Mismo valor → añadir a la mano
		coins.erase(coin)
		hand.append(coin)
		grab_anim_active = true

	if(grab_anim_active):
		var cell : Control = _get_cell(coin.row, coin.col)
		animation_coin.show()
		animation_coin._set_coin(hand_val_idx)
		animation_coin._align_center_to_position(cell.global_position + (cell.size * 0.5))
		# animation_coin._align_center_to_position(grid_marker.global_position)
		animation_coin.speed = game_data.coin_speed_grab
		animation_coin._move_to_target(Vector2(cell.global_position.x + (cell.size.x * 0.5), character_chibi._get_coin_global_position().y))
		animation_coin.on_reached.connect(_on_grab_animation_coin_reached)

	# Si el valor es diferente, no se puede agarrar (mano ocupada con otro valor)
func _on_grab_animation_coin_reached(coin_instance: Node) -> void:
	grab_anim_active = false
	animation_coin.hide()
	animation_coin.on_reached.disconnect(_on_grab_animation_coin_reached)

func _on_throw_animation_coin_reached(coin_instance: Node) -> void:
	throw_anim_active = false
	animation_coin.hide()
	animation_coin.on_reached.disconnect(_on_throw_animation_coin_reached)

## Lanzar: suelta toda la mano en la columna actual.
## SOLO AQUÍ ocurre la fusión.
func _action_throw() -> void:
	if hand.is_empty():
		return
	if (throw_anim_active or grab_anim_active):
		return

	# Verificar que hay espacio suficiente en la columna
	var free_rows : int = _free_rows_in(cursor_col)
	if free_rows <= 0:
		return   # columna llena, no se puede lanzar

	var first_row  : int      = _landing_row(cursor_col)
	var cell		: Control  = _get_cell(first_row, cursor_col)
	animation_coin.show()
	animation_coin._set_coin(hand_val_idx)
	animation_coin._align_center_to_position(Vector2(cell.global_position.x + (cell.size.x * 0.5), character_chibi._get_coin_global_position().y))
	animation_coin.speed = game_data.coin_speed_throw
	animation_coin._move_to_target(cell.global_position + (cell.size * 0.5) + Vector2(0, GameManager.CELL_SIZE))
	# animation_coin._move_to_target(grid_marker.global_position)
	animation_coin.on_reached.connect(_on_throw_animation_coin_reached)
	throw_anim_active = true

	# Colocar las monedas de la mano y registrarlas como disparadores del combo
	_trigger_coins.clear()
	for i in range(hand.size()):
		var coin : CoinData = hand[i] as CoinData
		var row  : int      = _landing_row(cursor_col)
		if row < 0:
			break   # columna llena
		coin.col = cursor_col
		coin.row = row
		coins.append(coin)
		_trigger_coins.append(coin)   # solo estas monedas pueden iniciar combos

	hand.clear()
	hand_val_idx = -1

	# Iniciar resolución: solo busca grupos que incluyan las monedas lanzadas
	_resolve()


## Contar monedas libres en una columna.
func _free_rows_in(col: int) -> int:
	var used : int = 0
	for coin in coins:
		if (coin as CoinData).col == col:
			used += 1
	return ROWS - used


## Devuelve la fila más baja LIBRE en una columna.
func _landing_row(col: int) -> int:
	## La moneda aterriza JUSTO DEBAJO del stack actual de la columna.
	## Si la columna esta vacia cae al fondo (fila ROWS-1, junto al jugador).
	var max_occupied : int = -1
	for coin in coins:
		var cd := coin as CoinData
		if cd.col == col and cd.row > max_occupied:
			max_occupied = cd.row
	if max_occupied == -1:
		return 0                  # columna vacia: la moneda va a la CIMA (row 0)
	elif max_occupied >= ROWS - 1:
		return -1                 # columna llena
	else:
		return max_occupied + 1   # justo debajo del stack existente


func _bottom_coin_in(col: int) -> CoinData:
	var best : CoinData = null
	for coin in coins:
		var cd := coin as CoinData
		if cd.col == col and (best == null or cd.row > best.row):
			best = cd
	return best


func _coin_at(col: int, row: int) -> CoinData:
	for coin in coins:
		var cd := coin as CoinData
		if cd.col == col and cd.row == row:
			return cd
	return null


func _random_coin(c: int, r: int) -> CoinData:
	var roll  : float = randf() * randf()
	var idx   : int   = clampi(int(roll * float(max_val_idx + 1)), 0, max_val_idx)
	return CoinData.new(c, r, idx, CoinType.NORMAL)


func _game_over() -> void:
	hand.clear()
	hand_val_idx = -1
	if score > high_score:
		high_score = score
		_save_highscore()
	state = State.GAMEOVER
	on_gameover.emit()

# ─────────────────────────────────────────────────────────────
#  RESOLUCIÓN DE FUSIONES (solo tras lanzamiento del jugador)
# ─────────────────────────────────────────────────────────────
func _resolve() -> void:
	if is_resolving:
		return
	is_resolving = true
	_resolve_step(0)


func _resolve_step(chain: int) -> void:
	# Solo buscar grupos que contengan al menos una moneda disparadora.
	# Esto asegura que los combos estén conectados a la moneda que lanzó el jugador.
	var groups : Array = _find_groups_from_triggers(_trigger_coins)

	if groups.is_empty():
		_apply_gravity()
		is_resolving = false

		if arcade_mode:
			if score >= target_score:
				if score > high_score:
					high_score = score
					_save_highscore()
				state = State.VICTORY
				on_victory.emit()
		return

	# Resolver UN solo grupo por paso (el más grande)
	var best_group : Array = groups[0]
	for g in groups:
		if (g as Array).size() > best_group.size():
			best_group = g

	# _merge_group actualiza _trigger_coins con la moneda resultante
	var pts : int = _merge_group(best_group, chain)
	score += pts

	if chain == 0:
		combo_text  = "+%d" % pts
	else:
		combo_text  = "COMBO x%d   +%d" % [chain + 1, pts]
	_twee_combo_text_scale()
	combo_timer = 2.4

	# Doble de lento para que el jugador siga la cadena visualmente
	await get_tree().create_timer(0.90).timeout
	_apply_gravity()
	await get_tree().create_timer(0.40).timeout

	_resolve_step(chain + 1)


func _min_group_size(val_idx: int, group_size: int) -> int:
	## Cantidad de fichas adyacentes necesarias para fusionar:
	## 10x5=50 | 50x2=100 | 100x5=500 | 500x2=1000
	## 1000x5=5000 or x2=2000 | 2000x5=10000 | 5000x2=10000 | 10000x2=20000 | 20000x2=desaparecen
	# -1 special case for 1000, can be either x5=5000 or x2=2000 (+1 or +2 to the index, requires know the ammount)
	# -2 special case for 2000, is 5 but jumps up +2 (to the index of 10000)
	const SIZES : Array[int] = [5, 2, 5, 2, -1, 5, 2, 2, 2]
	if val_idx >= 0 and val_idx < SIZES.size():
		if SIZES[val_idx] == -1:
			# Handle special case for 1000: can be either x5=5000 or x2=2000
			if group_size >= 5:
				return 5
			else:
				return 2
		# elif(SIZES[val_idx] == -2):
		# 	# Handle special case for 2000: is 5 but jumps up +2 (to the index of 10000)
		# 	return SIZES[val_idx+2]
		else:
			# Handle normal case
			return SIZES[val_idx]
	return 2


func _find_groups_from_triggers(triggers: Array) -> Array:
	## Devuelve solo los grupos que contienen al menos una de las monedas en "triggers".
	## Esto conecta los combos a la moneda lanzada por el jugador.
	if triggers.is_empty():
		return []

	var all_groups : Array = _find_groups()
	var connected  : Array = []

	for group in all_groups:
		var group_arr := group as Array
		var has_trigger := false
		for coin in group_arr:
			if triggers.has(coin):
				has_trigger = true
				break
		if has_trigger:
			connected.append(group)

	return connected


func _find_groups() -> Array:
	var visited : Dictionary = {}
	var groups  : Array      = []

	for coin in coins:
		var cd  := coin as CoinData
		var key := "%d_%d" % [cd.col, cd.row]
		if visited.has(key) or cd.type != CoinType.NORMAL:
			continue

		var group    := _flood(cd.val_idx, cd.col, cd.row, visited)
		var min_size : int = _min_group_size(cd.val_idx, group.size())
		if group.size() >= min_size:
			groups.append(group)

	return groups


func _flood(val_idx: int, sc: int, sr: int, visited: Dictionary) -> Array:
	var stack  : Array = [[sc, sr]]
	var result : Array = []

	while not stack.is_empty():
		var cur : Array = stack.pop_back() as Array
		var cc  : int   = cur[0] as int
		var cr  : int   = cur[1] as int
		var key : String = "%d_%d" % [cc, cr]
		if visited.has(key):
			continue
		var cd := _coin_at(cc, cr)
		if cd == null or cd.type != CoinType.NORMAL or cd.val_idx != val_idx:
			continue

		visited[key] = true
		result.append(cd)
		stack.append([cc - 1, cr])
		stack.append([cc + 1, cr])
		stack.append([cc,     cr - 1])
		stack.append([cc,     cr + 1])

	return result


func _merge_group(group: Array, chain: int) -> int:
	if group.is_empty():
		return 0

	var first   := group[0] as CoinData
	var v_idx   := first.val_idx
	var is_max  := v_idx == GameManager.COIN_VALUES.size() - 1
	var rc      := first.col
	var rr      := first.row

	for coin in group:
		var cell = _get_cell(coin.row, coin.col)
		cell.blink_cell(v_idx)
		coins.erase(coin)

	var base_pts : int = GameManager.COIN_VALUES[v_idx] * group.size()
	if is_max:
		base_pts *= 3

	var pts : int = base_pts * (1 + chain)

	if not is_max:
		# La moneda resultado se convierte en el nuevo disparador del siguiente combo
		# v_idx ya no es linear, hay que revisar el indice y el tamaño del grupo para revisar casos especiales
		var result_coin : CoinData = CoinData.new(rc, rr, _increment_coin_index(v_idx, group.size()), CoinType.NORMAL)
		coins.append(result_coin)
		_trigger_coins = [result_coin]   # solo esta ficha puede encadenar el siguiente paso
	else:
		_trigger_coins = []   # fusión máxima: no hay resultado → la cadena termina
	return pts
func _increment_coin_index(val_idx: int, group_size: int) -> int:
	if val_idx == 4:
		# Special case for 1000: can be either x5=5000 or x2=2000
		if group_size >= 5:
			return val_idx + 2
		else:
			return val_idx + 1
	elif val_idx == 5:
		return val_idx + 2
	else:
		# Normal case
		return val_idx + 1
func get_money_in_hand() -> int:
	if hand_val_idx < 0 or hand.size() == 0:
		return 0
	return GameManager.COIN_VALUES[hand_val_idx] * hand.size()

func _apply_gravity() -> void:
	# Las monedas vienen de ARRIBA: compactar hacia row 0 (cima del tablero).
	# Asi los huecos que dejan las fusiones se cierran hacia arriba,
	# y las monedas siguen en la parte superior donde el jugador puede verlas.
	for col in range(COLS):
		var col_coins : Array = []
		for coin in coins:
			var cd := coin as CoinData
			if cd.col == col:
				col_coins.append(cd)
		# Ordenar de menor a mayor fila (de arriba hacia abajo)
		col_coins.sort_custom(func(a, b): return (a as CoinData).row < (b as CoinData).row)

		# Reasignar desde row 0 hacia abajo (compactar a la CIMA)
		var target_row : int = 0
		for coin in col_coins:
			if coin.row != target_row:
				coin.fall_anim = coin.row - target_row
				coin.row = target_row
			target_row += 1

# ─────────────────────────────────────────────────────────────
#  DIBUJO PRINCIPAL
# ─────────────────────────────────────────────────────────────

func _get_current_level_objective() -> int:
	return 1000 + level * 1500


func _clear_grid() -> void:
	for cell in cells:
		cell._set_coin(-1)

func _refresh_coins() -> void:
	_clear_grid()
	for coin in coins:
		var cd : CoinData = coin as CoinData
		var cell = _get_cell(cd.row, cd.col)
		cell._set_coin(cd.val_idx)
		if cd.fall_anim != 0:
			cell._play_fall_anim(cd.fall_anim)
			cd.fall_anim = 0

func _get_cell(row: int, col: int) -> Control:
	return cells[row * COLS + col]

func _get_first_occupied_bottom_to_top_row(col: int) -> int:
	var lowest_row : int = 0
	for coin in coins:
		if(coin.col == col and coin.val_idx != -1):
			lowest_row = max(lowest_row, coin.row)
	return lowest_row
func _get_first_free_bottom_to_top_row(col: int) -> int:
	var lowest_row : int = 0
	for coin in coins:
		if(coin.col == col and coin.val_idx != -1):
			lowest_row = max(lowest_row, coin.row)
	return lowest_row + 1

func _refresh_player_area() -> void:
	# var py : float = float(PLAYER_Y)
	var cursor_row = _get_first_occupied_bottom_to_top_row(cursor_col);
	var cursor_cell = cells[cursor_row * COLS + cursor_col]
	var cell_global_center: Vector2 = cursor_cell.global_position + (cursor_cell.size * 0.5)

	_ser_chibi_cursor_position(cursor_col)

	character_chibi._set_coins_in_hand(hand.size(), hand_val_idx)
	
	grid_marker.show()
	grid_marker.global_position = cell_global_center - (grid_marker.size * 0.5)
	row_highlight.global_position = Vector2(cell_global_center.x - (row_highlight.size.x * 0.5), row_highlight.global_position.y)
func _ser_chibi_cursor_position(col: int) -> void:
	var cursor_cell = cells[col]
	var cell_global_center: Vector2 = cursor_cell.global_position + (cursor_cell.size * 0.5)
	# Implement the logic to set the chibi cursor position based on the column
	# This is a placeholder implementation and should be replaced with actual logic
	character_chibi.global_position = Vector2(cell_global_center.x - (character_chibi.size.x * 0.5), character_chibi.global_position.y)
	
func _refresh_hud() -> void:
	score_text.text = str(score)
	if arcade_mode:
		target_score_text.text = str(target_score)
		level_text.text = tr("level") + " " + str(level)
		# Barra de progreso
		var prog : float = clampf(float(score) / float(target_score), 0.0, 1.0)
		progress_bar.value = prog

	coin_counter_text.text = ""
	if hand.size() > 0:
		coin_counter_text.text = "x %d" % hand.size()

func _refresh_combo_text(delta: float) -> void:
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer < 0.0:
			combo_timer = 0.0
		var a : float = clampf(combo_timer / 0.5, 0.0, 1.0)
		combo_text_text.text = combo_text
		combo_text_text.modulate.a = a
	else:
		combo_text_text.modulate.a = 0
# ─────────────────────────────────────────────────────────────
#  UTILIDADES DE DIBUJO
# ─────────────────────────────────────────────────────────────
func _format_value(v: int) -> String:
	if v >= 1000:
		return "%dk" % (v / 1000)   # division entera intencional int→int
	else:
		return str(v)
# ─────────────────────────────────────────────────────────────
#  PERSISTENCIA
# ─────────────────────────────────────────────────────────────
const SAVE_PATH := "user://coinmerge.json"

func _save_highscore() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"hs": high_score}))
		f.close()

func _load_highscore() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var d : Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(d) == TYPE_DICTIONARY:
			high_score = (d as Dictionary).get("hs", 0) as int

func get_coin_in_hand_ID() -> int:
	return hand_val_idx
func get_coins_in_hand_count() -> int:
	return hand.size()
func return_container_coins(coins_instances: Array[Control]) -> void:
	print("Returning container coins: ", coins_instances)
	# TODO: get each coin idn and propagate them along the surface of the grid
	var x_dir: int = 1 # 1 = laft to righ, -1 = right to left
	if randf() < 0.5:
		x_dir = 1
	else:
		x_dir = -1

	var current_col: int
	if x_dir == 1:
		current_col = 0
	else:
		current_col = COLS - 1

	for coin_instance in coins_instances:
		var top_free_row: int = _get_first_free_bottom_to_top_row(current_col)
		var new_coin : CoinData = CoinData.new(current_col, top_free_row, coin_instance.coinID, CoinType.NORMAL)
		coins.append(new_coin)
		
		var cell = _get_cell(top_free_row, current_col)
		print("connecting on_reached for coinID:", coin_instance.coinID)
		coin_instance.on_reached.connect(_return_coin_instance)
		coin_instance._move_to_target(cell.global_position + (cell.size / 2))

		if (current_col + x_dir) < 0 or (current_col + x_dir) >= COLS:
			x_dir = x_dir *-1
		current_col += x_dir
func _twee_combo_text_scale() -> void:
	combo_text_text.text = combo_text
	# TODO: tween scale in and out
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(combo_text_text, "scale", Vector2(1.5, 1.5), 0.2)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(combo_text_text, "scale", Vector2(1, 1), 0.2)
func _return_coin_instance(instance: Control) -> void:
	print("_return_coin_instance " + str(instance.coinID))
	instance.on_reached.disconnect(_return_coin_instance)
	coins_pooling.return_instance(instance)
func _tween_grid_container_alpha(target_alpha: float, duration: float) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(grid_container, "modulate:a", target_alpha, duration)
