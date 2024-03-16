GLOBAL_LIST_INIT(map_transition_config, MAP_TRANSITION_CONFIG)

#ifdef UNIT_TESTS
GLOBAL_DATUM(test_runner, /datum/test_runner)
#endif

/proc/enable_debugging(mode, port)
	CRASH("auxtools not loaded")

/world/New()
#ifdef USE_BYOND_TRACY
	#warn USE_BYOND_TRACY is enabled
	prof_init()
#endif

	dmjit_hook_main_init()
	// IMPORTANT
	// If you do any SQL operations inside this proc, they must ***NOT*** be ran async. Otherwise players can join mid query
	// This is BAD.

	//temporary file used to record errors with loading config and the database, moved to log directory once logging is set up
	GLOB.config_error_log = GLOB.world_game_log = GLOB.world_runtime_log = GLOB.sql_log = "data/logs/config_error.log"

	// Proc to enable the extools debugger, which allows breakpoints, live var checking, and many other useful tools
	// The DLL is injected into the env by visual studio code. If not running VSCode, the proc will not call the initialization
	var/debug_server = world.GetConfig("env", "AUXTOOLS_DEBUG_DLL")
	if(debug_server)
		CALL_EXT(debug_server, "auxtools_init")()
		enable_debugging()

	load_configuration()
	// Right off the bat, load up the DB
	SSdbcore.CheckSchemaVersion() // This doesnt just check the schema version, it also connects to the db! This needs to happen super early! I cannot stress this enough!
	SSdbcore.SetRoundID() // Set the round ID here

	// Setup all log paths and stamp them with startups, including round IDs
	SetupLogs()

	// This needs to happen early, otherwise people can get a null species, nuking their character
	makeDatumRefLists()

	TgsNew(new /datum/tgs_event_handler/impl, TGS_SECURITY_TRUSTED) // creates a new TGS object
	log_world("World loaded at [time_stamp()]")
	log_world("[GLOB.vars.len - GLOB.gvars_datum_in_built_vars.len] global variables")
	GLOB.revision_info.log_info()
	load_admins(run_async=FALSE) // This better happen early on.

	#ifdef UNIT_TESTS
	log_world("Unit Tests Are Enabled!")
	#endif


	if(byond_version < MIN_COMPILER_VERSION || byond_build < MIN_COMPILER_BUILD)
		log_world("Your server's byond version does not meet the recommended requirements for this code. Please update BYOND")

	if(config && CONFIG_GET(string/servername) != null && CONFIG_GET(number/server_suffix) && world.port > 0)
		// dumb and hardcoded but I don't care~
		CONFIG_SET(string/servername, CONFIG_GET(string/servername) + " #[(world.port % 1000) / 100]")

	GLOB.timezoneOffset = text2num(time2text(0, "hh")) * 36000

	startup_procs() // Call procs that need to occur on startup (Generate lists, load MOTD, etc)

	src.update_status()

	GLOB.space_manager.initialize() //Before the MC starts up

	. = ..()

	Master.Initialize(10, FALSE, TRUE)


	#ifdef UNIT_TESTS
	GLOB.test_runner = new
	GLOB.test_runner.Start()
	#endif

	return

// This is basically a replacement for hook/startup. Please dont shove random bullshit here
// If it doesnt need to happen IMMEDIATELY on world load, make a subsystem for it
/world/proc/startup_procs()
	LoadBans() // Load up who is banned and who isnt. DONT PUT THIS IN A SUBSYSTEM IT WILL TAKE TOO LONG TO BE CALLED
	jobban_loadbanfile() // Load up jobbans. Again, DO NOT PUT THIS IN A SUBSYSTEM IT WILL TAKE TOO LONG TO BE CALLED
	load_motd() // Loads up the MOTD (Welcome message players see when joining the server)
	load_mode() // Loads up the gamemode

/// List of all world topic spam prevention handlers. See code/modules/world_topic/_spam_prevention_handler.dm
GLOBAL_LIST_EMPTY(world_topic_spam_prevention_handlers)
/// List of all world topic handler datums. Populated inside makeDatumRefLists()
GLOBAL_LIST_EMPTY(world_topic_handlers)


