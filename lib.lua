--lib.lua
--Defines the actual explosion-handling library.

function explosives.general_modfunc(pos, node, power, drops, param)
	if node.name=="air" then return power end
	local resistance=minetest.get_item_group(node.name, "blast_resistance")
	if resistance==0 then resistance=explosives.DEFAULT_RESISTANCE end
	
	local nodedef=minetest.registered_nodes[node.name]
	if nodedef and nodedef.on_blast then
		nodedef.on_blast(pos, power)
	else
		local dropstacks=minetest.get_node_drops(node.name, nil)
		minetest.remove_node(pos)
		for _, stack in ipairs(dropstacks) do
			if drops>explosives.MAX_DROPS then break end
			if math.random(explosives.DEFAULT_DROPCHANCE)==1 then
				minetest.add_item(pos, stack)
				drops=drops+1
			end
		end
	end
	return power-resistance, drops
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

function explosives.general_explode(pos, power, modfunc, param, cache, depth, lastpos, drops)
	if not cache then cache={} end
	if not modfunc then modfunc=explosives.general_modfunc end
	if not depth then depth=0 end
	if not drops then drops=0 end
	--Sanity
	if not power then return explosives.log("Attempted to explode with nil power!") end
	if not pos then return explosives.log("Attempted to explode with nil pos!") end
	pos={x=math.floor(pos.x), y=math.floor(pos.y), z=math.floor(pos.z)}
	if depth==0 then explosives.log("Explosion power="..tostring(power).." at "..minetest.pos_to_string(pos)) end
	
	cache_pos(cache, pos)
	
	power, drops=modfunc(pos, minetest.get_node(pos), power, drops, param)
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
	if lastpos then
		local dpos={x=pos.x-lastpos.x, y=pos.y-lastpos.y, z=pos.z-lastpos.z}
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
					local newpos={x=pos.x+dx, y=pos.y+dy, z=pos.z+dz}
					--if depth==0 then
						--explosives.log("DEBUG: Depth 0, position traversal, new position: "..minetest.pos_to_string(newpos))
					--end
					if not pos_in_cache(cache, newpos) then
						explosives.general_explode(newpos, power, modfunc, param, cache, depth+1, pos, drops)
					end
				until true
			end
		end
	end
end