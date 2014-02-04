--defs.lua
--Defines all of the explosive materials in this mod.

local function tnt_tiles(type)
	return {"tnt_"..type.."_top.png", "tnt_"..type.."_bottom.png", "tnt_"..type.."_side_a.png", "tnt_"..type.."_side_b.png", "tnt_"..type.."_side_a.png", "tnt_"..type.."_side_b.png"}
end

function explosives.detonate(pos)
	local node=minetest.get_node(pos)
	local player=minetest.get_meta(pos):get_string("player")
	local power=minetest.get_item_group(node.name, "explosive")
	if power==0 then return explosives.log("WARNING: Attempted to detonate a non-explosive node "..node.name) end
	
	explosives.log("DEBUG: Detonating "..node.name.." at "..minetest.pos_to_string(pos))
	
	minetest.remove_node(pos)
	local tnt=minetest.add_entity(pos, "explosives:primed_tnt")
	if tnt then
		local tntent=tnt:get_luaentity()
		tntent.power=power
		tntent.player=player
		tntent.boomtime=explosives.DEFAULT_COUNTDOWN
		tntent.modfunc=explosives.general_modfunc
		tntent.param=nil
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

minetest.register_entity("explosives:primed_tnt", {
	initial_properties={
		physical=true,
		visual="cube",
		textures=tnt_tiles("normal")
	},
	on_step=function(self, dt)
		local pos=self.object:getpos()
		if not self.boomtime then self.boomtime=0 end
		if dt>self.boomtime then
			pos={x=pos.x+0.5, y=pos.y+0.5, z=pos.z+0.5}
			explosives.general_explode(pos, self.power, self.modfunc, self.param)
			self.object:remove()
			return
		else
			self.boomtime=self.boomtime-dt
		end
		pos.y=pos.y-0.5
		if minetest.get_node(pos).name~="air" then
			self.object:setvelocity({x=0, y=0, z=0})
			self.object:setacceleration({x=0, y=0, z=0})
		end
	end
})

minetest.register_node("explosives:tnt", {
	description="TNT",
	drawtype="normal",
	tiles=tnt_tiles("normal"),
	paramtype="light",
	walkable=true,
	pointable=true,
	groups={explosive=1, blast_resistance=1, oddly_breakable_by_hand=2},
	on_blast=explosives.on_blast,
	after_place_node=explosives.after_place_node
})

minetest.register_node("explosives:mega_tnt", {
	description="Mega TNT",
	drawtype="normal",
	tiles=tnt_tiles("mega"),
	paramtype="light",
	walkable=true,
	pointable=true,
	groups={explosive=4, blast_resistance=1, oddly_breakable_by_hand=2},
	on_blast=explosives.on_blast,
	after_place_node=explosives.after_place_node
})

minetest.register_node("explosives:super_tnt", {
	description="Super TNT",
	drawtype="normal",
	tiles=tnt_tiles("super"),
	paramtype="light",
	walkable=true,
	pointable=true,
	groups={explosive=16, blast_resistance=1, oddly_breakable_by_hand=2},
	on_blast=explosives.on_blast,
	after_place_node=explosives.after_place_node
})

minetest.register_node("explosives:ultra_tnt", {
	description="Ultra TNT",
	drawtype="normal",
	tiles=tnt_tiles("ultra"),
	paramtype="light",
	walkable=true,
	pointable=true,
	groups={explosive=64, blast_resistance=1, oddly_breakable_by_hand=2},
	on_blast=explosives.on_blast,
	after_place_node=explosives.after_place_node
})

minetest.register_node("explosives:hyper_tnt", {
	description="Hyper TNT",
	drawtype="normal",
	tiles=tnt_tiles("hyper"),
	paramtype="light",
	walkable=true,
	pointable=true,
	groups={explosive=256, blast_resistance=1, oddly_breakable_by_hand=2},
	on_blast=explosives.on_blast,
	after_place_node=explosives.after_place_node
})

minetest.register_node("explosives:blastproofing", {
	drawtype="normal",
	tiles={"blastproofing.png"},
	paramtype="light",
	walkable=true,
	pointable=true,
	groups={cracky=2, blast_resistance=32}
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
	})
end