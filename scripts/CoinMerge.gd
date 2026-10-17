extends Node2D
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
const CELL       : int = 90
const COLS       : int = 7
const ROWS       : int = 10
const START_ROWS : int = 3      # filas pre-pobladas al iniciar

const VALUES : Array[int] = [10, 50, 100, 500, 1000, 5000, 10000, 20000]

const COIN_COLORS : Array[Color] = [
	Color(0.95, 0.78, 0.08),   # 10    — amarillo (fallback sin textura)
	Color(0.95, 0.42, 0.08),   # 50    — naranja
	Color(0.88, 0.18, 0.18),   # 100   — rojo
	Color(0.20, 0.50, 0.95),   # 500   — azul
	Color(0.15, 0.80, 0.35),   # 1000  — verde
	Color(0.05, 0.88, 0.88),   # 5000  — cian
	Color(0.95, 0.28, 0.72),   # 10000 — magenta
	Color(0.65, 0.10, 0.82),   # 20000 — morado
]

## Texturas de monedas/billetes. Deben estar en res://assets/coins/
## Si un archivo falta, se usa el color de COIN_COLORS como fallback.
const COIN_TEXTURES : Array[String] = [
	"res://assets/coins/10pesos.png",
	"res://assets/coins/50pesos.png",
	"res://assets/coins/100pesos.png",
	"res://assets/coins/500pesos.png",
	"res://assets/coins/1000.png",
	"res://assets/coins/5000.png",
	"res://assets/coins/10000.png",
	"res://assets/coins/20000.png",
]

# Posición del tablero en pantalla
const BOARD_X : int = 45
const BOARD_Y : int = 80

# Posición Y del área del jugador (debajo del tablero)
const PLAYER_Y : int = BOARD_Y + ROWS * CELL + 30

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

	func _init(c: int, r: int, v: int, t: int = 0) -> void:
		col     = c
		row     = r
		val_idx = v
		type    = t

# ─────────────────────────────────────────────────────────────
#  ESTADO GLOBAL
# ─────────────────────────────────────────────────────────────
var state         : int   = State.MENU
var coins         : Array = []          # Array[CoinData] — tablero

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
var throw_anim_y      : float = 0.0
var throw_anim_col    : int   = 0

var _font         : Font
var _tex_cache    : Array = []   # Array[Texture2D] cargadas en _ready
var _tex_bg       : Texture2D = null   # patrón de fondo general
var _tex_container: Texture2D = null   # marco del tablero

# ─────────────────────────────────────────────────────────────
#  INICIALIZACIÓN
# ─────────────────────────────────────────────────────────────
func _ready() -> void:
	_font = ThemeDB.fallback_font
	_load_highscore()
	_load_textures()

func enable_inputs() -> void:
	InputManager.gameplay_grab.triggered.connect(_action_grab)
	InputManager.gameplay_throw.triggered.connect(_action_throw)
	InputManager.gameplay_pause.triggered.connect(_pause_game)
	InputManager.ui_submit.triggered.connect(_check_submit_input)

func disable_inputs() -> void:
	InputManager.gameplay_grab.triggered.disconnect(_action_grab)
	InputManager.gameplay_throw.triggered.disconnect(_action_throw)
	InputManager.gameplay_pause.triggered.disconnect(_pause_game)
	InputManager.ui_submit.triggered.disconnect(_check_submit_input)

func _load_textures() -> void:
	_tex_cache.clear()
	for path in COIN_TEXTURES:
		if ResourceLoader.exists(path):
			_tex_cache.append(load(path) as Texture2D)
		else:
			_tex_cache.append(null)
	# Fondo general y marco del tablero
	if ResourceLoader.exists("res://assets/ui/pattern_BG.png"):
		_tex_bg = load("res://assets/ui/pattern_BG.png") as Texture2D
	if ResourceLoader.exists("res://assets/ui/container.png"):
		_tex_container = load("res://assets/ui/container.png") as Texture2D

# ─────────────────────────────────────────────────────────────
#  INPUT
# ─────────────────────────────────────────────────────────────
func _check_submit_input() -> void:
	match state:
		State.PAUSED:
			state = State.PLAYING
		State.VICTORY:
			if level < 10:
				level += 1
				_start_game()
		State.GAMEOVER:
			state = State.MENU
