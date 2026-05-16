extends Node
class_name AnimationController

@export var anim_tree_hands: AnimationTree

@onready var hands_main_sm = anim_tree_hands.get("parameters/playback")
@onready var weapon_attached_sm = anim_tree_hands.get("parameters/WeaponAttached/StateMachine/playback")
@onready var empty_hands_sm = anim_tree_hands.get("parameters/EmptyHands/playback")

func update_animations(velocity: Vector3, is_running: bool, has_weapon: bool):
	var speed = Vector2(velocity.x, velocity.z).length()
	
	if has_weapon:
		hands_main_sm.travel("WeaponAttached")
		if is_running and speed > 0.1:
			weapon_attached_sm.travel("Sprint")
		else:
			weapon_attached_sm.travel("Pistol_Idle")
	else:
		hands_main_sm.travel("EmptyHands")
		if speed > 0.1:
			if is_running:
				empty_hands_sm.travel("Sprint")
			else:
				empty_hands_sm.travel("Walk")
		else:
			empty_hands_sm.travel("Idle")

func play_shoot():
	anim_tree_hands.set("parameters/WeaponAttached/OneShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
