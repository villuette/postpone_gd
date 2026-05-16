extends Node

# --- ГЛОБАЛЬНЫЕ СУЩНОСТИ ---
# Используются для передачи контекста (Actor-Target)

signal request_dialogue(lines, time)
signal subtitles_updated()
# ПЕРЕДВИЖЕНИЕ
signal player_sprint_toggled(actor: Node, is_running: bool)

# БОЕВАЯ СИСТЕМА
signal weapon_shoot_requested(actor: Node, target_point: Vector3, excluded: Array)
signal weapon_fired(actor: Node, weapon_node: Node)
signal weapon_reloaded(actor: Node, direction: int) # 1 или -1 для вращения барабана
signal weapon_drum_synced(actor: Node, bullets: Array) # Передает Array[BulletData]
signal weapon_predictive_hit_updated(actor: Node, hit_point: Vector3)

# ИНВЕНТАРЬ И ПРЕДМЕТЫ
signal item_collected(actor: Node, data: ItemData)
signal item_equip_requested(actor: Node, data: ItemData)
signal item_drop_requested(actor: Node, data: ItemData)

# ХАРАКТЕРИСТИКИ
signal stat_changed(actor: Node, stat_type: String, current_val: float, max_val: float)
signal entity_died(actor: Node)

# ИНТЕРФЕЙС
signal preview_requested(visual_scene: PackedScene)
signal interaction_hint_updated(text: String)