/world/Topic(T, addr, master, key)
	TGS_TOPIC
	log_misc("WORLD/TOPIC: \"[T]\", from:[addr], master:[master], key:[key == CONFIG_GET(string/comms_password) ? "*secret*" : key]")

	// Handle spam prevention
	if(!(addr in CONFIG_GET(str_list/topic_filtering_whitelist)))
		if(!GLOB.world_topic_spam_prevention_handlers[addr])
			GLOB.world_topic_spam_prevention_handlers[addr] = new /datum/world_topic_spam_prevention_handler(addr)

		var/datum/world_topic_spam_prevention_handler/sph = GLOB.world_topic_spam_prevention_handlers[addr]

		// Lock the user out and cancel their topic if needed
		if(sph.check_lockout())
			return

	var/list/input = params2list(T)

	var/datum/world_topic_handler/wth

	for(var/H in GLOB.world_topic_handlers)
		if(H in input)
			wth = GLOB.world_topic_handlers[H]
			break

	if(!wth)
		return

	// If we are here, the handler exists, so it needs to be invoked
	wth = new wth()
	return wth.invoke(input)

/world/Reboot(reason, fast_track = FALSE)
	//special reboot, do none of the normal stuff
	if((reason == 1) || fast_track) // Do NOT change this to if(reason). You WILL break the entirety of world rebooting
		if(usr)
			if(!check_rights(R_SERVER))
				log_and_message_admins("attempted to restart the server via the Profiler, without access.")
				return
			log_and_message_admins("has requested an immediate world restart via client side debugging tools")
			to_chat(world, "<span class='boldannounce'>Rebooting world immediately due to host request</span>")
		rustg_log_close_all() // Past this point, no logging procs can be used, at risk of data loss.
		// Now handle a reboot
		if(config && CONFIG_GET(flag/shutdown_on_reboot))
			sleep(0)
			if(GLOB.shutdown_shell_command)
				shell(GLOB.shutdown_shell_command)
			del(world)
			TgsEndProcess() // We want to shutdown on reboot. That means kill our TGS process "gracefully", instead of the watchdog crying
			return
		else
			TgsReboot() // Tell TGS we did a reboot
			return ..(1)

	// If we got here, we are in a "normal" reboot
	Master.Shutdown() // Shutdown subsystems

	// If we were running unit tests, finish that run
	#ifdef UNIT_TESTS
	GLOB.test_runner.Finalize()
	return
	#endif

	// If we had an update or pending TM, set a 60 second timeout
	var/secs_before_auto_reconnect = 10
	if(GLOB.pending_server_update)
		secs_before_auto_reconnect = 60
		to_chat(world, "<span class='boldannounce'>Reboot will take a little longer, due to pending updates.</span>")

	// Send the reboot banner to all players
	for(var/client/C in GLOB.clients)
		C << output(list2params(list(secs_before_auto_reconnect)), "browseroutput:reboot")
		if(CONFIG_GET(string/server)) // If you set a server location in config.txt, it sends you there instead of trying to reconnect to the same world address. -- NeoFite
			C << link("byond://[CONFIG_GET(string/server)]")

	// And begin the real shutdown
	rustg_log_close_all() // Past this point, no logging procs can be used, at risk of data loss.
	if(config && CONFIG_GET(flag/shutdown_on_reboot))
		sleep(0)
		if(GLOB.shutdown_shell_command)
			shell(GLOB.shutdown_shell_command)
		rustg_log_close_all() // Past this point, no logging procs can be used, at risk of data loss.
		del(world)
		TgsEndProcess() // We want to shutdown on reboot. That means kill our TGS process "gracefully", instead of the watchdog crying
		return
	else
		TgsReboot() // We did a normal reboot. Tell TGS we did a normal reboot.
		..(0)

/world/proc/load_mode()
	var/list/Lines = file2list("data/mode.txt")
	if(Lines.len)
		if(Lines[1])
			GLOB.master_mode = Lines[1]
			add_game_logs("Saved mode is '[GLOB.master_mode]'")

/world/proc/save_mode(var/the_mode)
	var/F = file("data/mode.txt")
	fdel(F)
	F << the_mode

/world/proc/check_for_lowpop()
	if(!CONFIG_GET(number/auto_extended_players_num))
		return

	var/totalPlayersReady = 0
	for(var/mob/new_player/player in GLOB.player_list)
		if(player.ready)
			totalPlayersReady++

	if(totalPlayersReady <= CONFIG_GET(number/auto_extended_players_num))
		GLOB.master_mode = "extended"
		to_chat(world, "<span class='boldnotice'>Due to the lowpop the mode has been changed.</span>")
	to_chat(world, "<span class='boldnotice'>The mode is now: [GLOB.master_mode]</span>")

