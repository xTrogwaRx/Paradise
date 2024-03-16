/// Returns the src and all recursive contents as a list.
/atom/proc/get_all_contents()
	. = list(src)
	var/idx = 0
	while(idx < length(.))
		var/atom/checked_atom = .[++idx]
		if(checked_atom.flags)
			continue
		. += checked_atom.contents

/// Same as get_all_contents(), but returns a list of atoms of the passed type
/atom/proc/get_all_contents_type(type)
	var/list/processing_list = list(src)
	. = list()
	while(length(processing_list))
		var/atom/checked_atom = processing_list[1]
		processing_list.Cut(1, 2)
		processing_list += checked_atom.contents
		if(istype(checked_atom, type))
			. += checked_atom

/// Forces atom to drop all the important items while dereferencing them from their
/// containers both ways. To be used to preserve important items before mob gib/self-gib.
/// Returns a list with all saved items.
/atom/proc/drop_ungibbable_items(atom/new_loc)
	. = list()
	var/atom/drop_loc = new_loc ? new_loc : drop_location()

	for(var/atom/movable/I in contents)
		if(!is_type_in_list(I, GLOB.ungibbable_items_types))
			if(length(I.contents))
				I.drop_ungibbable_items(new_loc)
			continue

		. += I

		if(isturf(I.loc))
			continue

		var/obj/item/storage/holder_storage = I.loc
		if(istype(holder_storage))
			holder_storage.remove_from_storage(I, drop_loc)
			continue

		var/mob/holder_mob = I.loc
		if(istype(holder_mob))
			holder_mob.temporarily_remove_item_from_inventory(I, force = TRUE, silent = TRUE)
			I.forceMove(drop_loc)
			continue

		for(var/var_name in vars)
			// Item may be referenced in some properties of container.
			// E.g. holsters.
			if(vars[var_name] == I)
				vars[var_name] = null
			// Item may be referenced in some list properties of container.
			// E.g. medals.
			else if(islist(vars[var_name]) && (I in vars[var_name]))
				vars[var_name] -= I

		for(var/var_name in I.vars)
			// Item may reference container in some properties.
			// E.g. medals.
			if(I.vars[var_name] == src)
				I.vars[var_name] = null

		I.forceMove(drop_loc)


/**
 * Proc that collects all atoms of passed `path` in our atom contents
 * and returns it in a list()
 */
/atom/proc/collect_all_atoms_of_type(path, list/blacklist)
	var/list/atoms = list()
	if(src in blacklist)
		return atoms
	for(var/atom/check in contents)
		if(check in blacklist)
			continue
		if(istype(check, path))
			atoms |= check
		if(length(check.contents))
			atoms |= check.collect_all_atoms_of_type(path, blacklist)
	return atoms
/**
 * 	Proc that returns if selected loc, or atom is within boundaries of playable area. (non-transitional space)
 */
/proc/is_location_within_transition_boundaries(atom/loc)
	return (loc.x > TRANSITION_BORDER_WEST) \
	&& (loc.x < TRANSITION_BORDER_EAST) \
	&& (loc.y > TRANSITION_BORDER_SOUTH) \
	&& (loc.y < TRANSITION_BORDER_NORTH)


/// Returns an x and y value require to reverse the transformations made to center an oversized icon
/atom/proc/get_oversized_icon_offsets()
	if (pixel_x == 0 && pixel_y == 0)
		return list("x" = 0, "y" = 0)
	var/list/icon_dimensions = get_icon_dimensions(icon)
	var/icon_width = icon_dimensions["width"]
	var/icon_height = icon_dimensions["height"]
	return list(
		"x" = icon_width > world.icon_size && pixel_x != 0 ? (icon_width - world.icon_size) * 0.5 : 0,
		"y" = icon_height > world.icon_size && pixel_y != 0 ? (icon_height - world.icon_size) * 0.5 : 0,
	)

