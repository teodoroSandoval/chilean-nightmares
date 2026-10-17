extends TextureRect

@export var coins_in_hand: Array[Control]
@export var coins_base: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass
func _set_coins_in_hand(count: int, coinID: int) -> void:
	for i in range(coins_in_hand.size()):
		var coin = coins_in_hand[i]
		if i < count:
			coin._set_coin(coinID)
			coin.show()
		else:
			coin._set_coin(-1)
			coin.hide()
func _get_coin_position() -> Vector2:
	return position + coins_base.position + (coins_base.size * 0.5)
func _get_coin_global_position() -> Vector2:
	return coins_base.global_position + (coins_base.size * 0.5)
