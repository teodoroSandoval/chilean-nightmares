extends Resource
class_name StoryChapter

@export_category("Settings")
@export var name: String
@export var rewards: Array[ItemData]

@export_category("Dialogs")
@export var initial_dialogs: Array[Dialog]
@export var ending_dialogs: Array[Dialog]

@export_category("Clientes")
@export var clients: Array[ClientRequest]
@export var story_client_requests: Array[ClientRequest]
@export var random_client_requests: Array[ClientRequest]
