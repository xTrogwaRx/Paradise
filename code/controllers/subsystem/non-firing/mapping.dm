SUBSYSTEM_DEF(mapping)
	name = "Mapping"
	init_order = INIT_ORDER_MAPPING // 7
	flags = SS_NO_FIRE
	ss_id = "mapping"
	/// What map datum are we using
	var/datum/map/map_datum
	/// What map will be used next round
	var/datum/map/next_map
	/// Waht map to fallback
	var/datum/map/fallback_map = new /datum/map/delta
	///What do we have as the lavaland theme today?
	var/datum/lavaland_theme/lavaland_theme
	///What primary cave theme we have picked for cave generation today.
	var/cave_theme
	///List of areas that exist on the station this shift
	var/list/existing_station_areas


// This has to be here because world/New() uses [station_name()], which looks this datum up
/datum/controller/subsystem/mapping/PreInit()
	. = ..()
	if(map_datum) // Dont do this again if we are recovering
		return
	if(fexists("data/next_map.txt"))
		var/list/lines = file2list("data/next_map.txt")
		// Check its valid
		try
			map_datum = text2path(lines[1])
			map_datum = new map_datum
		catch
			map_datum = fallback_map // Assume delta if non-existent
		fdel("data/next_map.txt") // Remove to avoid the same map existing forever
		return
	map_datum = fallback_map // Assume delta if non-existent

/datum/controller/subsystem/mapping/Shutdown()
	if(next_map) // Save map for next round
		var/F = file("data/next_map.txt")
		F << next_map.type

/datum/controller/subsystem/mapping/Initialize()
	var/datum/lavaland_theme/lavaland_theme_type = pick(subtypesof(/datum/lavaland_theme))
	ASSERT(lavaland_theme_type)
	lavaland_theme = new lavaland_theme_type
	log_startup_progress("We're in the mood for [initial(lavaland_theme.name)] today...") //We load this first. In the event some nerd ever makes a surface map, and we don't have it in lavaland in the event lavaland is disabled.
	cave_theme = pick(BLOCKED_BURROWS, CLASSIC_CAVES, DEADLY_DEEPROCK)
	log_startup_progress("We feel like [cave_theme] today...")
	// Load all Z level templates
	preloadTemplates()
	// Load the station
	loadStation()

	if(!CONFIG_GET(flag/disable_lavaland))
		loadLavaland()
	if(!CONFIG_GET(flag/disable_taipan))
		loadTaipan()
	// Pick a random away mission.
	if(!CONFIG_GET(flag/disable_away_missions))
		createRandomZlevel()
	// Seed space ruins
	if(!CONFIG_GET(flag/disable_space_ruins))
		handleRuins()

	// Makes a blank space level for the sake of randomness
	GLOB.space_manager.add_new_zlevel("Empty Area", linkage = CROSSLINKED, traits = list(REACHABLE))


	// Setup the Z-level linkage
	GLOB.space_manager.do_transition_setup()

	if(!CONFIG_GET(flag/disable_lavaland))
		// Spawn Lavaland ruins and rivers.
		log_startup_progress("Populating lavaland...")
		var/lavaland_setup_timer = start_watch()
		seedRuins(list(level_name_to_num(MINING)), CONFIG_GET(number/lavaland_budget), /area/lavaland/surface/outdoors/unexplored, GLOB.lava_ruins_templates)
		if(lavaland_theme)
			lavaland_theme.setup()
		var/time_spent = stop_watch(lavaland_setup_timer)
		log_startup_progress("Successfully populated lavaland in [time_spent]s.")
		if(time_spent >= 10)
			log_startup_progress("!!!ERROR!!! Lavaland took FAR too long to generate at [time_spent] seconds. Notify maintainers immediately! !!!ERROR!!!") //In 3 testing cases so far, I have had it take far too long to generate. I am 99% sure I have fixed this issue, but never hurts to be sure
			WARNING("!!!ERROR!!! Lavaland took FAR too long to generate at [time_spent] seconds. Notify maintainers immediately! !!!ERROR!!!")
			var/loud_annoying_alarm = sound('sound/machines/engine_alert1.ogg')
			for(var/get_player_attention in GLOB.player_list)
				SEND_SOUND(get_player_attention, loud_annoying_alarm)
	else
		log_startup_progress("Skipping lavaland ruins...")

	// Now we make a list of areas for teleport locs
	// TOOD: Make these locs into lists on the SS itself, not globs

	var/list/all_areas = list()
	for(var/area/areas in world)
		all_areas += areas

	for(var/area/AR as anything in all_areas)
		if(AR.no_teleportlocs)
			continue
		if(GLOB.teleportlocs[AR.name])
			continue
		var/list/pickable_turfs = list()
		for(var/turf/turfs in AR)
			pickable_turfs += turfs
			break
		var/turf/picked = safepick(pickable_turfs)
		if(picked && is_station_level(picked.z))
			GLOB.teleportlocs[AR.name] = AR

	GLOB.teleportlocs = sortAssoc(GLOB.teleportlocs)

	for(var/area/AR as anything in all_areas)
		if(GLOB.ghostteleportlocs[AR.name])
			continue
		var/list/pickable_turfs = list()
		for(var/turf/turfs in AR)
			pickable_turfs += turfs
			break
		if(length(pickable_turfs))
			GLOB.ghostteleportlocs[AR.name] = AR

	GLOB.ghostteleportlocs = sortAssoc(GLOB.ghostteleportlocs)

	// Now we make a list of areas that exist on the station. Good for if you don't want to select areas that exist for one station but not others. Directly references
	existing_station_areas = list()
	for(var/area/AR as anything in all_areas)
		var/list/pickable_turfs = list()
		for(var/turf/turfs in AR)
			pickable_turfs += turfs
			break
		var/turf/picked = safepick(pickable_turfs)
		if(picked && is_station_level(picked.z))
			existing_station_areas += AR

	// World name
	if(config && CONFIG_GET(string/servername))
		world.name = "[CONFIG_GET(string/servername)] — [station_name()]"
	else
		world.name = station_name()


