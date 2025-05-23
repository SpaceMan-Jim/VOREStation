/mob/living/carbon/human/proc/update_eyes()
	var/obj/item/organ/internal/eyes/eyes = internal_organs_by_name[O_EYES]
	if(eyes)
		eyes.update_colour()
		update_icons_body() //Body handles eyes
		update_eyes() //For floating eyes only

/mob/living/carbon/human/proc/recheck_bad_external_organs()
	var/damage_this_tick = getToxLoss()
	for(var/obj/item/organ/external/O in organs)
		damage_this_tick += O.burn_dam + O.brute_dam
		if(O.germ_level)
			damage_this_tick += 1 //Just tap it if we have germs so we can process those

	if(damage_this_tick > last_dam)
		. = TRUE
	last_dam = damage_this_tick

// Takes care of organ related updates, such as broken and missing limbs
/mob/living/carbon/human/proc/handle_organs()

	var/force_process = recheck_bad_external_organs()

	if(force_process)
		bad_external_organs.Cut()
		for(var/obj/item/organ/external/Ex in organs)
			bad_external_organs += Ex //VOREStation Edit - Silly and slow to |= this

	//processing internal organs is pretty cheap, do that first.
	for(var/obj/item/organ/I in internal_organs)
		I.process()

	handle_stance()
	handle_grasp()

	if(!force_process && !bad_external_organs.len)
		return

	number_wounds = 0
	for(var/obj/item/organ/external/E in bad_external_organs)
		if(!E)
			continue
		if(!E.need_process())
			bad_external_organs -= E
			continue
		else
			E.process()
			number_wounds += E.number_wounds

			if (!lying && !buckled && world.time - l_move_time < 15)
			//Moving around with fractured ribs won't do you any good
				if (prob(10) && !stat && can_feel_pain() && chem_effects[CE_PAINKILLER] < 50 && E.is_broken() && E.internal_organs.len)
					custom_pain("Pain jolts through your broken [E.encased ? E.encased : E.name], staggering you!", 50)
					emote("scream")
					drop_item(loc)
					Stun(2)

				//Moving makes open wounds get infected much faster
				if (E.wounds.len)
					for(var/datum/wound/W in E.wounds)
						if (W.infection_check())
							W.germ_level += 1

/mob/living/carbon/human/proc/handle_stance()
	// Don't need to process any of this if they aren't standing anyways
	// unless their stance is damaged, and we want to check if they should stay down
	if (!stance_damage && (lying || resting) && (life_tick % 4) != 0)
		return

	stance_damage = 0

	// Buckled to a bed/chair. Stance damage is forced to 0 since they're sitting on something solid
	if (istype(buckled, /obj/structure/bed))
		return

	var/limb_pain = FALSE
	for(var/limb_tag in list(BP_L_LEG,BP_R_LEG,BP_L_FOOT,BP_R_FOOT))
		var/obj/item/organ/external/E = organs_by_name[limb_tag]
		if(!E || !E.is_usable())
			stance_damage += 2 // let it fail even if just foot&leg
		else if (E.is_malfunctioning() && !(lying || resting))
			//malfunctioning only happens intermittently so treat it as a missing limb when it procs
			stance_damage += 2
			if(isturf(loc) && prob(10))
				visible_message("\The [src]'s [E.name] [pick("twitches", "shudders")] and sparks!")
				var/datum/effect/effect/system/spark_spread/spark_system = new ()
				spark_system.set_up(5, 0, src)
				spark_system.attach(src)
				spark_system.start()
				spawn(10)
					qdel(spark_system)
		else if (E.is_broken())
			stance_damage += 1
		else if (E.is_dislocated())
			stance_damage += 0.5

		if(E && (!E.is_usable() || E.is_broken() || E.is_dislocated()))
			limb_pain = E.organ_can_feel_pain()

	// Canes and crutches help you stand (if the latter is ever added)
	// One cane mitigates a broken leg+foot, or a missing foot.
	// Two canes are needed for a lost leg. If you are missing both legs, canes aren't gonna help you.
	if (l_hand && istype(l_hand, /obj/item/cane))
		stance_damage -= 2
	if (r_hand && istype(r_hand, /obj/item/cane))
		stance_damage -= 2

	// standing is poor
	if(stance_damage >= 4 || (stance_damage >= 2 && prob(5)))
		if(!(lying || resting) && !isbelly(loc))
			if(limb_pain)
				emote("scream")
			automatic_custom_emote(VISIBLE_MESSAGE, "collapses!", check_stat = TRUE)
		if(!(lying || resting)) // stops permastun with SPINE sdisability
			Weaken(5) //can't emote while weakened, apparently.