func _input(event: InputEvent) -> void:
	# if if event.is_action_pressed("ui_Submit"):
	# if event is InputEventKey and (event as InputEventKey).pressed \
	# 		and not (event as InputEventKey).echo:

	# Clic del ratón: mover cursor y agarrar/lanzar según posición
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if state != State.PLAYING:
			return
		var bx : int = int(mb.position.x) - BOARD_X
		if bx >= 0 and bx < COLS * CELL:
			var clicked_col : int = bx / CELL
			if int(mb.position.y) > PLAYER_Y - 20:
				# Clic en área del jugador → mover cursor
				cursor_col = clicked_col
			elif int(mb.position.y) >= BOARD_Y:
				# Clic dentro del tablero → mover cursor y agarrar
				cursor_col = clicked_col
				_action_grab()
			else:
				cursor_col = clicked_col
func _pause_game() -> void:
	state = State.PAUSED
func _process(delta: float) -> void:
	if state != State.PLAYING:
		queue_redraw()
		return

	# Movimiento continuo con teclado
	move_cooldown -= delta
	if move_cooldown <= 0.0:
		if Input.is_action_pressed("gameplay_Left"):
			cursor_col = maxi(0, cursor_col - 1)
			move_cooldown = 0.10
		elif Input.is_action_pressed("gameplay_Right"):
			cursor_col = mini(COLS - 1, cursor_col + 1)
			move_cooldown = 0.10

	# Timer de la animación de lanzamiento
	if throw_anim_active:
		throw_anim_y -= delta * float(ROWS * CELL) * 2.5
		var target_y : float = _top_of_column_y(throw_anim_col)
		if throw_anim_y <= target_y:
			throw_anim_active = false

	# Hileras nuevas caen desde arriba
	if not is_resolving:
		rise_timer += delta
		if rise_timer >= rise_interval:
			rise_timer = 0.0
			_drop_new_row()   # nueva hilera desde ARRIBA, sin fusión automática

	if combo_timer > 0.0:
		combo_timer -= delta

	queue_redraw()

# ─────────────────────────────────────────────────────────────
#  LÓGICA PRINCIPAL
# ─────────────────────────────────────────────────────────────
func _start_game() -> void:
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

	var t      : float = float(level - 1) / 9.0
	var t_fast : float = minf(t * 2.0, 1.0)  # alcanza dificultad máx en nivel 5
	rise_interval = lerp(6.0, 1.4, t_fast)   # de 6s entre filas hasta 1.4s
	# Los valores altos aparecen progresivamente desde el nivel 1:
	# nivel 1→idx 2 (hasta 10), nivel 3→idx 5 (hasta 500), nivel 5+→idx 9 (todos)
	max_val_idx   = clampi(3 + int(t_fast * 4.0), 3, 7)
	target_score  = int(25000.0 * pow(2.0, float(level - 1)))

	state = State.PLAYING
	_fill_start_rows()
	# NO llamamos _resolve() aquí: sin fusión automática al inicio


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


## Agarrar: toma la moneda más baja de la columna actual.
## Si la mano ya tiene monedas, solo permite agarrar el mismo valor.
func _action_grab() -> void:
	var coin : CoinData = _bottom_coin_in(cursor_col)
	if coin == null:
		return

	if hand_val_idx == -1:
		# Mano vacía → agarrar cualquier moneda
		coins.erase(coin)
		hand.append(coin)
		hand_val_idx = coin.val_idx

	elif coin.val_idx == hand_val_idx:
		# Mismo valor → añadir a la mano
		coins.erase(coin)
		hand.append(coin)

	# Si el valor es diferente, no se puede agarrar (mano ocupada con otro valor)


## Lanzar: suelta toda la mano en la columna actual.
## SOLO AQUÍ ocurre la fusión.
func _action_throw() -> void:
	if hand.is_empty():
		return

	# Verificar que hay espacio suficiente en la columna
	var free_rows : int = _free_rows_in(cursor_col)
	if free_rows <= 0:
		return   # columna llena, no se puede lanzar

	# Animación de lanzamiento (visual)
	throw_anim_col    = cursor_col
	throw_anim_y      = float(PLAYER_Y)
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


