--Fast voxel raytrace library
--(for explosives, but feel free to use this elsewhere!)
--by Grissess

--[[
Alright, I'm going to think out loud here. You can skip this if you're not into theory :P

To start off, let's define this problem:

	Find all of the voxels which contain at least one point in a given line.

This particular description is problematic; it's more than a little difficult to determine if
one arbitrary point is inside of a volume--especially since a line can be considered to be a
(countably) infinite set of points. Consider the following diagram:

	x---.....____               |```| V
	             ````------.....|.__|_
	                                  ````----x L

In this particular case, the probability of selecting the point inside of this line at random
from a continuous uniform distribution of points along line segment L is

	    ||S||
	P = ----- (1)
	    ||L||

where ||X|| is the length operator, and S represents the (small) line segment in V. As S
approaches being a point, ||S||->0, and the limit of P in this instance is 0! Even for
practical purposes, especially with long lines (large ||L||), the number of samples required
would be overbearing, and--assuming n samples were chosen at equidistant points--the "hit"
probability for a small S would be

	        ||S||
	P = n * ----- (2)
	        ||L||

(The correspondence to (1) above is not coincidental; this solution is essentially equivalent
to subdivinding L into n unique line segments.)

Choosing a value for ||S|| and P, we can solve for n algebraically:

	        ||L||
	n = P * ----- (3)
	        ||S||

where ||L|| is assumed to be given from the problem, and P is the probability that we'd like
to guarantee of hitting V (across size ||S||). n is, hence, linearly dependent on P, and
*inversely proportional* to ||S||; thus, lim (||S||->0) n=infinity.

There exists a better way of doing this, of course--if we know that V is bounded by some set
of planes P, we can (almost trivially) find the intersections between L and P, as this next
diagram shows:

	__________________|______________________|_____________ P(4)
	x---....____      |                   V  |
	            ````--|-...___ S             |
	__________________|_______````---....____|_____________ P(2)
	                  |                     `|``----x L
	                 P(1)                   P(3)

This method gives a direct, closed-form solution for finding the endpoints of S as intersections
of the planes that bound V (in 3R space, there would be six such planes). The actual vector
math behind this is fairly straightforward:

	p = L_a + (L_b-L_a)*u (4)

	(p - p0) . n = 0 (5)

(4) represents the equation of a line between points L_a and L_b (both vectors). * is scalar
multiplication, and u is the independent (scalar). For our purposes, we consider only the
segment between L_a and L_b; therefore, valid solutions constitute only u in [0, 1]. (5)
represents the equation of a plane with normal vector n and constant point p_0, where .
is the dot (scalar) product of the vectors. Performing substitution, we get:

	(L_a + (L_b-L_a)*u - p0) . n = k (6)

	    (p0 - L_a) . n
	u = -------------- (7)
	    (L_b-L_a) . n

Before evaluating (7) outright, however, it must be ensured that (L_b-L_a) . n is not 0; if
it is, and (L_a - p0) . n = 0, then the line is entirely within the plane, otherwise it is
parallel to (and outside of) the plane. These are the only two edge conditions.

Assuming that is done, we should get a scalar value for u, which--again--must be in [0, 1]
to lie on segment L. If it does, we may consider it one of the intersection points on L
bounding S (and hence V).

With this knowledge, we can rephrase this problem into an equivalent problem:

	Find all of the voxel faces that intersect L.

And, indeed, this one is much easier because of a closed-form solution.

Additionally, on a grid, it can be proven (though I shall omit this here) that, given a set
of n intersections, we can expect to have hit n+1 voxels. Essentially, this follows from the
fact that the existence of an S implies that there exists at least one point on S in V (and,
since S is a subset of L, at least one point on L in V). an informal introduction, I'll
provide the following diagram:

	___|______|______|______|__
	   |      |      |      |
	   |      |      |      |
	___|______|______|______|__
	   |      |      |      |
	   | S    |      |      |
	x-..._____|______|______|__
	   | ```---___   |      |
	   |   S  | S ```---x   |
	___|______|______|______|__

In this case, we have three S which share endpoints; thus, we have four intersections, and,
including the voxels containing the line endpoints, we have five voxels. This works even
when the segment is contained entirely inside one voxel--there will be zero intersections,
and, thus, one voxel.

The only remaining problem is how to get the appropriate set of planes--in voxel maps, there
may be a huge number of them! Luckily, the consistent axis-aligned normals (spacing aside) in
these voxel maps permits us a fast shortcut: simply find all of the planes that go through the
axis-aligned box formed by the lines' two endpoints. Equivalently:

	Let p0_i = k * n for all k in [(L_a . n), (L_b . n)] union integers. (8)

(The union with integers is relevant in out context because our coordinates are nicely aligned
with the integers; in situations where the spacing may be different, a different definition
that takes the spacing into account would be required.)

In 3R space (again), there will be three such axis-aligned normals; namely i=<1, 0, 0>,
j=<0, 1, 0>, and k=<0, 0, 1>, which reduce the dot products to simple selection of the
proper coordinate.

There exists one more problem: getting the actual V's (voxels) that contain S. This is
pretty simple: find the midpoint of S, and see which voxel it's in :P . This requires us to
iterate over pairs of intersections, and, where there are n intersections, there are n-1
such pairs; including the voxels containing the endpoints, there will be n+1 such results--
another informal proof of the theorem above :P

So...that's it :D . The rest of this file is dedicated to the (probably comparatively small)
algorithm described exactly above. So, let's get to some gaming!

UPDATE: So, apparently, after some careful looking at the debug screen, I've deduced that...
well...Minetest is weird. The separation planes aren't at integers, but rather at
*exact halves*; the integers represent the center of the node. The code below is updated to
take this into account, but the above explanation is not. It's not much of an effect; the
only thing that changes is the "union integers" part of (8), as explained.
]]--

