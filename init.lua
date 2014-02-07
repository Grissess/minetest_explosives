--Explosives mod
--Causes big booms! :D
--by Grissess

explosives={
	modpath=minetest.get_modpath("explosives"),
	default_settings={
		MAX_DEPTH={key="explosion_maxdepth", type="n", default=16}, --How deep the call stack goes in the recursive general_explosion algorithm
		MAX_DROPS={key="explosion_maxdrops", type="n", default=49}, --Maximum number of drops to place from a single explosion (experimentally found to be maximal stored in a mapblock)
		MAX_DAMAGE={key="explosion_maxdamage", type="n", default=10000}, --Maximum damage that may be done to an entity from blast damage
		DEFAULT_RESISTANCE={key="explosion_default_resistance", type="n", default=0.35}, --The blast_resistance assumed for blocks with no particular resistance set
		DEFAULT_COUNTDOWN={key="explosion_default_countdown", type="n", default=5}, --The time, in seconds, until primed TNT goes boom
		DEFAULT_DROPCHANCE={key="explosion_default_dropchance", type="n", default=4}, --The chance (expressed as 1:n) that an exploded block is dropped after removal.
		ENABLE_VACUUM={key="explosion_enable_vacuum", type="b", default=true}, --Enable /vacuum command
		VACUUM_RADIUS={key="explosion_vacuum_radius", type="n", default=1024}, --Radius of /vacuum command
		ENABLE_TRACE={key="explosion_enable_trace", type="b", default=true}, --Enable /trace command, should be turned off for servers!
		DAMAGE_FACTOR={key="explosion_damage_factor", type="n", default=80} --Blast damage done by a player at the epicenter of a 1-power explosion
	}
}

if not explosives.modpath then
	error("[EXPLOSIVES] ERROR! The 'minetest_explosives' repo MUST be called 'explosives' to function properly!")
end

function explosives.log(s)
	print("[EXPLOSIVES] "..s)
end

for name, spec in pairs(explosives.default_settings) do
	local val=minetest.setting_get(spec.key)
	if val then
		if spec.type=="n" then
			local asnumber=tonumber(val)
			if asnumber then
				explosives[name]=asnumber
			else
				explosives[name]=spec.default
			end
		elseif spec.type=="b" then
			explosives[name]=minetest.setting_getbool(spec.key)
		else
			exposives.log("WARNING: Unrecognized spec type for specified value for config setting "..name.."; using default.")
			explosives[name]=spec.default
		end
	else
		explosives[name]=spec.default
		minetest.setting_set(spec.key, tostring(spec.default))
	end
	explosives.log("Config setting "..name.." = "..tostring(explosives[name]))
end

dofile(explosives.modpath.."/raytrace.lua")

dofile(explosives.modpath.."/lib.lua")

dofile(explosives.modpath.."/defs.lua")