## Posición Y (en píxeles) de la cima del stack de una columna (para la animación).
func _top_of_column_y(col: int) -> float:
	var top_row : int = ROWS
	for coin in coins:
		var cd := coin as CoinData
		if cd.col == col and cd.row < top_row:
			top_row = cd.row
	if top_row >= ROWS:
		top_row = 0
	return float(BOARD_Y + top_row * CELL)


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
		if score >= target_score:
			if score > high_score:
				high_score = score
				_save_highscore()
			state = State.VICTORY
		queue_redraw()
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
	combo_timer = 2.4

	queue_redraw()

	# Doble de lento para que el jugador siga la cadena visualmente
	await get_tree().create_timer(0.90).timeout
	_apply_gravity()
	queue_redraw()
	await get_tree().create_timer(0.40).timeout

	_resolve_step(chain + 1)


func _min_group_size(val_idx: int) -> int:
	## Cantidad de fichas adyacentes necesarias para fusionar:
	## 1x5=5 | 5x2=10 | 10x5=50 | 50x2=100 | 100x5=500 | 500x2=1000
	## 1000x5=5000 | 5000x2=10000 | 10000x2=20000 | 20000x2=desaparecen
	const SIZES : Array[int] = [5, 2, 5, 2, 5, 2, 2, 2]
	if val_idx >= 0 and val_idx < SIZES.size():
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
		# Reglas reales: 1x5=5 | 5x2=10 | 10x5=50 | 50x2=100 | 100x5=500 | 500x2=boom
		var min_size : int = _min_group_size(cd.val_idx)
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
	var is_max  := v_idx == VALUES.size() - 1
	var rc      := first.col
	var rr      := first.row

	for coin in group:
		coins.erase(coin)

	var base_pts : int = VALUES[v_idx] * group.size()
	if is_max:
		base_pts *= 3

	var pts : int = base_pts * (1 + chain)

	if not is_max:
		# La moneda resultado se convierte en el nuevo disparador del siguiente combo
		var result_coin : CoinData = CoinData.new(rc, rr, v_idx + 1, CoinType.NORMAL)
		coins.append(result_coin)
		_trigger_coins = [result_coin]   # solo esta ficha puede encadenar el siguiente paso
	else:
		_trigger_coins = []   # fusión máxima: no hay resultado → la cadena termina

	return pts


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
			(coin as CoinData).row = target_row
			target_row += 1

# ─────────────────────────────────────────────────────────────
#  DIBUJO PRINCIPAL
# ─────────────────────────────────────────────────────────────
func _draw() -> void:
	var vp : Vector2 = get_viewport_rect().size

	match state:
		State.MENU:
			_draw_menu(vp)
		State.PLAYING:
			_draw_game(vp)
		State.PAUSED:
			_draw_game(vp)
			_draw_overlay_panel(vp, "PAUSA",
				"",
				"ESC  Continuar     M  Menú",
				Color(0.08, 0.08, 0.20, 0.93))
		State.VICTORY:
			_draw_game(vp)
			_draw_overlay_panel(vp, "¡VICTORIA!",
				"Puntos: %d" % score,
				"ENTER  Siguiente nivel",
				Color(0.06, 0.28, 0.10, 0.93))
		State.GAMEOVER:
			_draw_game(vp)
			_draw_overlay_panel(vp, "GAME OVER",
				"Puntos: %d" % score,
				"Presiona ENTER para volver a jugar",
				Color(0.28, 0.05, 0.05, 0.93))


