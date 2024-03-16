#define TURF_FIND_TRIES 10

/datum/event/anomaly
	name = "Anomaly: Energetic Flux"
	var/obj/effect/anomaly/anomaly_path = /obj/effect/anomaly/flux
	var/turf/target_turf
	announceWhen = 1
	/// The prefix message for the anomaly annoucement.
	var/prefix_message = "На сканерах дальнего действия обнаружена гиперэнергетическая потоковая аномалия."


/datum/event/anomaly/setup()
	target_turf = find_targets(TRUE)

/datum/event/anomaly/proc/find_targets(warn_on_fail = FALSE)
	for(var/tries in 1 to TURF_FIND_TRIES)
		impact_area = findEventArea()
		if(!impact_area)
			if(warn_on_fail)
				stack_trace("No valid areas for anomaly found.")
				kill()
			return
		var/list/candidate_turfs = get_area_turfs(impact_area)
		while(length(candidate_turfs))
			var/turf/candidate = pick_n_take(candidate_turfs)
			if(!is_blocked_turf(candidate, TRUE))
				target_turf = candidate
				break
		if(target_turf)
			break
	if(!target_turf)
		stack_trace("Anomaly: Unable to find a valid turf to spawn the anomaly. Last area tried: [impact_area] - [impact_area.type]")
		kill()
		return

	return target_turf

/datum/event/anomaly/announce(false_alarm)
	var/area/target = false_alarm ? findEventArea() : impact_area
	if(false_alarm && !target)
		log_debug("Failed to find a valid area when trying to make a false alarm anomaly!")
		return
	GLOB.event_announcement.Announce("[prefix_message] Предполагаемая локация: [target.name]", "ВНИМАНИЕ: ОБНАРУЖЕНА АНОМАЛИЯ.")

/datum/event/anomaly/start()
	var/newAnomaly = new anomaly_path(target_turf)
	announce_to_ghosts(newAnomaly)

#undef TURF_FIND_TRIES
