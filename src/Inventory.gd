extends Control

@onready var grid = $GridContainer  # Убедись, что путь верный
var slot_scene = preload("res://src/InventorySlot.tscn")

@export var total_slots: int = 25  # Сколько ячеек в инвентаре
var current_player: CharacterBody3D


func _ready():
	for i in range(total_slots):
		var slot = slot_scene.instantiate()
		grid.add_child(slot)