func _draw_menu(vp: Vector2) -> void:
	if _tex_bg != null:
		draw_texture_rect(_tex_bg, Rect2(Vector2.ZERO, vp), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.16, 0.42, 0.27))

	# Decoración de fondo
	for row in range(ROWS):
		for col in range(COLS):
			var ci : int = (col + row * 2) % COIN_COLORS.size()
			_draw_coin_at(float(BOARD_X + col * CELL), float(BOARD_Y + row * CELL),
				COIN_COLORS[ci].darkened(0.6), "")

	# Panel central
	_draw_card(vp.x * 0.5, vp.y * 0.42, 360.0, 310.0, Color(0.10, 0.10, 0.20, 0.95))
	_draw_text_c("COIN MERGE",  vp.x * 0.5, vp.y * 0.42 - 100.0, 46, Color.WHITE)
	_draw_text_c("Nivel %d" % level, vp.x * 0.5, vp.y * 0.42 - 42.0, 24, Color(0.9,0.85,0.3))
	_draw_text_c("Objetivo: %d pts" % (1000 + level * 1500), vp.x * 0.5, vp.y * 0.42 + 0.0, 18, Color(0.7,0.7,0.7))
	_draw_text_c("Récord: %d" % high_score, vp.x * 0.5, vp.y * 0.42 + 34.0, 18, Color(0.5,0.9,0.5))
	# Mensaje de inicio parpadeante (sin botón, solo texto)
	var blink_alpha : float = 0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.004)
	_draw_text_c("— Presiona ENTER para partir —",
		vp.x * 0.5, vp.y * 0.42 + 90.0, 20, Color(0.85, 0.90, 1.0, blink_alpha))

	_draw_text_c("Z Agarrar  |  X Lanzar  |  ←→ Mover  |  ESC Pausa",
		vp.x * 0.5, vp.y - 36.0, 16, Color(0.45, 0.45, 0.58))


func _draw_game(vp: Vector2) -> void:
	# Fondo general: patrón tileado o color sólido como fallback
	if _tex_bg != null:
		draw_texture_rect(_tex_bg, Rect2(Vector2.ZERO, vp), true)
	else:
		draw_rect(Rect2(Vector2.ZERO, vp), Color(0.16, 0.42, 0.27))

	_draw_hud(vp)
	_draw_board_bg()
	_draw_coins()
	_draw_throw_anim()
	_draw_player_area(vp)

	# Texto de combo
	if combo_timer > 0.0:
		var a : float = clampf(combo_timer / 0.5, 0.0, 1.0)
		_draw_text_c(combo_text, float(BOARD_X) + float(COLS * CELL) * 0.5,
			float(BOARD_Y) - 36.0, 28, Color(1.0, 0.85, 0.1, a))


func _draw_board_bg() -> void:
	# ── Patrón ajedrez bicolor ──────────────────────────────────────────────
	# Verde oscuro RGB(41,106,69) y verde claro RGB(51,116,79)
	var dark  := Color(41.0/255.0,  106.0/255.0, 69.0/255.0)
	var light := Color(51.0/255.0,  116.0/255.0, 79.0/255.0)
	for row in range(ROWS):
		for col in range(COLS):
			var tile_col : Color = dark if (col + row) % 2 == 0 else light
			draw_rect(Rect2(float(BOARD_X + col * CELL), float(BOARD_Y + row * CELL),
				float(CELL), float(CELL)), tile_col)

	# ── Marco (container): cubre tablero + área del jugador ─────────────────
	# Posición fija que garantiza que las monedas nunca salen del marco.
	# PNG debe ser 680x1170 px con centro transparente.
	var frame_rect := Rect2(20.0, 58.0, 680.0, 1170.0)
	if _tex_container != null:
		draw_texture_rect(_tex_container, frame_rect, false)
	else:
		draw_rect(frame_rect, Color(0.20, 0.50, 0.25, 0.9), false, 3.0)

	# ── Resaltado de columna activa ─────────────────────────────────────────
	draw_rect(Rect2(float(BOARD_X + cursor_col * CELL), float(BOARD_Y),
		float(CELL), float(ROWS * CELL)),
		Color(1.0, 1.0, 1.0, 0.08))


func _draw_coins() -> void:
	for coin in coins:
		var cd : CoinData = coin as CoinData
		var cx : float = float(BOARD_X + cd.col * CELL)
		var cy : float = float(BOARD_Y + cd.row * CELL)
		_draw_coin_sprite(cx, cy, cd.val_idx)


