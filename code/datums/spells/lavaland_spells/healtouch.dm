//basic touch ability that heals basic damage types accessed by the ashwalker shaman
/obj/effect/proc_holder/spell/touch/healtouch
	name = "healing touch"
	desc = "This spell charges your hand with the vile energy of the Necropolis, permitting you to undo some external injuries from a target."
	hand_path = /obj/item/melee/touch_attack/healtouch

	school = "evocation"
	panel = "Ashwalker"
	base_cooldown = 20 SECONDS
	clothes_req = FALSE

	action_icon_state = "healtouch"

/obj/item/melee/touch_attack/healtouch
	name = "\improper healing touch"
	desc = "A blaze of life-granting energy from the hand. Heals minor to moderate injuries."
	catchphrase = "BE REPLENISHED!!"
	on_use_sound = 'sound/magic/staff_healing.ogg'
	icon_state = "disintegrate" //ironic huh
	item_state = "disintegrate"
	//total of 40 assuming they're hurt by both brute and burn
	var/brute = 20
	var/burn = 20
	var/tox = 10
	var/oxy = 50
	var/heal_self = FALSE

/obj/item/melee/touch_attack/healtouch/afterattack(atom/target, mob/living/carbon/user, proximity)
	if(!proximity || (target == user && !heal_self) || !ismob(target) || !iscarbon(user) || user.lying || user.handcuffed)
		return
	var/mob/living/M = target
	new /obj/effect/temp_visual/heal(get_turf(M), "#899d39")
	M.heal_overall_damage(brute, burn)
	M.adjustToxLoss(-tox)
	M.adjustOxyLoss(-oxy)
	return ..()

/obj/effect/proc_holder/spell/touch/healtouch/advanced
	hand_path = /obj/item/melee/touch_attack/healtouch/advanced

/obj/item/melee/touch_attack/healtouch/advanced
	heal_self = TRUE
