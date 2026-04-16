extends Control

@onready var grid = $GridContainer  # Убедись, что путь верный
var slot_scene = preload("res://src/InventorySlot.tscn")

@export var total_slots: int = 25  # Сколько ячеек в инвентаре
var current_player: CharacterBody3D


func _ready():
    for i in range(total_slots):
        var slot = slot_scene.instantiate()
        grid.add_child(slot)


func add_item(new_item: ItemData):
    # 1. Если стакается, пробуем добавить в существующий стак
    if new_item.stackable:
        for slot in grid.get_children():
            if slot.item_data and slot.item_data.title == new_item.title:
                if slot.item_data.current_stack < slot.item_data.max_stack:
                    slot.item_data.current_stack += 1
                    slot.update_slot(slot.item_data)
                    return true  # Успешно добавили

    # 2. Ищем свободное место
    for slot in grid.get_children():
        if slot.item_data == null:
            # Важно: делаем копию ресурса, чтобы не менять оригинал!
            slot.update_slot(new_item.duplicate())
            return true

    print("Инвентарь полон!")
    return false