## Dibuja una moneda usando textura PNG si está disponible, o color+label como fallback.
func _draw_coin_sprite(cx: float, cy: float, val_idx: int, override_alpha: float = 1.0) -> void:
	# Sin padding ni sombra: la moneda ocupa toda la celda
	var rect : Rect2 = Rect2(cx, cy, float(CELL), float(CELL))

	var tex : Texture2D = null
	if val_idx >= 0 and val_idx < _tex_cache.size():
		tex = _tex_cache[val_idx] as Texture2D

	if tex != null:
		draw_texture_rect(tex, rect, false, Color(1, 1, 1, override_alpha))
	else:
		# Fallback color sin sombra
		var col : Color = COIN_COLORS[val_idx] if val_idx < COIN_COLORS.size() else Color.GRAY
		col.a = override_alpha
		draw_rect(rect, col)
		_draw_text_c(_format_value(VALUES[val_idx]),
			cx + float(CELL) * 0.5, cy + float(CELL) * 0.5 + 8.0, 22, Color(1, 1, 1, override_alpha))


## Versión de color plano para decoraciones (fondo del menú, etc.)
func _draw_coin_at(cx: float, cy: float, col: Color, label: String) -> void:
	var pad : float = 5.0
	var rx  : float = cx + pad
	var ry  : float = cy + pad
	var rw  : float = float(CELL) - pad * 2.0
	var rh  : float = float(CELL) - pad * 2.0

	draw_rect(Rect2(rx + 3.0, ry + 3.0, rw, rh), Color(0, 0, 0, 0.35))
	draw_rect(Rect2(rx, ry, rw, rh), col)
	draw_rect(Rect2(rx, ry, rw, rh), col.lightened(0.38), false, 2.0)
	if label != "":
		_draw_text_c(label, cx + float(CELL) * 0.5, cy + float(CELL) * 0.5 + 8.0,
			20, Color.WHITE)


func _draw_throw_anim() -> void:
	if not throw_anim_active:
		return
	var cx : float = float(BOARD_X + throw_anim_col * CELL)
	var cy : float = throw_anim_y
	var idx : int = hand_val_idx if hand_val_idx >= 0 else 0
	_draw_coin_sprite(cx, cy, idx, 0.75)


func _draw_player_area(vp: Vector2) -> void:
	var py : float = float(PLAYER_Y)

	# Separador
	draw_line(Vector2(float(BOARD_X - 4), py - 8.0),
		Vector2(float(BOARD_X + COLS * CELL + 4), py - 8.0),
		Color(0.4, 0.4, 0.6, 0.5), 1.5)

	# Indicador del cursor (flecha apuntando HACIA ARRIBA)
	var arrow_x : float = float(BOARD_X + cursor_col * CELL) + float(CELL) * 0.5
	draw_rect(Rect2(arrow_x - 22.0, py, 44.0, 8.0), Color(1,1,1,0.80))
	draw_rect(Rect2(arrow_x - 14.0, py + 8.0, 28.0, 8.0), Color(1,1,1,0.55))
	draw_rect(Rect2(arrow_x - 6.0,  py + 16.0, 12.0, 8.0), Color(1,1,1,0.30))

	# Zona de la mano del jugador
	var hand_x_start : float = float(BOARD_X)
	var hand_y       : float = py + 34.0

	if hand.is_empty():
		_draw_text_c("Mano vacía  —  Z para agarrar",
			float(BOARD_X) + float(COLS * CELL) * 0.5, hand_y + 30.0,
			17, Color(0.45, 0.45, 0.58))
	else:
		_draw_text_c("EN MANO  (x%d)" % hand.size(),
			float(BOARD_X) + float(COLS * CELL) * 0.5, hand_y,
			16, Color(0.7, 0.8, 1.0))

		# Dibujar las monedas de la mano en fila horizontal (máx. 6 visibles)
		var num_visible : int = mini(hand.size(), 6)
		var spacing : float = float(COLS * CELL) / float(num_visible + 1)
		for i in range(num_visible):
			var cd  : CoinData = hand[i] as CoinData
			var hx  : float = hand_x_start + spacing * float(i + 1) - float(CELL) * 0.5
			_draw_coin_sprite(hx, hand_y + 14.0, cd.val_idx)

		if hand.size() > num_visible:
			_draw_text_c("+%d mas" % (hand.size() - num_visible),
				float(BOARD_X + COLS * CELL) - 30.0, hand_y + 50.0,
				15, Color(0.7,0.7,0.7))

		_draw_text_c("X para lanzar",
			float(BOARD_X) + float(COLS * CELL) * 0.5,
			hand_y + float(CELL) + 20.0,
			16, Color(0.55, 0.80, 0.55))

	# Controles rápidos
	_draw_text_c("Z Agarrar  |  X Lanzar  |  ←→  Mover",
		float(BOARD_X) + float(COLS * CELL) * 0.5, float(vp.y) - 22.0,
		15, Color(0.38, 0.38, 0.50))


