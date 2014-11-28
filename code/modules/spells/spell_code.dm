var/list/spells = typesof(/atom/movable/spell) //needed for the badmin verb for now

/atom/movable/spell
	name = "Spell"
	desc = "A spell"
	var/panel = "Spells"//What panel the proc holder needs to go on.

	var/school = "evocation" //not relevant at now, but may be important later if there are changes to how spells work. the ones I used for now will probably be changed... maybe spell presets? lacking flexibility but with some other benefit?

	var/charge_type = "recharge" //can be recharge or charges, see charge_max and charge_counter descriptions; can also be based on the holder's vars now, use "holder_var" for that

	var/charge_max = 100 //recharge time in deciseconds if charge_type = "recharge" or starting charges if charge_type = "charges"
	var/charge_counter = 0 //can only cast spells if it equals recharge, ++ each decisecond if charge_type = "recharge" or -- each cast if charge_type = "charges"
	var/still_recharging_msg = "<span class='notice'>The spell is still recharging.</span>"

	var/holder_var_type = "bruteloss" //only used if charge_type equals to "holder_var"
	var/holder_var_amount = 20 //same. The amount adjusted with the mob's var when the spell is used

	var/spell_flags = NEEDSCLOTHES
	var/invocation = "HURP DURP"	//what is uttered when the wizard casts the spell
	var/invocation_type = "none"	//can be none, whisper, shout, and emote
	var/range = 7					//the range of the spell; outer radius for aoe spells
	var/message = ""				//whatever it says to the guy affected by it
	var/selection_type = "view"		//can be "range" or "view"
	var/atom/movable/holder			//where the spell is. Normally the user, can be a projectile

	var/duration = 0 //how long the spell lasts

	var/list/spell_levels = list("speed" = 0, "power" = 0) //the current spell levels - total spell levels can be obtained by just adding the two values
	var/list/level_max = list("total" = 4, "speed" = 4, "power" = 0) //maximum possible levels in each category. Total does cover both.
	var/cooldown_reduc = 0		//If set, defines how much charge_max drops by every speed upgrade
	var/delay_reduc = 0
	var/cooldown_min = 0 //minimum possible cooldown for a charging spell

	var/overlay = 0
	var/overlay_icon = 'icons/obj/wizard.dmi'
	var/overlay_icon_state = "spell"
	var/overlay_lifespan = 0

	var/sparks_spread = 0
	var/sparks_amt = 0 //cropped at 10
	var/smoke_spread = 0 //1 - harmless, 2 - harmful
	var/smoke_amt = 0 //cropped at 10

	var/critfailchance = 0
	var/centcomm_cancast = 1 //Whether or not the spell should be allowed on z2

	var/cast_delay = 1
	var/cast_sound = ""

///////////////////////
///SETUP AND PROCESS///
///////////////////////

/atom/movable/spell/New()
	..()

	//still_recharging_msg = "<span class='notice'>[name] is still recharging.</span>"
	charge_counter = charge_max
	if(charge_type == "recharge")
		processing_objects.Add(src)


/atom/movable/spell/proc/process()
	if(charge_type != "recharge")
		processing_objects.Remove(src)
		return

	while(charge_counter < charge_max)
		charge_counter++


/atom/movable/spell/Click()
	..()

	perform(usr)

/////////////////
/////CASTING/////
/////////////////

/atom/movable/spell/proc/choose_targets(mob/user = usr) //depends on subtype - see targeted.dm, aoe_turf.dm, dumbfire.dm, or code in general folder
	return

/atom/movable/spell/proc/perform(mob/user = usr, skipcharge = 0) //if recharge is started is important for the trigger spells
	if(!cast_check())
		return
	if(cast_delay && !do_after(user, cast_delay))
		return
	if(!holder)
		holder = user //just in case
	var/list/targets = choose_targets()
	if(targets && targets.len)
		invocation(user, targets)
		take_charge(user, skipcharge)

		before_cast(targets) //applies any overlays and effects
		user.attack_log += text("\[[time_stamp()]\] <font color='red'>[user.real_name] ([user.ckey]) cast the spell [name].</font>")
		if(prob(critfailchance))
			critfail(targets, user)
		else
			cast(targets, user)
		after_cast(targets) //generates the sparks, smoke, target messages etc.


