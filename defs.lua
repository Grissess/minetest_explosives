--defs.lua
--Defines all of the explosive materials in this mod.

local function is_water(node)
	return node.name=="default:water_flowing" or node.name=="default:water_source"
end

function explosives.detonate(pos)
	local node=minetest.get_node(pos)
	local player=minetest.get_meta(pos):get_string("player")
	local power=minetest.get_item_group(node.name, "explosive")
	if power==0 then return explosives.log("WARNING: Attempted to detonate a non-explosive node "..node.name) end
	
	explosives.log("DEBUG: Detonating "..node.name.." at "..minetest.pos_to_string(pos))
	
	minetest.remove_node(pos)
	local tnt=minetest.add_entity(pos, "explosives:explosive")
	if tnt then
		local tntent=tnt:get_luaentity()
		tntent.power=power
		tntent.player=player
		tntent.boomtime=explosives.DEFAULT_COUNTDOWN
		tntent.modfunc=explosives.general_modfunc
		tntent.param=nil
		local nodedef=minetest.registered_nodes[node.name]
		if nodedef and nodedef.tiles then
			tntent.tiles=nodedef.tiles
		else
			tntent.tiles=minetest.registered_nodes["explosives:tnt"].tiles
			explosives.log("WARNING: Using default textures for unknown explosive node "..node.name.."'s explosive entity")
		end
		tntent:update_visual()
		tnt:setvelocity({x=0, y=3, z=0})
		tnt:setacceleration({x=0, y=-10, z=0})
	else
		explosives.log("WARNING: Could not spawn explosive entity.")
	end
	return tnt
end

function explosives.on_blast(pos, power)
	if not explosives.detonate(pos) then
		explosives.log("WARNING: Had to remove a "..minetest.get_node(pos).name.."node with an explosives.on_blast callback but no explosive ability (or the entity failed to spawn)")
		minetest.remove_node(pos)
	end
end

function explosives.after_place_node(pos, placer, itemstack, pointed)
	local name=placer:get_player_name() or ""
	local meta=minetest.get_meta(pos)
	meta:set_string("player", name)
	meta:set_string("infotext", name) --DEBUG
end

function explosives.mesecons_action_on(pos, node)
	explosives.log("DEBUG: Detonating explosive at "..minetest.pos_to_string(pos).." due to mesecons effector")
	explosives.detonate(pos)
end

local MESECONS={effector={action_on=explosives.mesecons_action_on}}

local function tnt_tiles(type)
	return {"tnt_"..type.."_top.png", "tnt_"..type.."_bottom.png", "tnt_"..type.."_side_a.png", "tnt_"..type.."_side_b.png", "tnt_"..type.."_side_a.png", "tnt_"..type.."_side_b.png"}
end

local function tnt_nodedef(type, descr, explosive)
	return {
		description=descr,
		drawtype="normal",
		tiles=tnt_tiles(type),
		paramtype="light",
		walkable=true,
		pointable=true,
		groups={explosive=explosive, blast_resistance=1, oddly_breakable_by_hand=2},
		on_blast=explosives.on_blast,
		after_place_node=explosives.after_place_node,
		mesecons=MESECONS
	}
end