func _draw_hud(vp: Vector2) -> void:
	draw_rect(Rect2(0, 0, vp.x, float(BOARD_Y) - 4.0),
		Color(0.04, 0.04, 0.09, 0.96))

	_draw_text("Puntos:",  14.0, 24.0, 15, Color(0.55,0.55,0.65))
	_draw_text(str(score), 14.0, 50.0, 30, Color(1.0, 0.9, 0.2))

	_draw_text("Meta:",    200.0, 24.0, 15, Color(0.55,0.55,0.65))
	_draw_text(str(target_score), 200.0, 50.0, 24, Color(0.45,0.90,0.50))

	_draw_text_c("Nivel %d" % level, vp.x - 80.0, 36.0, 20, Color(0.80,0.80,1.0))

	# Barra de progreso
	var prog : float = clampf(float(score) / float(target_score), 0.0, 1.0)
	draw_rect(Rect2(14.0, float(BOARD_Y) - 14.0, vp.x - 28.0, 10.0),
		Color(0.12, 0.12, 0.22))
	draw_rect(Rect2(14.0, float(BOARD_Y) - 14.0, (vp.x - 28.0) * prog, 10.0),
		Color(0.20 + prog * 0.60, 0.80 - prog * 0.30, 0.20))


func _draw_overlay_panel(vp: Vector2, title: String, score_line: String, action_line: String, bg: Color) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.0, 0.0, 0.0, 0.58))
	var pw : float = 400.0
	var ph : float = 260.0
	var px : float = (vp.x - pw) * 0.5
	var py : float = (vp.y - ph) * 0.5
	# Fondo principal
	draw_rect(Rect2(px, py, pw, ph), bg)
	draw_rect(Rect2(px, py, pw, ph), Color.WHITE.darkened(0.25), false, 2.5)
	# Título
	_draw_text_c(title, vp.x * 0.5, py + 52.0, 40, Color.WHITE)
	# Franja de puntuación
	draw_rect(Rect2(px + 16.0, py + 88.0, pw - 32.0, 44.0), Color(0.0, 0.0, 0.0, 0.30))
	_draw_text_c(score_line, vp.x * 0.5, py + 116.0, 22, Color(0.95, 0.95, 0.60))
	# Franja de acción
	draw_rect(Rect2(px + 16.0, py + 148.0, pw - 32.0, 44.0), Color(0.0, 0.0, 0.0, 0.30))
	_draw_text_c(action_line, vp.x * 0.5, py + 176.0, 17, Color(0.60, 0.95, 0.95))

# ─────────────────────────────────────────────────────────────
#  UTILIDADES DE DIBUJO
# ─────────────────────────────────────────────────────────────
func _format_value(v: int) -> String:
	if v >= 1000:
		return "%dk" % (v / 1000)   # division entera intencional int→int
	else:
		return str(v)


func _draw_text(text: String, x: float, y: float, size: int, color: Color) -> void:
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_text_c(text: String, cx: float, cy: float, size: int, color: Color) -> void:
	var w : float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, Vector2(cx - w * 0.5, cy), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_card(cx: float, cy: float, w: float, h: float, col: Color) -> void:
	draw_rect(Rect2(cx - w * 0.5, cy - h * 0.5, w, h), col)
	draw_rect(Rect2(cx - w * 0.5, cy - h * 0.5, w, h),
		Color(0.38, 0.45, 0.85, 0.55), false, 2.0)

func _draw_button(cx: float, cy: float, w: float, h: float, label: String, col: Color) -> void:
	var rx : float = cx - w * 0.5
	var ry : float = cy - h * 0.5
	draw_rect(Rect2(rx, ry, w, h), col)
	draw_rect(Rect2(rx, ry, w, h), col.lightened(0.4), false, 1.5)
	_draw_text_c(label, cx, cy + 8.0, 18, Color.WHITE)

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