/mob/living/carbon/human/proc/handle_grasp()
	if(!l_hand && !r_hand)
		return

	// You should not be able to pick anything up, but stranger things have happened.
	if(l_hand)
		for(var/limb_tag in list(BP_L_HAND, BP_L_ARM))
			var/obj/item/organ/external/E = get_organ(limb_tag)
			if(!E)
				visible_message(span_danger("Lacking a functioning left hand, \the [src] drops \the [l_hand]."))
				drop_from_inventory(l_hand)
				break

	if(r_hand)
		for(var/limb_tag in list(BP_R_HAND, BP_R_ARM))
			var/obj/item/organ/external/E = get_organ(limb_tag)
			if(!E)
				visible_message(span_danger("Lacking a functioning right hand, \the [src] drops \the [r_hand]."))
				drop_from_inventory(r_hand)
				break

	// Check again...
	if(!l_hand && !r_hand)
		return
	for (var/obj/item/organ/external/E in organs)
		if(!E || !E.can_grasp)
			continue

		if((E.is_broken() || E.is_dislocated()) && !E.splinted)
			switch(E.body_part)
				if(HAND_LEFT, ARM_LEFT)
					if(!l_hand)
						continue
					drop_from_inventory(l_hand)
				if(HAND_RIGHT, ARM_RIGHT)
					if(!r_hand)
						continue
					drop_from_inventory(r_hand)

			if(!isbelly(loc))
				var/emote_scream = pick("screams in pain and ", "lets out a sharp cry and ", "cries out and ")
				automatic_custom_emote(VISIBLE_MESSAGE, "[(can_feel_pain()) ? "" : emote_scream ]drops what they were holding in their [E.name]!", check_stat = TRUE)
				if(can_feel_pain())
					emote("pain")

		else if(E.is_malfunctioning())
			switch(E.body_part)
				if(HAND_LEFT, ARM_LEFT)
					if(!l_hand)
						continue
					drop_from_inventory(l_hand)
				if(HAND_RIGHT, ARM_RIGHT)
					if(!r_hand)
						continue
					drop_from_inventory(r_hand)

			if(!isbelly(loc))
				automatic_custom_emote(VISIBLE_MESSAGE, "drops what they were holding, their [E.name] malfunctioning!", check_stat = TRUE)

				var/datum/effect/effect/system/spark_spread/spark_system = new /datum/effect/effect/system/spark_spread()
				spark_system.set_up(5, 0, src)
				spark_system.attach(src)
				spark_system.start()
				spawn(10)
					qdel(spark_system)

//Handles chem traces
/mob/living/carbon/human/proc/handle_trace_chems()
	//New are added for reagents to random organs.
	for(var/datum/reagent/A in reagents.reagent_list)
		var/obj/item/organ/O = pick(organs)
		O.trace_chemicals[A.name] = 100

// Traitgenes Init genes based on the traits currently active
/mob/living/carbon/human/proc/sync_dna_traits(var/refresh_traits, var/hide_message = TRUE)
	SHOULD_NOT_OVERRIDE(TRUE) //Don't. Even. /Think/. About. It.
	if(!dna || !species)
		return
	// Traitgenes NO_DNA and Synthetics cannot be mutated
	if(isSynthetic())
		return
	if(species.flags & NO_DNA)
		return
	if(refresh_traits && species.traits)
		for(var/TR in species.traits)
			var/datum/trait/T = GLOB.all_traits[TR]
			if(!T)
				continue
			if(!T.linked_gene)
				continue
			var/datum/gene/trait/gene = T.linked_gene
			dna.SetSEState(gene.block, TRUE, TRUE)
			// testing("[gene.name] Setup activated!")
		dna.UpdateSE()
	var/flgs = MUTCHK_FORCED
	if(hide_message)
		flgs |= MUTCHK_HIDEMSG
	domutcheck( src, null, flgs)

/mob/living/carbon/human/proc/sync_organ_dna()
	var/list/all_bits = internal_organs|organs
	for(var/obj/item/organ/O in all_bits)
		O.set_dna(dna)

/mob/living/carbon/human/proc/set_gender(var/g)
	if(g != gender)
		gender = g

	if(dna.GetUIState(DNA_UI_GENDER) ^ gender == FEMALE) // XOR will catch both cases where they do not match
		dna.SetUIState(DNA_UI_GENDER, gender == FEMALE)
		sync_organ_dna(dna)
