/obj/item/flash
	name = "flash"
	desc = "A powerful and versatile flashbulb device, with applications ranging from disorienting attackers to acting as visual receptors in robot production."
	icon = 'icons/obj/device.dmi'
	icon_state = "flash"
	item_state = "flashtool"	//looks exactly like a flash (and nothing like a flashbang)
	belt_icon = "flash"
	throwforce = 0
	w_class = WEIGHT_CLASS_TINY
	throw_speed = 3
	throw_range = 7
	flags = CONDUCT
	materials = list(MAT_METAL = 300, MAT_GLASS = 300)
	origin_tech = "magnets=2;combat=1"

	var/times_used = 0 //Number of times it's been used.
	var/broken = FALSE     //Is the flash burnt out?
	var/last_used = 0 //last world.time it was used.
	var/battery_panel = FALSE //whether the flash can be modified with a cell or not
	var/overcharged = FALSE   //if overcharged the flash will set people on fire then immediately burn out (does so even if it doesn't blind them).
	var/can_overcharge = TRUE //set this to FALSE if you don't want your flash to be overcharge capable
	var/use_sound = 'sound/weapons/flash.ogg'
	/// This is the duration of the cooldown
	var/cooldown_duration = 1 SECONDS
	COOLDOWN_DECLARE(flash_cooldown)


/obj/item/flash/update_icon_state()
	icon_state = "[initial(icon_state)][broken ? "burnt" : ""]"


/obj/item/flash/update_overlays()
	. = ..()
	if(overcharged)
		. += "overcharge"


/obj/item/flash/proc/clown_check(mob/user)
	if(user && (CLUMSY in user.mutations) && prob(50))
		flash_carbon(user, user, 30 SECONDS, 0)
		return FALSE
	return TRUE


/obj/item/flash/attackby(obj/item/W, mob/user, params)
	if(can_overcharge)
		if(W.tool_behaviour == TOOL_SCREWDRIVER)
			if(battery_panel)
				to_chat(user, "<span class='notice'>You close the battery compartment on the [src].</span>")
				battery_panel = FALSE
			else
				to_chat(user, "<span class='notice'>You open the battery compartment on the [src].</span>")
				battery_panel = TRUE
		if(battery_panel && !overcharged)
			if(istype(W, /obj/item/stock_parts/cell))
				to_chat(user, "<span class='notice'>You jam the cell into battery compartment on the [src].</span>")
				qdel(W)
				overcharged = TRUE
				update_icon(UPDATE_OVERLAYS)


/obj/item/flash/random/New()
	..()
	if(prob(25))
		broken = TRUE
		update_icon(UPDATE_ICON_STATE)

/obj/item/flash/proc/burn_out() //Made so you can override it if you want to have an invincible flash from R&D or something.
	broken = TRUE
	update_icon(UPDATE_ICON_STATE)
	visible_message("<span class='notice'>The [src.name] burns out!</span>")


/obj/item/flash/proc/flash_recharge(var/mob/user)
	if(prob(times_used * 2))	//if you use it 5 times in a minute it has a 10% chance to break!
		burn_out()
		return FALSE

	var/deciseconds_passed = world.time - last_used
	times_used -= round(deciseconds_passed / 100) //get 1 charge every 10 seconds

	last_used = world.time
	times_used = max(0, times_used) //sanity


/obj/item/flash/proc/try_use_flash(mob/user = null)

	if(broken)
		return FALSE
	if(!COOLDOWN_FINISHED(src, flash_cooldown))
		to_chat(user, "<span class='warning'>Your [name] is still too hot to use again!</span>")
		return FALSE
	COOLDOWN_START(src, flash_cooldown, cooldown_duration)
	flash_recharge(user)

	playsound(loc, use_sound, 100, 1)
	flick("[initial(icon_state)]2", src)
	set_light(2, 1, COLOR_WHITE)
	addtimer(CALLBACK(src, TYPE_PROC_REF(/atom, set_light), 0), 2)
	times_used++

	if(user && !clown_check(user))
		return FALSE

	return TRUE


/obj/item/flash/proc/flash_carbon(mob/living/carbon/M, mob/user = null, power = 10 SECONDS, targeted = 1)
	if(user)
		add_attack_logs(user, M, "Flashed with [src]")
		if(targeted)
			if(M.weakeyes)
				M.Weaken(6 SECONDS) //quick weaken bypasses eye protection but has no eye flash
			if(M.flash_eyes(1, 1))
				M.AdjustConfused(power)
				M.Stun(2 SECONDS)
				visible_message("<span class='disarm'>[user] blinds [M] with the flash!</span>")
				to_chat(user, "<span class='danger'>You blind [M] with the flash!</span>")
				to_chat(M, "<span class='userdanger'>[user] blinds you with the flash!</span>")
				if(M.weakeyes)
					M.Stun(4 SECONDS)
					M.visible_message("<span class='disarm'>[M] gasps and shields [M.p_their()] eyes!</span>", "<span class='userdanger'>You gasp and shield your eyes!</span>")
			else
				visible_message("<span class='disarm'>[user] fails to blind [M] with the flash!</span>")
				to_chat(user, "<span class='warning'>You fail to blind [M] with the flash!</span>")
				to_chat(M, "<span class='danger'>[user] fails to blind you with the flash!</span>")
			return

	if(M.flash_eyes())
		M.AdjustConfused(power)

