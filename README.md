minetest_explosives
===================

Hey!
----

You're looking at the development branch! This may be unstable, and there may be issues in here that can cause serious stability concerns; I would not recommend running this on an established server or any map that you care about.

If you'd like to go to the stable version, please check out the ["master" branch](https://github.com/Grissess/minetest_explosives/tree/master). Otherwise, continue at your own risk.

Brings big booms to [Minetest](minetest.net) :D

Currently a Work-in-Progress; a stable and usable API should be available soon!

Currently supports:

* All kinds of TNT and derived TNTs with equal power (1 being the "usual" power).
* The unused (as far as I know) `on_blast` function in node defs, with the usual semantics. (TODO: Let it dynamically provide blast resistance values...)
* A fairly fast, efficient, and stable explosion propagation function (`explosives.general_explode`) that may be called from any explosive and customized with a modification callback (`explosives.general_modfunc`, usually).
* Item drops, which may happen only by chance.
* Entity damage! (Based on a powerful voxel raytracing library that is extensible and flexible; scroll all the way down :P)
* Integration with mesecons.
* Easy per-game configuation of various performance and tuning parameters :D

Will eventually support:

* Different modfuncs (for things like fission or energy weapons).
* An explosion algorithm that avoids the "wrap-around" currently afforded by unrestricted recursion (and makes it less ray-like).
* Better textures, hopefully :P

Use
---

When cloning this repository, be sure to use something like

    git clone https://github.com/Grissess/minetest_explosives.git explosives

in your mod folder. Alternatively, you can extract the zip, but be sure the directory's name is "explosives"--otherwise, Minetest will complain about naming convention issues and fail to load it :P

At present, the only way to detonate the TNT is to put fire near it (in any adjacent block) and wait; there is a 1 in 4 chance that it will detonate in any given second. Support for immediate detonation using mesecons will be implemented soon!

API
---

This is very likely to change, so don't depend on it:

* `explosives.general_explode(pos, power, player, options, modfunc, param, cache, depth, parentvals, globalvals)`: Explode at `pos` with `power` (1 being the usual TNT). `player` is the player to be blamed for causing the explosion. This is used in `can_dig` callbacks, and can be the empty string (using nil is discouraged). All other arguments are optional, in particular:

  * `options` are the options to be in effect. If not given (or nil), all defaults are assumed. Any key also not given explicitly will be set to its default. Valid options include:
    * `blockdamage` (default true): Do damage to terrain during this explosion. (Turning this off cuts down on processing time dramatically, as no recursion occurs.)
    * `entitydamage` (default true): Do damage to entities during this explosion.
    * `entitypush` (default true): Push entities using setvelocity during this explosion. Turning both this and the above off turn off processing and searching for entities altogether.
  * `modfunc` is the modification func called at each position with each node, at most once per position, to cause explosion effects (damage) to blocks. The default implementation is `explosives.general_modfunc`, which handles on_blast and item drop logic.
  * `param` is a parameter that may be passed to a custom `modfunc`. `explosives.general_modfunc` doesn't use it.
  * `cache` is the position visit cache and should not be passed.
  * `depth` is the recursion level and should not be passed.
  * `parentvals` is a table of values used to pass information to the called function from the immediate caller and should not be passed.
  * `globalvals` is a table of values used to pass information to all called functions from the initial call (depth==0) and should not be passed.
  
* `explosives.general_modfunc(pos, power, parentvals, globalvals, param)`: Does the usual logic for explosion modification, but this implementation may be overriden by passing another function as a `modfunc` to `explosives.general_explode`. The parameters are defined as follows:

  * `pos` is the position being processed.
  * `power` is the current power (1 being the power of the epicenter of usual TNT).
  * `parentvals` are the values passed in to `explosives.general_explode` from the immediate caller in the recursion chain, and include:
    * `parentvals.pos`: The position passed to the parent function. (TODO: `parentvals.lastpos` currently...)
    * `parentvals.depth`: The recursion depth of the parent function. (TODO: Implement :P)
  * `globalvals` are the values passed in to `explosives.general_explode` from the first call, and include:
    * `globalvals.pos`: The original explosion position.
    * `globalvals.power`: The original explosion power.
    * `globalvals.player`: The player responsible for this explosion.
    * `globalvals.drops`: The number of drops created so far in this explosion. Should be incremented for each drop created in a modfunc, and checked against `explosives.MAX_DROPS`.
  * `param` is the `param` passed to `explosives.general_explode`.

  The function must return a `power`, the resulting power after blast resistance is computed.
  
  The default implementation defers to on_blast if it can; otherwise, it gets the drops, spawns some of them, removes the node, and returns the appropriate power based on the `blast_resistance` group. If you are implementing on_blast, you are responsible for implementing these behaviors yourself. (TODO: Currently no way to override blast_resistance using on_blast...)
  
For block developers, the following groups are of interest:

* `blast_resistance`: If nonzero, specifies the blast resistance of this block (how much explosive damage it absorbs). If zero (or not a member), `explosives.DEFAULT_RESISTANCE` is assumed.
* `explosive`: If nonzero, the block is an explosive, and may be triggered by igniters (fire, lava) or mesecons (TODO!). The value specifies the explosive power on detonation. (TODO: Provide a way to customize the appearance of the explosive entity...)

The functions `explosives.on_blast` and `explosives.after_place_node` are configured to be used as node callbacks of the same names to implement activation-on-blast and to correctly set the responsible player for the explosion, respectively.

Entity developers might want to know about some attributes that may be stored on the `explosives:primed_tnt` `LuaEntitySAO`:

* `power`: The `power` parameter to `explosives.general_explode`.
* `player`: The `player` parameter to `explosives.general_explode`.
* `boomtime`: Seconds until explosion; decreased in `on_step`.
* `modfunc`: The `modfunc` parameter to `explosives.general_explode`.
* `param`: The `param` parameter to `explosives.general_explode`.

The position is calculated as the nearest integer position to the entity's box center during detonation.

To force an explosion of an explosive node from Lua, use explosives.detonate(pos). The return value is an `ObjectRef` whose `LuaEntitySAO` may be configured as needed, or nil if the block wasn't explosive (in which case the node is not removed) or the entity couldn't be created (in which case the node is removed anyways).

Raytrace
--------

To support some of the stuff that involved tracing rays across nodes, a raytrace library was added--though it is very general and may be used by other mods fairly easily. The public API is as follows:

* `raytrace.trace_node_points(la, lb)`: Given endpoint vectors `la` and `lb`, returns an array of vectors representing node positions that include at least one point on this line segment.
* `raytrace.trace_node_array(la, lb)`: As above, but returns instead an array of `node` structures.
* `raytrace.trace_node_map(la, lb)`: As above, but instead returns the nodes in a mapping table which may be indexed by `tbl[x][y][z]` -> `node`. Entries only exist for points on the line segment.
