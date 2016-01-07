--lib.lua
--Defines the actual explosion-handling library.

local function is_empty(node)
	return node.name=="air" or node.name=="ignore"
end

local function entity_name(obj)
	if obj:is_player() then
		return "Player "..obj:get_player_name()
	elseif obj:get_luaentity() then
		return "Lua object "..obj:get_luaentity().name
	else
		return "Unknown thing"
	end
end

function explosives.general_modfunc(pos, power, parentvals, globalvals, param)
	local node=minetest.get_node(pos)
	if is_empty(node) then return power end
	local nodedef=minetest.registered_nodes[node.name]
	if nodedef and nodedef.can_dig and not nodedef.can_dig(pos, globalvals.player) then return power end
	if minetest.get_item_group(node.name, "unbreakable")>0 then return 0 end
	local resistance=minetest.get_item_group(node.name, "blast_resistance")
	if resistance==0 then resistance=explosives.DEFAULT_RESISTANCE end
	
	local nodedef=minetest.registered_nodes[node.name]
	if nodedef and nodedef.on_blast then
		nodedef.on_blast(pos, power)
	else
		if power>resistance then
			local dropstacks=minetest.get_node_drops(node.name, nil)
			minetest.dig_node(pos)
			for _, stack in ipairs(dropstacks) do
				if globalvals.drops>explosives.MAX_DROPS then break end
				if math.random(explosives.DEFAULT_DROPCHANCE)==1 then
					minetest.add_item(pos, stack)
					globalvals.drops=globalvals.drops+1
				end
			end
		end
	end
	return power-resistance
end

local function cache_pos(cache, pos)
	if not cache[pos.x] then
		cache[pos.x]={}
	end
	if not cache[pos.x][pos.y] then
		cache[pos.x][pos.y]={}
	end
	if not cache[pos.x][pos.y][pos.z] then
		cache[pos.x][pos.y][pos.z]=true
	end
end

local function pos_in_cache(cache, pos)
	local cmp=cache[pos.x]
	if not cmp then return false end
	cmp=cmp[pos.y]
	if not cmp then return false end
	cmp=cmp[pos.z]
	if not cmp then return false end
	return true
end