minetest.register_entity("explosives:explosive", {
	initial_properties={
		physical=true,
		visual="cube",
		textures=tnt_tiles("normal")
	},
	on_step=function(self, dt)
		local pos=self.object:getpos()
		local pvel=vector.new(4*math.random()-2, 3+2*math.random(), 4*math.random()-2)
		local pacc=vector.new(0, -9, 0)
		minetest.add_particle({
			pos=vector.add(pos, vector.new(0, 0.6, 0)),
			size=3,
			velocity=pvel,
			vel=pvel, --XXX lua_particles.cpp uses these keys, but this change is not documented (yet). FIXME?
			acceleration=pacc,
			acc=pacc,
			expirationtime=0.5+0.5*math.random(),
			texture="fire_particle.png",
			collisiondetection=false
		})
		if not self.boomtime then self.boomtime=0 end
		if dt>self.boomtime then
			--pos={x=pos.x+0.25, y=pos.y+0.25, z=pos.z+0.25}
			--Just as a note, this line remains commented for good reason and as a reminder;
			--it seems that cubic entities like this consider their position to be at the center
			--of their volume, unlike players, which consider their position to be at their feet
			--(and there's probably mimicry of this principle in player-like entities).
			local node=minetest.get_node(pos)
			explosives.log("DEBUG: Explosion to take place inside block of "..node.name)
			explosives.general_explode(pos, self.power, self.player, {blockdamage=not is_water(node)}, self.modfunc, self.param)
			self.object:remove()
			return
		else
			self.boomtime=self.boomtime-dt
		end
	end,
	update_visual=function(self)
		self.object:set_properties({textures=self.tiles})
	end
})

minetest.register_node("explosives:tnt", tnt_nodedef("normal", "TNT", 1))

minetest.register_node("explosives:mega_tnt", tnt_nodedef("mega", "Mega TNT", 4))

minetest.register_node("explosives:super_tnt", tnt_nodedef("super", "Super TNT", 16))

minetest.register_node("explosives:ultra_tnt", tnt_nodedef("ultra", "Ultra TNT", 64))

minetest.register_node("explosives:hyper_tnt", tnt_nodedef("hyper", "Hyper TNT", 256))

minetest.register_node("explosives:blastproofing", {
	drawtype="normal",
	tiles={"blastproofing.png"},
	paramtype="light",
	walkable=true,
	pointable=true,
	groups={cracky=2, blast_resistance=32}
})

minetest.register_node("explosives:blastproof_glass", {
	drawtype="glasslike",
	tiles={"blastproof_glass.png"},
	paramtype="light",
	walkable=true,
	pointable=true,
	sunlight_propagates=true,
	groups={blast_resistance=32, oddly_breakable_by_hand=2},
	sounds=default.node_sound_glass_defaults()
})

minetest.register_craftitem("explosives:gunpower", {
	description="Gunpowder",
	inventory_image="gunpowder.png"
})

minetest.register_craft({
	output="explosives:tnt",
	recipe={
		{"explosives:gunpowder", "group:sand", "explosives:gunpowder"},
		{"group:sand", "explosives:gunpowder", "group:sand"},
		{"explosives:gunpowder", "group:sand", "explosives:gunpowder"}
	}
})

minetest.register_craft({
	output="explosives:mega_tnt",
	recipe={
		{"explosives:tnt", "explosives:tnt"},
		{"explosives:tnt", "explosives:tnt"}
	}
})

minetest.register_craft({
	output="explosives:super_tnt",
	recipe={
		{"explosives:mega_tnt", "explosives:mega_tnt"},
		{"explosives:mega_tnt", "explosives:mega_tnt"}
	}
})

minetest.register_craft({
	output="explosives:ultra_tnt",
	recipe={
		{"explosives:super_tnt", "explosives:super_tnt"},
		{"explosives:super_tnt", "explosives:super_tnt"}
	}
})

minetest.register_craft({
	output="explosives:super_tnt",
	recipe={
		{"explosives:super_tnt", "explosives:super_tnt"},
		{"explosives:super_tnt", "explosives:super_tnt"}
	}
})

minetest.register_abm({
	nodenames={"group:explosive"},
	neighbors={"group:igniter"},
	interval=1.0,
	chance=4,
	action=function(pos, node, aoc, aocw)
		explosives.log("DEBUG: ABM detonating TNT due to fire")
		explosives.detonate(pos)
	end
})

if explosives.ENABLE_VACUUM then
	minetest.register_privilege("vacuum", "Player can vacuum free items out of the server.")
	
	minetest.register_chatcommand("vacuum", {
		params="",
		description="Vacuum all items currently spawned in the server into the issuing player.",
		privs={vacuum=true},
		func=function(player, params)
			local ply=minetest.get_player_by_name(player)
			local inv=ply:get_inventory()
			local objects=minetest.get_objects_inside_radius(ply:getpos(), explosives.VACUUM_RADIUS)
			for _, obj in ipairs(objects) do
				if not obj:is_player() then
					local luaobj=obj:get_luaentity()
					if not luaobj then
						explosives.log("WARNING: No lua object associated!")
					elseif luaobj.name=="__builtin:item" then
						local result=inv:add_item("main", luaobj.itemstring)
						if result:is_empty() then
							obj:remove()
						end
					end
				end
			end
		end
	})
end

if explosives.ENABLE_TRACE then
	minetest.register_privilege("trace", "Player can debug the trace library.")
	
	minetest.register_chatcommand("trace", {
		params="(x1,y1,z1) (x2,y2,z2) block",
		description="Set all blocks on the trace between the given points to block.",
		privs={trace=true},
		func=function(player, params)
			local p1, p2, node
			p1, p2, node=string.match(params, "^(%S+) (%S+) (%S+)$")
			if not (p1 and p2 and node) then
				minetest.chat_send_player(player, "Invalid trace specification.")
				return
			end
			p1=minetest.string_to_pos(p1)
			p2=minetest.string_to_pos(p2)
			if not (p1 and p2) then
				minetest.chat_send_player(player, "Invalid position specification.")
				return
			end
			local pts=raytrace.trace_node_points(p1, p2)
			for _, pt in ipairs(pts) do
				minetest.set_node(pt, {name=node})
			end
		end
	})
end