raytrace={}

--You didn't implement the dot product in vector? Tsk, tsk...

if not vector.dot then
	function vector.dot(va, vb)
		return va.x*vb.x+va.y*vb.y+va.z*vb.z
	end
end

--vector.round, but not vector.floor? I am ever so slightly disappoint...

if not vector.floor then
	function vector.floor(v)
		return vector.new(math.floor(v.x), math.floor(v.y), math.floor(v.z))
	end
end

--local ptos=minetest.pos_to_string

function raytrace.line_point(la, lb, u)
	--(4)
	return vector.add(la, vector.multiply(vector.subtract(lb, la), u))
end

function raytrace.line_midpoint(a, b)
	return raytrace.line_point(a, b, 0.5)
end

function raytrace.isct_line_plane(la, lb, p0, n, unbounded, asu)
	local dir=vector.subtract(lb, la)
	--print("Raytrace DEBUG: Line "..ptos(la).."->"..ptos(lb).." plane @"..ptos(p0).." norm "..ptos(n))
	--(7)
	local d=vector.dot(dir, n)
	if d==0 then return nil end --Also not considering line-in-plane
	local u=vector.dot(vector.subtract(p0, la), n)/d
	--print("...U="..tostring(u))
	if (u<0 or u>1) and not unbounded then return nil end --Not on segment
	if asu then
		return u
	else
		return raytrace.line_point(la, lb, u)
	end
end

raytrace.FUNDAMENTAL_UNITS={x=vector.new(1, 0, 0), y=vector.new(0, 1, 0), z=vector.new(0, 0, 1)}
raytrace.COMPONENTS={"x", "y", "z"}

function raytrace.all_intersections(la, lb, asu)
	local isctu={}
	
	for _, cmp in ipairs(raytrace.COMPONENTS) do
		--(8)
		local ka=math.floor(la[cmp])
		local kb=math.floor(lb[cmp])
		local n=raytrace.FUNDAMENTAL_UNITS[cmp]
		for k=math.min(ka, kb)-1, math.max(ka, kb)+1 do --Added some range just to be sure we cover all of the planes
			local res=raytrace.isct_line_plane(la, lb, vector.multiply(n, k+0.5), n, false, true)
			if res then
				table.insert(isctu, res)
			end
		end
	end
	
	table.sort(isctu)
	if asu then
		return isctu
	else
		local pts={}
		for _, u in ipairs(isctu) do
			table.insert(pts, raytrace.line_point(la, lb, u))
		end
		return pts
	end
end

function raytrace.node_at(pos)
	return minetest.get_node(vector.round(pos))
end

--Public API

function raytrace.trace_node_points(la, lb)
	local iscts=raytrace.all_intersections(la, lb)
	local pts={}
	
	local fa=vector.round(la)
	local fb=vector.round(lb)
	
	table.insert(pts, fa)
	
	if #iscts>1 then
		for i=1,#iscts-1 do
			table.insert(pts, vector.round(raytrace.line_midpoint(iscts[i], iscts[i+1])))
		end
	end
	
	
	if not vector.equals(fa, fb) then
		table.insert(pts, fb)
	end
	
	return pts
end

function raytrace.trace_node_array(la, lb)
	local pts=raytrace.trace_node_points(la, lb)
	local nodes={}
	
	for _, pt in ipairs(pts) do
		table.insert(nodes, minetest.get_node(pt))
	end
	
	return nodes
end

function raytrace.trace_node_map(la, lb)
	local pts=raytrace.trace_node_points(la, lb)
	local nodes={}
	
	for _, pt in ipairs(pts) do
		if not nodes[pt.x] then
			nodes[pt.x]={}
		end
		if not nodes[pt.x][pt.y] then
			nodes[pt.x][pt.y]={}
		end
		nodes[pt.x][pt.y][pt.z]=minetest.get_node(pt)
	end
	
	return nodes
end