/atom/movable/spell/proc/cast(list/targets, mob/user) //the actual meat of the spell
	return

/atom/movable/spell/proc/critfail(list/targets, mob/user) //the wizman has fucked up somehow
	return

/atom/movable/spell/proc/adjust_var(mob/living/target = usr, type, amount) //handles the adjustment of the var when the spell is used. has some hardcoded types
	switch(type)
		if("bruteloss")
			target.adjustBruteLoss(amount)
		if("fireloss")
			target.adjustFireLoss(amount)
		if("toxloss")
			target.adjustToxLoss(amount)
		if("oxyloss")
			target.adjustOxyLoss(amount)
		if("stunned")
			target.AdjustStunned(amount)
		if("weakened")
			target.AdjustWeakened(amount)
		if("paralysis")
			target.AdjustParalysis(amount)
		else
			target.vars[type] += amount //I bear no responsibility for the runtimes that'll happen if you try to adjust non-numeric or even non-existant vars
	return

///////////////////////////
/////CASTING WRAPPERS//////
///////////////////////////

/atom/movable/spell/proc/before_cast(list/targets)
	var/valid_targets[0]
	for(var/atom/target in targets)
		// Check range again (fixes long-range EI NATH)
		if(!(target in view_or_range(range,usr,selection_type)))
			continue

		valid_targets += target

		if(overlay)
			var/location
			if(istype(target,/mob/living))
				location = target.loc
			else if(istype(target,/turf))
				location = target
			var/obj/effect/overlay/spell = new /obj/effect/overlay(location)
			spell.icon = overlay_icon
			spell.icon_state = overlay_icon_state
			spell.anchored = 1
			spell.density = 0
			spawn(overlay_lifespan)
				del(spell)
	return valid_targets

/atom/movable/spell/proc/after_cast(list/targets)
	for(var/atom/target in targets)
		var/location = get_turf(target)
		if(istype(target,/mob/living) && message)
			target << text("[message]")
		if(sparks_spread)
			var/datum/effect/effect/system/spark_spread/sparks = new /datum/effect/effect/system/spark_spread()
			sparks.set_up(sparks_amt, 0, location) //no idea what the 0 is
			sparks.start()
		if(smoke_spread)
			if(smoke_spread == 1)
				var/datum/effect/effect/system/smoke_spread/smoke = new /datum/effect/effect/system/smoke_spread()
				smoke.set_up(smoke_amt, 0, location) //no idea what the 0 is
				smoke.start()
			else if(smoke_spread == 2)
				var/datum/effect/effect/system/smoke_spread/bad/smoke = new /datum/effect/effect/system/smoke_spread/bad()
				smoke.set_up(smoke_amt, 0, location) //no idea what the 0 is
				smoke.start()

/////////////////////
////CASTING TOOLS////
/////////////////////
/*Checkers, cost takers, message makers, etc*/

/atom/movable/spell/proc/cast_check(skipcharge = 0,mob/user = usr) //checks if the spell can be cast based on its settings; skipcharge is used when an additional cast_check is called inside the spell

	if(!(src in user.spell_list))
		user << "<span class='warning'>You shouldn't have this spell! Something's wrong.</span>"
		return 0

	if(user.z == 2 && spell_flags & Z2NOCAST) //Certain spells are not allowed on the centcomm zlevel
		return 0

	if(istype(user, /mob/living/simple_animal))
		var/mob/living/simple_animal/SA = user
		if(SA.purge)
			SA << "<span class='warning'>The nullrod's power interferes with your own!</span>"
			return 0

	if(!src.check_charge(skipcharge, user)) //sees if we can cast based on charges alone
		return 0

	if(!(spell_flags & GHOSTCAST))
		if(user.stat && !(spell_flags & STATALLOWED))
			usr << "Not when you're incapacitated."
			return 0

		if(ishuman(user) || ismonkey(user))
			if(istype(usr.wear_mask, /obj/item/clothing/mask/muzzle))
				usr << "Mmmf mrrfff!"
				return 0

	var/atom/movable/spell/noclothes/spell = locate() in user.spell_list
	if((spell_flags & NEEDSCLOTHES) && !(spell && istype(spell)))//clothes check
		if(!user.wearing_wiz_garb())
			return 0

	return 1

