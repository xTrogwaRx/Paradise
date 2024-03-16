////////////////////////////////////////////////////////////////////////////////
/// HYPOSPRAY
////////////////////////////////////////////////////////////////////////////////

/obj/item/reagent_containers/hypospray
	name = "hypospray"
	desc = "The DeForest Medical Corporation hypospray is a sterile, air-needle autoinjector for rapid administration of drugs to patients."
	icon = 'icons/obj/hypo.dmi'
	item_state = "hypo"
	icon_state = "hypo"
	belt_icon = "hypospray"
	amount_per_transfer_from_this = 5
	volume = 30
	possible_transfer_amounts = list(1,2,3,4,5,10,15,20,25,30)
	resistance_flags = ACID_PROOF
	container_type = OPENCONTAINER
	slot_flags = SLOT_BELT
	var/ignore_flags = FALSE
	var/emagged = FALSE
	var/safety_hypo = FALSE

/obj/item/reagent_containers/hypospray/attack(mob/living/M, mob/user)
	if(!reagents.total_volume)
		to_chat(user, "<span class='warning'>[src] is empty!</span>")
		return
	if(!iscarbon(M))
		return

	if(reagents.total_volume && (ignore_flags || M.can_inject(user, TRUE))) // Ignore flag should be checked first or there will be an error message.
		to_chat(M, "<span class='warning'>You feel a tiny prick!</span>")
		to_chat(user, "<span class='notice'>You inject [M] with [src].</span>")

		if(M.reagents)
			var/list/injected = list()
			for(var/datum/reagent/R in reagents.reagent_list)
				injected += R.name

			var/primary_reagent_name = reagents.get_master_reagent_name()
			var/fraction = min(amount_per_transfer_from_this / reagents.total_volume, 1)
			reagents.reaction(M, REAGENT_INGEST, fraction)
			var/trans = reagents.trans_to(M, amount_per_transfer_from_this)

			if(safety_hypo)
				visible_message("<span class='warning'>[user] injects [M] with [trans] units of [primary_reagent_name].</span>")
				playsound(loc, 'sound/goonstation/items/hypo.ogg', 80, 0)

			to_chat(user, "<span class='notice'>[trans] unit\s injected.  [reagents.total_volume] unit\s remaining in [src].</span>")

			var/contained = english_list(injected)

			add_attack_logs(user, M, "Injected with [src] containing ([contained])", reagents.harmless_helper() ? ATKLOG_ALMOSTALL : null)

		return TRUE

/obj/item/reagent_containers/hypospray/on_reagent_change()
	if(safety_hypo && !emagged)
		var/found_forbidden_reagent = FALSE
		for(var/datum/reagent/R in reagents.reagent_list)
			if(!GLOB.safe_chem_list.Find(R.id))
				reagents.del_reagent(R.id)
				found_forbidden_reagent = TRUE
		if(found_forbidden_reagent)
			if(ismob(loc))
				to_chat(loc, "<span class='warning'>[src] identifies and removes a harmful substance.</span>")
			else
				visible_message("<span class='warning'>[src] identifies and removes a harmful substance.</span>")


/obj/item/reagent_containers/hypospray/emag_act(mob/user)
	if(safety_hypo && !emagged)
		add_attack_logs(user, src, "emagged")
		emagged = TRUE
		ignore_flags = TRUE
		if(user)
			to_chat(user, "<span class='warning'>You short out the safeties on [src].</span>")

/obj/item/reagent_containers/hypospray/safety
	name = "medical hypospray"
	desc = "A general use medical hypospray for quick injection of chemicals. There is a safety button by the trigger."
	icon_state = "medivend_hypo"
	belt_icon = "medical_hypospray"
	safety_hypo = TRUE
	var/has_paint
	var/colour

