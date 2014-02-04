minetest_explosives
===================

Brings big booms to [Minetest](minetest.net) :D

Currently a Work-in-Progress; a stable and usable API should be available soon!

Currently supports:

* All kinds of TNT and derived TNTs with equal power (1 being the "usual" power).
* The unused (as far as I know) `on_blast` function in node defs, with the usual semantics. (TODO: Let it dynamically provide blast resistance values...)
* A fairly fast, efficient, and stable explosion propagation function (`explosives.general_explode`) that may be called from any explosive and customized with a modification callback (`explosives.general_modfunc`, usually).
* Item drops, which may happen only by chance.
* Easy per-game configuation of various performance and tuning parameters :D

Will eventually support:

* Different modfuncs (for things like fission or energy weapons).
* An explosion algorithm that avoids the "wrap-around" currently afforded by unrestricted recursion (and makes it less ray-like).
* Entity damage (soon!)
* Better textures, hopefully :P

API
---

This is very likely to change, so don't depend on it:

* `explosives.general_explode(pos, power, modfunc, param, cache, depth, lastpos, drops)`: Explode at `pos` with `power` (1 being the usual TNT). All other arguments are optional, in particular:

  * `modfunc` is the modification func called at each position with each node, at most once per position, to cause explosion effects (damage) to blocks. The default implementation is `explosives.general_modfunc`, which handles on_blast and item drop logic.
  * `param` is a parameter that may be passed to a custom `modfunc`. `explosives.general_modfunc` doesn't use it.
  * `cache` is the position visit cache and should not be passed.
  * `depth` is the recursion level and should not be passed.
  * `lastpos` is the recursion parent's `pos` and should not be passed.
  * `drops` is the number of entities spawned so far and should not be passed.
  
* `explosives.general_modfunc(pos, node, power, drops, param)`: Does the usual logic for explosion modification, but this implementation may be overriden by passing another function as a `modfunc` to `explosives.general_explode`. The parameters are defined as follows:

  * `pos` is the position being processed.
  * `node` is the result of `minetest.get_node(pos)`.
  * `power` is the current power (1 being the power of the epicenter of usual TNT).
  * `drops` is the current number of drops.
  * `param` is the `param` passed to `explosives.general_explode`.

  The function must return a double `power, drops` where `power` is the resulting power after blast resistance is computed, and `drops` is the sum of the parameter `drops` and whatever additional drops were spawned.
  
  The default implementation defers to on_blast if it can; otherwise, it gets the drops, spawns some of them, removes the node, and returns the appropriate power based on the `blast_resistance` group.
  
For block developers, the following groups are of interest:

* `blast_resistance`: If nonzero, specifies the blast resistance of this block (how much explosive damage it absorbs). If zero (or not a member), `explosives.DEFAULT_RESISTANCE` is assumed.
* `explosive`: If nonzero, the block is an explosive, and may be triggered by igniters (fire, lava) or mesecons (TODO!). The value specifies the explosive power on detonation. (TODO: Provide a way to customize the appearance of the explosive entity...)

Entity developers might want to know about some attributes that may be stored on the `explosives:primed_tnt` `LuaEntitySAO`:

* `power`: The `power` parameter to `explosives.general_explode`.
* `boomtime`: Seconds until explosion; decreased in `on_step`.
* `modfunc`: The `modfunc` parameter to `explosives.general_explode`.
* `param`: The `param` parameter to `explosives.general_explode`.
