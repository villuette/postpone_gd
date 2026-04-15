extends PanelContainer

@onready var icon_rect = $Icon  # Твой TextureRect
@onready var count_label = $CountLabel  # Твой Label

var item_data: ItemData = null


func update_slot(data: ItemData):
    item_data = data
    if item_data == null:
        icon_rect.texture = null
        count_label.text = ""
    else:
        icon_rect.texture = item_data.icon
        # Показываем число, только если предметов больше 1
        if item_data.stackable and item_data.current_stack > 1:
            count_label.text = str(item_data.current_stack)
        else:
            count_label.text = ""
