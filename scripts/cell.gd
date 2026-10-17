extends Control

@export var coinTexture : TextureRect
@export var background : ColorRect
@export var speed : float
signal on_reached(sender: Control)
signal on_cell_clicked(col: int, row: int, sender: Control, button_index: int)

var startGlobalPosition : Vector2
var targetGlobalPosition : Vector2
var moving : bool
var reachedTarget : bool
var direction : Vector2 = Vector2.ZERO
var coinID : int = -1
var coinValue : int = 0
var baseCoinY : float = 0
var col : int = 0
var row : int = 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	baseCoinY = coinTexture.position.y

var lastYSign : int = 0
func _gui_input(event: InputEvent) -> void:
	print("Cell GUI input event: ", event)
	# Check if the input event is a mouse button press
	if event is InputEventMouseButton:
		# Check if it is a left-click and that it was a press (not a release)
		if event.pressed:
			print("Cell clicked at col: %d, row: %d" % [col, row])
			on_cell_clicked.emit(col, row, self, event.button_index)
func set_cell_position(col: int, row: int) -> void:
	self.col = col
	self.row = row
func _process(delta: float) -> void:
	if moving and !reachedTarget:
		var newPosition = global_position + direction * speed * delta
		var currentYSign = sign(targetGlobalPosition.y - newPosition.y)
		if currentYSign != lastYSign or newPosition.distance_to(targetGlobalPosition) < 1:
			global_position = targetGlobalPosition
			moving = false
			reachedTarget = true
			print("Reached target for coinID:", coinID)
			print(self.on_reached.get_connections())
			self.on_reached.emit(self)
			disconnect_all(self.on_reached)
		else:
			global_position = newPosition
func disconnect_all(sig: Signal) -> void:
	for connection in sig.get_connections():
		# Each connection dictionary contains the target 'callable'
		var target_callable: Callable = connection["callable"]
		sig.disconnect(target_callable)

func _set_coin(_coinID: int) -> void:
	coinID = _coinID
	coinValue = GameManager.get_coin_value_by_id(_coinID)
	coinTexture.texture = GameManager.get_coin_texture_by_id(_coinID)

func _move_to_target(target_global_position_centered: Vector2) -> void:
	startGlobalPosition = global_position
	targetGlobalPosition = target_global_position_centered - (size * 0.5)
	self.direction = (targetGlobalPosition - startGlobalPosition).normalized()
	lastYSign = sign(direction.y)

	moving = true
	reachedTarget = false
	# You can add tweening or animation logic here to move the coin towards the target

func _reached_target() -> bool:
	return reachedTarget

func _align_center_to_position(target_global_position: Vector2) -> void:
	global_position = target_global_position - (size * 0.5)
func blink_cell(v_idx: int) -> void:
	print("Blinking cell with coinID:", v_idx)
	if v_idx < 0:
		return
	
	var color = GameManager.get_coin_color_by_id(v_idx)
	background.color = color
	background.color.a = 0

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(background, "color:a", 1.0, 0.2)
	tween.tween_property(background, "color:a", 0.0, 0.2)
func _play_fall_anim(fall_anim: int) -> void:
	if fall_anim <= 0:
		return
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	coinTexture.position.y = baseCoinY + (fall_anim * GameManager.CELL_SIZE)
	tween.tween_property(coinTexture, "position:y", baseCoinY, 0.2)