/world/proc/load_motd()
	GLOB.join_motd = file2text("config/motd.txt")
	GLOB.join_tos = file2text("config/tos.txt")

/proc/load_configuration()
	config = new /datum/controller/configuration()
	config.Load()
	// apply some settings from config..

/world/proc/update_status()
	status = get_status_text()

/proc/get_world_status_text()
	return world.get_status_text()

/world/proc/get_status_text()
	var/s = ""

	if(config && CONFIG_GET(string/servername))
		s += "<b>[CONFIG_GET(string/servername)]</b> &#8212; "
	s += "<b>[station_name()]</b> "
	if(config && CONFIG_GET(string/githuburl))
		s+= "([GLOB.game_version])"

	if(config && CONFIG_GET(string/server_tag_line))
		s += "<br>[CONFIG_GET(string/server_tag_line)]"

	if(SSticker && ROUND_TIME > 0)
		s += "<br>[ROUND_TIME_TEXT()], " + capitalize(get_security_level())
	else
		s += "<br><b>STARTING</b>"

	s += "<br>"
	var/list/features = list()

	if(!GLOB.enter_allowed)
		features += "closed"

	if(config && CONFIG_GET(string/server_extra_features))
		features += CONFIG_GET(string/server_extra_features)

	if(config && CONFIG_GET(flag/allow_vote_mode))
		features += "vote"

	if(config && CONFIG_GET(string/wikiurl))
		features += "<a href=\"[CONFIG_GET(string/wikiurl)]\">Wiki</a>"

	if(GLOB.abandon_allowed)
		features += "respawn"

	if(features)
		s += "[jointext(features, ", ")]"

	return s

/world/proc/SetupLogs()
	if(GLOB.round_id && !CONFIG_GET(flag/full_day_logs))
		GLOB.log_directory = "data/logs/[time2text(world.realtime, "YYYY/MM-Month/DD-Day")]/round-[GLOB.round_id]"
	else
		GLOB.log_directory = "data/logs/[time2text(world.realtime, "YYYY/MM-Month/DD-Day")]" // Dont stick a round ID if we dont have one
	GLOB.world_game_log = "[GLOB.log_directory]/game.log"
	GLOB.world_href_log = "[GLOB.log_directory]/hrefs.log"
	GLOB.world_runtime_log = "[GLOB.log_directory]/runtime.log"
	GLOB.world_qdel_log = "[GLOB.log_directory]/qdel.log"
	GLOB.world_asset_log = "[GLOB.log_directory]/asset.log"
	GLOB.tgui_log = "[GLOB.log_directory]/tgui.log"
	GLOB.http_log = "[GLOB.log_directory]/http.log"
	GLOB.sql_log = "[GLOB.log_directory]/sql.log"
	start_log(GLOB.world_game_log)
	start_log(GLOB.world_href_log)
	start_log(GLOB.world_runtime_log)
	start_log(GLOB.world_qdel_log)
	start_log(GLOB.tgui_log)
	start_log(GLOB.http_log)
	start_log(GLOB.sql_log)

	// This log follows a special format and this path should NOT be used for anything else
	GLOB.runtime_summary_log = "data/logs/runtime_summary.log"
	if(fexists(GLOB.runtime_summary_log))
		fdel(GLOB.runtime_summary_log)
	start_log(GLOB.runtime_summary_log)
	// And back to sanity

	if(fexists(GLOB.config_error_log))
		fcopy(GLOB.config_error_log, "[GLOB.log_directory]/config_error.log")
		fdel(GLOB.config_error_log)

	// Save the current round's log path to a text file for other scripts to use.
	var/F = file("data/logpath.txt")
	fdel(F)
	F << GLOB.log_directory

	var/latest_changelog = file("html/changelogs/archive/" + time2text(world.timeofday, "YYYY-MM") + ".yml")
	GLOB.changelog_hash = fexists(latest_changelog) ? md5(latest_changelog) : 0 //for telling if the changelog has changed recently


/world/Del()
	rustg_close_async_http_client() // Close the HTTP client. If you dont do this, youll get phantom threads which can crash DD from memory access violations
	var/debug_server = world.GetConfig("env", "AUXTOOLS_DEBUG_DLL")
	if (debug_server)
		CALL_EXT(debug_server, "auxtools_shutdown")()
	prof_stop()
	..()