function explosives.general_explode(pos, power, player, options, modfunc, param, cache, depth, parentvals, globalvals)
	if not cache then cache={} end
	if not modfunc then modfunc=explosives.general_modfunc end
	if not depth then depth=0 end
	if not parentvals then parentvals={} end
	if not globalvals then globalvals={} end
	--Sanity
	if not power then return explosives.log("Attempted to explode with nil power!") end
	if not pos then return explosives.log("Attempted to explode with nil pos!") end
	local objects
	local nodepos={x=math.floor(pos.x), y=math.floor(pos.y), z=math.floor(pos.z)}
	if depth==0 then
		--Options
		if not options then options={} end
		if not options.blockdamage then options.blockdamage=true end
		if not options.entitydamage then options.entitydamage=true end
		if not options.entitypush then options.entitypush=true end
		explosives.log("Explosion power="..tostring(power).." at "..minetest.pos_to_string(pos))
		globalvals.pos=pos
		globalvals.power=power
		globalvals.player=options.player
		globalvals.drops=0
		
		--Store this now, because there's going to likely be a lot of drops later.
		--The following distance calculation is a solution for which the damage would be >=1;
		--this should suffice for our purposes.
                local radius=(explosives.DAMAGE_FACTOR*power)^0.5
		if options.entitydamage or options.entitypush then
			objects=minetest.get_objects_inside_radius(pos, radius)
		end
                minetest.sound_play("explosives_explode", {pos=pos, gain=2.0, max_hear_distance=radius*64})
	end
	
	if options.blockdamage then
		cache_pos(cache, pos)
		
		power=modfunc(pos, power, parentvals, globalvals, param)
		if power<=0 or depth>=explosives.MAX_DEPTH then return end
		
		--as a rule, permit only orthogonal faces (one axis offset must be zero) and do not consider a zero offset.
		--Furthermore, if we're in one octant of 3-space wrt our previous traversal, do not traverse into other octants.
		--This should simulate rays to some extent (except hopefully more efficient and faster due to redundancy elimination),
		--while preventing tunnelling due to wrapping around.
		--Simulated "continue" construct courtesy http://lua-users.org/lists/lua-l/2006-12/msg00440.html .
		
		local lx=-1
		local hx=1
		local ly=-1
		local hy=1
		local lz=-1
		local hz=1
		if parentvals.lastpos then
			local lastpos=parentvals.lastpos
			local dpos={x=nodepos.x-lastpos.x, y=nodepos.y-lastpos.y, z=nodepos.z-lastpos.z}
			if dpos.x>0 then lx=0 end
			if dpos.x<0 then hx=0 end
			if dpos.y>0 then ly=0 end
			if dpos.y<0 then hy=0 end
			if dpos.z>0 then lz=0 end
			if dpos.z<0 then hz=0 end
		end
		
		for dx=lx, hx do
			for dy=ly, hy do
				for dz=lz, hz do
					repeat
						if (dx==0 and dy==0 and dz==0) or not (dx==0 or dy==0 or dz==0) then break end
						local newpos={x=nodepos.x+dx, y=nodepos.y+dy, z=nodepos.z+dz}
						--if depth==0 then
							--explosives.log("DEBUG: Depth 0, position traversal, new position: "..minetest.pos_to_string(newpos))
						--end
						if not pos_in_cache(cache, newpos) then
							explosives.general_explode(newpos, power, player, options, modfunc, param, cache, depth+1, {lastpos=pos}, globalvals)
						end
					until true
				end
			end
		end
	end
	
	if depth==0 then
		--Do a raytrace to see if we cleared a line between the original pos and each of the stored objects;
		--if we did, then the blast was sufficient to propagate to that object.
		if options.entitydamage or options.entitypush then
			for _, obj in ipairs(objects) do
				local opos=obj:getpos()
				if obj:is_player() then
					opos.y=opos.y+0.1 --Add some distance for raytracing; otherwise this point is on the separation plane, and might cause some FP issues.
				end
				local skip=false
				local nodes=raytrace.trace_node_array(pos, opos)
				--explosives.log("DEBUG: Tracing nodes from "..minetest.pos_to_string(pos).." to "..minetest.pos_to_string(opos))
				for _, node in ipairs(nodes) do
					--explosives.log("DEBUG: Testing node "..node.name)
					if not is_empty(node) then
						explosives.log("DEBUG: Skipping damage calc for "..tostring(obj).." ("..entity_name(obj)..") @"..minetest.pos_to_string(opos).."because the path is obstructed.")
						skip=true
						break
					end
				end
				if not skip then
					local dist=vector.distance(pos, opos)
					local damage
					if dist==0 then
						damage=explosives.MAX_DAMAGE
					else
						damage=math.min(explosives.DAMAGE_FACTOR*power*(dist^-2), explosives.MAX_DAMAGE)
					end
					explosives.log("DEBUG: Performing damage calc; "..tostring(damage).." damage (distance "..tostring(dist)..") assigned to "..tostring(obj).." ("..entity_name(obj)..")")
					if options.entitydamage then
						--TODO: Use punch? What kind of tool capabilities should equate to a blast?
						obj:set_hp(obj:get_hp()-damage)
					end
					if options.entitypush and dist~=0 then
						obj:setvelocity(vector.multiply(vector.normalize(vector.subtract(opos, pos)), damage/20))
					end
				end
			end
			explosives.log("DEBUG: Explosion at "..minetest.pos_to_string(pos).." done.")
			--minetest.set_node(pos, {name="wool:red"}) --DEBUG
			--minetest.set_node(nodepos, {name="wool:blue"}) --DEBUG
		end
	end
end