/atom/movable/spell/proc/check_charge(var/skipcharge, mob/user)
	if(!skipcharge)
		switch(charge_type)
			if("recharge")
				if(charge_counter < charge_max)
					user << still_recharging_msg
					return 0
			if("charges")
				if(!charge_counter)
					user << "<span class='notice'>[name] has no charges left.</span>"
					return 0
	return 1

/atom/movable/spell/proc/take_charge(mob/user, var/skipcharge)
	if(!skipcharge)
		switch(charge_type)
			if("recharge")
				charge_counter = 0 //doesn't start recharging until the targets selecting ends
				src.process()
				return 1
			if("charges")
				charge_counter-- //returns the charge if the targets selecting fails
				return 1
			if("holdervar")
				adjust_var(user, holder_var_type, holder_var_amount)
				return 1
		return 0
	return 1

/atom/movable/spell/proc/invocation(mob/user = usr, var/list/targets) //spelling the spell out and setting it on recharge/reducing charges amount

	switch(invocation_type)
		if("shout")
			if(prob(50))//Auto-mute? Fuck that noise
				user.say(invocation)
			else
				user.say(replacetext(invocation," ","`"))
		if("whisper")
			if(prob(50))
				user.whisper(invocation)
			else
				user.whisper(replacetext(invocation," ","`"))
		if("emote")
			user.visible_message(invocation)

/////////////////////
///UPGRADING PROCS///
/////////////////////

/atom/movable/spell/proc/can_improve(var/upgrade_type)
	if(level_max["total"] <= ( spell_levels["speed"] + spell_levels["power"] )) //too many levels, can't do it
		return 0

	if(upgrade_type && upgrade_type in spell_levels && upgrade_type in level_max)
		if(spell_levels[upgrade_type] >= level_max[upgrade_type])
			return 0

	return 1

/atom/movable/spell/proc/empower_spell()
	return

/atom/movable/spell/proc/quicken_spell()
	if(!can_improve("speed"))
		return 0

	spell_levels["speed"]++

	if(delay_reduc && cast_delay)
		cast_delay = max(0, cast_delay - delay_reduc)
	else if(cast_delay)
		cast_delay = round( max(0, initial(cast_delay) * ((level_max["speed"] - spell_levels["speed"]) / level_max["speed"] ) ) )

	if(charge_type == "recharge")
		if(cooldown_reduc)
			charge_max = max(cooldown_min, charge_max - cooldown_reduc)
		else
			charge_max = round( max(cooldown_min, initial(charge_max) * ((level_max["speed"] - spell_levels["speed"]) / level_max["speed"] ) ) ) //the fraction of the way you are to max speed levels is the fraction you lose
	if(charge_max < charge_counter)
		charge_counter = charge_max

	var/temp = ""
	name = initial(name)
	switch(level_max["speed"] - spell_levels["speed"])
		if(3)
			temp = "You have improved [name] into Efficient [name]."
			name = "Efficient [name]"
		if(2)
			temp = "You have improved [name] into Quickened [name]."
			name = "Quickened [name]"
		if(1)
			temp = "You have improved [name] into Free [name]."
			name = "Free [name]"
		if(0)
			temp = "You have improved [name] into Instant [name]."
			name = "Instant [name]"

	return temp