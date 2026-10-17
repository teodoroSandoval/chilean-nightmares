extends Resource
class_name ClientRequest

@export_category("Client")
@export var character_data: CharacterData

@export_category("Dialogs")
@export var initial_dialogs: Array[String]
@export var ending_dialogs: Array[String]

@export_category("Request")
@export var requested_items: Array[ItemStack]
@export var money: int