// Do not confuse with seedRuins()
/datum/controller/subsystem/mapping/proc/handleRuins()
	// load in extra levels of space ruins
	var/load_zlevels_timer = start_watch()
	log_startup_progress("Creating random space levels...")
	var/num_extra_space = rand(CONFIG_GET(number/extra_space_ruin_levels_min), CONFIG_GET(number/extra_space_ruin_levels_max))
	for(var/i in 1 to num_extra_space)
		GLOB.space_manager.add_new_zlevel("Ruin Area #[i]", linkage = CROSSLINKED, traits = list(REACHABLE, SPAWN_RUINS))
	log_startup_progress("Loaded random space levels in [stop_watch(load_zlevels_timer)]s.")

	// Now spawn ruins, random budget between 20 and 30 for all zlevels combined.
	// While this may seem like a high number, the amount of ruin Z levels can be anywhere between 3 and 7.
	// Note that this budget is not split evenly accross all zlevels
	log_startup_progress("Seeding ruins...")
	var/seed_ruins_timer = start_watch()
	seedRuins(levels_by_trait(SPAWN_RUINS), rand(20, 30), /area/space, GLOB.space_ruins_templates)
	log_startup_progress("Successfully seeded ruins in [stop_watch(seed_ruins_timer)]s.")


/datum/controller/subsystem/mapping/proc/loadStation()
	if(CONFIG_GET(string/default_map) && !CONFIG_GET(string/override_map) && map_datum == fallback_map)
		var/map_datum_path = text2path(CONFIG_GET(string/default_map))
		if(map_datum_path)
			map_datum = new map_datum_path

	if(CONFIG_GET(string/override_map))
		log_startup_progress("Station map overridden by configuration to [CONFIG_GET(string/override_map)].")
		var/map_datum_path = text2path(CONFIG_GET(string/override_map))
		if(map_datum_path)
			map_datum = new map_datum_path
		else
			to_chat(world, "<span class='narsie'>ERROR: The map datum specified to load is invalid. Falling back to... delta probably?</span>")

	ASSERT(map_datum.map_path)
	if(!fexists(map_datum.map_path))
		// Make a VERY OBVIOUS error
		to_chat(world, "<span class='narsie'>ERROR: The path specified for the map to load is invalid. No station has been loaded!</span>")
		return

	var/watch = start_watch()
	log_startup_progress("Loading [map_datum.station_name]...")
	// This should always be Z3, but you never know
	var/map_z_level = GLOB.space_manager.add_new_zlevel(MAIN_STATION, linkage = CROSSLINKED, traits = list(STATION_LEVEL, STATION_CONTACT, REACHABLE, AI_OK))
	GLOB.maploader.load_map(wrap_file(map_datum.map_path), z_offset = map_z_level)
	log_startup_progress("Loaded [map_datum.station_name] in [stop_watch(watch)]s")

	// Save station name in the DB
	if(!SSdbcore.IsConnected())
		return
	var/datum/db_query/query_set_map = SSdbcore.NewQuery(
		"UPDATE [format_table_name("round")] SET start_datetime=NOW(), map_name=:mapname, station_name=:stationname WHERE id=:round_id",
		list("mapname" = map_datum.name, "stationname" = map_datum.station_name, "round_id" = GLOB.round_id)
	)
	query_set_map.Execute(async = FALSE) // This happens during a time of intense server lag, so should be non-async
	qdel(query_set_map)