/obj/item/flash/attack(mob/living/M, mob/user)
	if(!try_use_flash(user))
		return FALSE
	if(iscarbon(M))
		flash_carbon(M, user, 10 SECONDS, 1)
		if(overcharged)
			M.adjust_fire_stacks(6)
			M.IgniteMob()
			burn_out()
		return TRUE
	else if(issilicon(M))
		add_attack_logs(user, M, "Flashed with [src]")
		if(M.flash_eyes(affect_silicon = TRUE))
			M.Weaken(rand(10 SECONDS, 20 SECONDS))
			user.visible_message("<span class='disarm'>[user] overloads [M]'s sensors with the [src.name]!</span>", "<span class='danger'>You overload [M]'s sensors with the [src.name]!</span>")
		return TRUE
	user.visible_message("<span class='disarm'>[user] fails to blind [M] with the [src.name]!</span>", "<span class='warning'>You fail to blind [M] with the [src.name]!</span>")


/obj/item/flash/attack_self(mob/living/carbon/user, flag = 0, emp = FALSE)
	if(!try_use_flash(user))
		return FALSE
	user.visible_message("<span class='disarm'>[user]'s [src.name] emits a blinding light!</span>", "<span class='danger'>Your [src.name] emits a blinding light!</span>")
	for(var/mob/living/carbon/M in oviewers(3, null))
		flash_carbon(M, user, 6 SECONDS, FALSE)


/obj/item/flash/emp_act(severity)
	if(!try_use_flash())
		return FALSE
	for(var/mob/living/carbon/M in viewers(3, null))
		flash_carbon(M, null, 20 SECONDS, FALSE)
	burn_out()
	..()

/obj/item/flash/cyborg
	origin_tech = null

/obj/item/flash/cyborg/attack(mob/living/M, mob/user)
	..()
	new /obj/effect/temp_visual/borgflash(get_turf(src))

/obj/item/flash/cyborg/attack_self(mob/user)
	..()
	new /obj/effect/temp_visual/borgflash(get_turf(src))

/obj/item/flash/cameraflash
	name = "camera"
	icon = 'icons/obj/items.dmi'
	desc = "A polaroid camera. 10 photos left."
	icon_state = "camera"
	item_state = "electropack" //spelling, a coders worst enemy. This part gave me trouble for a while.
	belt_icon = null
	w_class = WEIGHT_CLASS_SMALL
	slot_flags = SLOT_BELT
	can_overcharge = FALSE
	var/flash_max_charges = 5
	var/flash_cur_charges = 5
	var/charge_tick = 0
	use_sound = 'sound/items/polaroid1.ogg'

/obj/item/flash/cameraflash/burn_out() //stops from burning out
	return

/obj/item/flash/cameraflash/New()
	..()
	START_PROCESSING(SSobj, src)

/obj/item/flash/cameraflash/Destroy()
	STOP_PROCESSING(SSobj, src)
	return ..()

/obj/item/flash/cameraflash/process() //this and the two parts above are part of the charge system.
	charge_tick++
	if(charge_tick < 10)
		return FALSE
	charge_tick = 0
	flash_cur_charges = min(flash_cur_charges+1, flash_max_charges)
	return TRUE

/obj/item/flash/cameraflash/try_use_flash(mob/user = null)
	if(!flash_cur_charges)
		to_chat(user, "<span class='warning'>[src] needs time to recharge!</span>")
		return FALSE
	. = ..()
	if(.)
		flash_cur_charges--
		to_chat(user, "[src] now has [flash_cur_charges] charge\s.")

/obj/item/flash/armimplant
	name = "photon projector"
	desc = "A high-powered photon projector implant normally used for lighting purposes, but also doubles as a flashbulb weapon. Self-repair protocols fix the flashbulb if it ever burns out."
	cooldown_duration = 2 SECONDS
	var/obj/item/organ/internal/cyberimp/arm/flash/I = null

/obj/item/flash/armimplant/Destroy()
	I = null
	return ..()

/obj/item/flash/armimplant/burn_out()
	if(I && I.owner)
		to_chat(I.owner, "<span class='warning'>Your [name] implant overheats and deactivates!</span>")
		I.Retract()

/obj/item/flash/synthetic //just a regular flash now