/obj/item/reagent_containers/hypospray/safety/attackby(obj/item/I, mob/user, params)
	if(istype(I, /obj/item/toy/crayon/spraycan))
		var/obj/item/toy/crayon/spraycan/spraycan = I
		if(spraycan.capped)
			to_chat(user, "<span class='warning'>Take the cap off first!</span>")
			return
		if(spraycan.uses < 2)
			to_chat(user, "<span class ='warning'>There is not enough paint in the can!")
			return
		colour = spraycan.colour
		has_paint = TRUE
		icon_state = "whitehypo"
		src.remove_filter("hypospray_handle")
		var/icon/hypo_mask = icon('icons/obj/hypo.dmi',"colour_hypo" )
		src.add_filter("hypospray_handle",1,layering_filter(icon = hypo_mask, color = colour))
	if(istype(I, /obj/item/soap) && has_paint)
		to_chat(user, span_notice("You wash off the paint layer from hypospray"))
		has_paint = FALSE
		src.remove_filter("hypospray_handle")
		icon_state = "medivend_hypo"
	..()


/obj/item/reagent_containers/hypospray/safety/ert
	name = "medical hypospray (Omnizine)"
	list_reagents = list("omnizine" = 30)

/obj/item/reagent_containers/hypospray/CMO
	volume = 250
	possible_transfer_amounts = list(1,2,3,4,5,10,15,20,25,30,35,40,45,50)
	list_reagents = list("omnizine" = 100)
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | ACID_PROOF

/obj/item/reagent_containers/hypospray/CMO/empty
	list_reagents = null

/obj/item/reagent_containers/hypospray/combat
	name = "combat stimulant injector"
	desc = "A modified air-needle autoinjector, used by support operatives to quickly heal injuries in combat."
	amount_per_transfer_from_this = 15
	possible_transfer_amounts = null
	icon_state = "combat_hypo"
	volume = 90
	ignore_flags = 1 // So they can heal their comrades.
	list_reagents = list("epinephrine" = 30, "weak_omnizine" = 30, "salglu_solution" = 30)

/obj/item/reagent_containers/hypospray/ertm
	volume = 90
	ignore_flags = 1
	icon_state = "combat_hypo"
	possible_transfer_amounts = list(1,2,3,4,5,10,15,20,25,30)

/obj/item/reagent_containers/hypospray/ertm/hydrocodone
	amount_per_transfer_from_this = 10
	name = "Hydrocodon combat stimulant injector"
	desc = "A modified air-needle autoinjector, used by support operatives to quickly heal injuries in combat. Contains hydrocodone."
	icon_state = "hypocombat-hydro"
	list_reagents = list("hydrocodone" = 90)

/obj/item/reagent_containers/hypospray/ertm/perfluorodecalin
	amount_per_transfer_from_this = 3
	name = "Perfluorodecalin combat stimulant injector"
	icon_state = "hypocombat-perfa"
	desc = "A modified air-needle autoinjector, used by support operatives to quickly heal injuries in combat. Contains perfluorodecalin."
	list_reagents = list("perfluorodecalin" = 90)

/obj/item/reagent_containers/hypospray/ertm/pentic_acid
	amount_per_transfer_from_this = 5
	name = "Pentic acid combat stimulant injector"
	icon_state = "hypocombat-dtpa"
	desc = "A modified air-needle autoinjector, used by support operatives to quickly heal injuries in combat. Contains pentic acid."
	list_reagents = list("pen_acid" = 90)

/obj/item/reagent_containers/hypospray/ertm/epinephrine
	amount_per_transfer_from_this = 5
	name = "Epinephrine combat stimulant injector"
	icon_state = "hypocombat-epi"
	desc = "A modified air-needle autoinjector, used by support operatives to quickly heal injuries in combat. Contains epinephrine."
	list_reagents = list("epinephrine" = 90)

/obj/item/reagent_containers/hypospray/ertm/mannitol
	amount_per_transfer_from_this = 5
	name = "Mannitol combat stimulant injector"
	desc = "A modified air-needle autoinjector, used by support operatives to quickly heal injuries in combat. Contains mannitol."
	icon_state = "hypocombat-mani"
	list_reagents = list("mannitol" = 90)

/obj/item/reagent_containers/hypospray/ertm/oculine
	amount_per_transfer_from_this = 5
	name = "Oculine combat stimulant injector"
	icon_state = "hypocombat-ocu"
	desc = "A modified air-needle autoinjector, used by support operatives to quickly heal injuries in combat. Contains oculine."
	list_reagents = list("oculine" = 90)