/datum/controller/subsystem/mapping/proc/loadLavaland()
	var/watch = start_watch()
	log_startup_progress("Loading Lavaland...")
	var/lavaland_z_level = GLOB.space_manager.add_new_zlevel(MINING, linkage = SELFLOOPING, traits = list(ORE_LEVEL, REACHABLE, STATION_CONTACT, HAS_WEATHER, AI_OK))
	GLOB.maploader.load_map(file(map_datum.lavaland_path), z_offset = lavaland_z_level)
	log_startup_progress("Loaded Lavaland in [stop_watch(watch)]s")


/datum/controller/subsystem/mapping/proc/loadTaipan()
	var/watch = start_watch()
	log_startup_progress("Loading Taipan...")
	var/taipan_z_level = GLOB.space_manager.add_new_zlevel(RAMSS_TAIPAN, linkage = CROSSLINKED, traits = list(REACHABLE, TAIPAN))
	GLOB.maploader.load_map(file("_maps/map_files/generic/syndicatebase.dmm"), z_offset = taipan_z_level)
	log_startup_progress("Loaded Taipan in [stop_watch(watch)]s")

/datum/controller/subsystem/mapping/proc/seedRuins(list/z_levels = null, budget = 0, whitelist = /area/space, list/potentialRuins)
	if(!z_levels || !z_levels.len)
		WARNING("No Z levels provided - Not generating ruins")
		return

	for(var/zl in z_levels)
		var/turf/T = locate(1, 1, zl)
		if(!T)
			WARNING("Z level [zl] does not exist - Not generating ruins")
			return

	var/list/ruins = potentialRuins.Copy()

	var/list/forced_ruins = list()		//These go first on the z level associated (same random one by default)
	var/list/big_ruins = list()	// Large ruins that require a separate z level
	var/list/ruins_availible = list()	//we can try these in the current pass
	var/list/picked_ruins = list()

	//Set up the starting ruin list
	for(var/key in ruins)
		var/datum/map_template/ruin/R = ruins[key]
		if(R.cost > budget) //Why would you do that
			continue
		if(R.height >= MAX_RUIN_SIZE_VALUE || R.width >= MAX_RUIN_SIZE_VALUE)
			big_ruins[R] = -1
		if(R.always_place)
			forced_ruins[R] = -1
		if(R.unpickable)
			continue
		ruins_availible[R] = R.placement_weight

	while(budget > 0 && (length(ruins_availible) || length(forced_ruins)))
		var/datum/map_template/ruin/current_pick

		if(length(forced_ruins)) //We have something we need to load right now, so just pick it
			for(var/ruin in forced_ruins)
				current_pick = ruin
				forced_ruins -= ruin
				break
		else //Otherwise just pick random one
			current_pick = pickweight(ruins_availible)

		budget -= current_pick.cost
		if(!current_pick.allow_duplicates)
			for(var/datum/map_template/ruin/R as anything in ruins_availible)
				if(R.id == current_pick.id)
					ruins_availible -= R

		if(current_pick.never_spawn_with)
			for(var/blacklisted_type in current_pick.never_spawn_with)
				for(var/possible_exclusion in ruins_availible)
					if(istype(possible_exclusion,blacklisted_type))
						ruins_availible -= possible_exclusion

		//Update the availible list
		for(var/datum/map_template/ruin/R as anything in ruins_availible)
			if(R.cost > budget)
				ruins_availible -= R

		if(current_pick in big_ruins)
			picked_ruins.Insert(1, current_pick)
		else
			picked_ruins.Add(current_pick)

	for(var/datum/map_template/ruin/current_pick as anything in picked_ruins)
		var/failed_to_place = TRUE
		var/z_placed = 0

		if(current_pick in big_ruins)
			z_placed = pick(z_levels)
			if(current_pick.try_to_place(z_placed, whitelist))
				failed_to_place = FALSE
				z_levels -= z_placed //If there is a big ruin, there is no place for small ones here.
		else
			var/placement_tries = PLACEMENT_TRIES
			while(placement_tries > 0)
				placement_tries--
				z_placed = pick(z_levels)
				if(!current_pick.try_to_place(z_placed, whitelist))
					continue
				else
					failed_to_place = FALSE
					break

		if(failed_to_place)
			log_world("Failed to place [current_pick.name] ruin.")

	log_world("Ruin loader finished with [budget] left to spend.")

/datum/controller/subsystem/mapping/Recover()
	flags |= SS_NO_INIT
