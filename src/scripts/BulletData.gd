@tool
extends ItemData
class_name BulletData


#func _validate_property(property: Dictionary):
	#super._validate_property(property)
			
enum DamageType { LEAD, CRYSTAL, PURE }

@export var damage_type: DamageType = DamageType.LEAD
@export var base_damage: float = 20.0
@export var force: float = 10.0 # Сила импульса
@export var tracer_color: Color = Color.WHITE