/obj/item/reagent_containers/hypospray/ertm/omnisal
	amount_per_transfer_from_this = 10
	name = "DilOmni-Salglu solution combat stimulant injector"
	icon_state = "hypocombat-womnisal"
	desc = "A modified air-needle autoinjector, used by support operatives to quickly heal injuries in combat. Contains a solution of dilute omnisin and saline."
	list_reagents = list("weak_omnizine" = 45, "salglu_solution" = 45)
	possible_transfer_amounts = list(10, 20, 30)

/obj/item/reagent_containers/hypospray/combat/nanites
	desc = "A modified air-needle autoinjector for use in combat situations. Prefilled with expensive medical nanites for rapid healing."
	volume = 100
	list_reagents = list("nanites" = 100)

/obj/item/reagent_containers/hypospray/autoinjector
	name = "emergency autoinjector"
	desc = "A rapid and safe way to stabilize patients in critical condition for personnel without advanced medical knowledge."
	icon_state = "autoinjector"
	item_state = "autoinjector"
	belt_icon = "autoinjector"
	amount_per_transfer_from_this = 10
	possible_transfer_amounts = null
	volume = 10
	var/only_self = FALSE //is it usable only on yourself
	var/spent = FALSE
	ignore_flags = TRUE //so you can medipen through hardsuits
	container_type = DRAWABLE
	flags = null
	list_reagents = list("epinephrine" = 10)
	var/reskin_allowed = FALSE
	//for radial menu
	var/list/skinslist = list(
		"Completely Blue" = "ablueinjector",
		"Blue" = "blueinjector",
		"Completely Red" = "redinjector",
		"Red" = "lepopen",
		"Golden" = "goldinjector",
		"Completely Green" = "greeninjector",
		"Green" = "autoinjector",
		"Gray" = "stimpen",
	)

/obj/item/reagent_containers/hypospray/autoinjector/attackby(obj/item/W, mob/user)
	if(reskin_allowed)
		if(istype(W, /obj/item/pen))
			var/t = clean_input("Введите желаемое название для инжектора.", "Переименовывание", "")
			if(!t)
				return
			if(length(t) > 15)
				to_chat(user, "<span class = 'warning'>Название слишком длинное, и не помещается на инжекторе! Нужно другое.</span>")
			name = t
		if(istype(W, /obj/item/toy/crayon/spraycan))
			var/obj/item/toy/crayon/spraycan/C = W
			if(C.capped)
				to_chat(user, "<span class = 'warning'>Вам стоит снять крышку, прежде чем пытаться раскрасить [src]!</span>")
				return
			var/list/injector_icons = list("Completely Blue" = image(icon = src.icon, icon_state = "ablueinjector"),
											"Blue" = image(icon = src.icon, icon_state = "blueinjector"),
											"Completely Red" = image(icon = src.icon, icon_state = "redinjector"),
											"Red" = image(icon = src.icon, icon_state = "lepopen"),
											"Golden" = image(icon = src.icon, icon_state = "goldinjector"),
											"Completely Green" = image(icon = src.icon, icon_state = "greeninjector"),
											"Green" = image(icon = src.icon, icon_state = "autoinjector"),
											"Gray" = image(icon = src.icon, icon_state = "stimpen"))
			var/choice = show_radial_menu(user, src, injector_icons, custom_check = CALLBACK(src, PROC_REF(check_reskin), user))
			if(!choice || W.loc != user || src.loc != user)
				return
			if(C.uses <= 0)
				to_chat(user, "<span class = 'warning'>Не похоже что бы осталось достаточно краски.</span>")
				return
			icon_state = skinslist[choice]
			C.uses--
			update_icon()
	else
		return ..()

/obj/item/reagent_containers/hypospray/autoinjector/proc/check_reskin(mob/living/user)
	if(user.incapacitated())
		return
	if(loc != user)
		return
	return TRUE

/obj/item/reagent_containers/hypospray/autoinjector/empty()
	set hidden = TRUE

/obj/item/reagent_containers/hypospray/autoinjector/attack(mob/M, mob/user)
	if(!reagents.total_volume || spent)
		to_chat(user, "<span class='warning'>[src] is empty!</span>")
		return
	if(only_self && (M != user))
		to_chat(user, "<span class='warning'>Не похоже что вы сможете уколоть [src] кому-либо, кроме себя!</span>")
		return
	..()
	spent = TRUE
	update_icon(UPDATE_ICON_STATE)
	return TRUE


/obj/item/reagent_containers/hypospray/autoinjector/update_icon_state()
	var/real_state = replacetext(icon_state, "0", "")	// we need to do this since customization is available
	icon_state = "[real_state][spent ? "0" : ""]"


/obj/item/reagent_containers/hypospray/autoinjector/examine()
	. = ..()
	if(reagents && reagents.reagent_list.len)
		. += "<span class='notice'>It is currently loaded.</span>"
	else
		. += "<span class='notice'>It is spent.</span>"

/obj/item/reagent_containers/hypospray/autoinjector/attack(mob/living/M, mob/user)
	if(..())
		playsound(loc, 'sound/effects/stimpak.ogg', 35, 1)

/obj/item/reagent_containers/hypospray/autoinjector/teporone //basilisks
	name = "teporone autoinjector"
	desc = "A rapid way to regulate your body's temperature in the event of a hardsuit malfunction."
	icon_state = "lepopen"
	list_reagents = list("teporone" = 10)

/obj/item/reagent_containers/hypospray/autoinjector/stimpack //goliath kiting
	name = "stimpack autoinjector"
	desc = "A rapid way to stimulate your body's adrenaline, allowing for freer movement in restrictive armor."
	icon_state = "stimpen"
	volume = 20
	amount_per_transfer_from_this = 20
	list_reagents = list("methamphetamine" = 10, "coffee" = 10)

/obj/item/reagent_containers/hypospray/autoinjector/stimulants
	name = "Stimulants autoinjector"
	desc = "Rapidly stimulates and regenerates the body's organ system."
	icon_state = "stimpen"
	amount_per_transfer_from_this = 50
	volume = 50
	list_reagents = list("stimulants" = 50)

/obj/item/reagent_containers/hypospray/autoinjector/survival
	name = "survival medipen"
	desc = "A medipen for surviving in the harshest of environments, heals and protects from environmental hazards. <br><span class='boldwarning'>WARNING: Do not inject more than one pen in quick succession.</span>"
	icon_state = "stimpen"
	belt_icon = "survival_medipen"
	volume = 42
	amount_per_transfer_from_this = 42
	list_reagents = list("salbutamol" = 10, "teporone" = 15, "epinephrine" = 10, "lavaland_extract" = 2, "weak_omnizine" = 5) //Short burst of healing, followed by minor healing from the saline

/obj/item/reagent_containers/hypospray/autoinjector/nanocalcium
	name = "protoype nanite autoinjector"
	desc = "After a short period of time the nanites will slow the body's systems and assist with body repair. Nanomachines son."
	icon_state = "bonepen"
	amount_per_transfer_from_this = 30
	volume = 30
	list_reagents = list("nanocalcium" = 30)

/obj/item/reagent_containers/hypospray/autoinjector/nanocalcium/attack(mob/living/M, mob/user)
	if(..())
		playsound(loc, 'sound/weapons/smg_empty_alarm.ogg', 20, 1)

/obj/item/reagent_containers/hypospray/autoinjector/selfmade
	name = "autoinjector"
	desc = "Самодельное подобие инжектора. Не похоже что вы сможете уколоть кого-то ещё кроме себя используя его."
	volume = 15
	amount_per_transfer_from_this = 15
	list_reagents = list()
	only_self = TRUE
	reskin_allowed = TRUE
	container_type = OPENCONTAINER

/obj/item/reagent_containers/hypospray/autoinjector/selfmade/attack(mob/living/M, mob/user)
	..()
	container_type = DRAINABLE

/obj/item/reagent_containers/hypospray/autoinjector/salbutamol
	name = "Salbutamol autoinjector"
	desc = "A medipen used for basic oxygen damage treatment"
	icon_state = "ablueinjector"
	amount_per_transfer_from_this = 20
	volume = 20
	list_reagents = list("salbutamol" = 20)

/obj/item/reagent_containers/hypospray/autoinjector/charcoal
	name = "Charcoal autoinjector"
	desc = "A medipen used for basic toxin damage treatment"
	icon_state = "greeninjector"
	amount_per_transfer_from_this = 20
	volume = 20
	list_reagents = list("charcoal" = 20)
