// Axis aligned bounding box
AABB :: struct  {
    min: Vector2;
    max: Vector2;
}

operator== :: (a: AABB, b: AABB) -> bool {
    return a.min == b.min && a.max == b.max;
}

Line_Segment :: struct {
    start: Vector2;
    end: Vector2;
}

Ray :: struct {
    start: Vector2;
    dir: Vector2;
}

make_aabb :: inline (center: Vector2, extent: Vector2) -> AABB {
    half_extent := extent / 2.;
    return .{min = center - half_extent, max = center + half_extent};
}

// returns true if the bounding box contains the vector
is_inside :: inline (using box: AABB, vec: Vector2) -> bool {
    return  (vec.x >= min.x && vec.x <= max.x) &&
            (vec.y >= min.y && vec.y <= max.y);
}

intersects :: (a: AABB, b: AABB) -> bool {
    if a.max.x < b.min.x || a.min.x > b.max.x then return false;
    if a.max.y < b.min.y || a.min.y > b.max.y then return false;
    return true;
} @NoProfile

operator+ :: inline (a: AABB, b: AABB) -> AABB {
    return .{min(a.min, b.min), max(a.max, b.max)};
} @NoProfile

area :: inline (aabb: AABB) -> float {
    return (aabb.max.x - aabb.min.x) * (aabb.max.y - aabb.min.y);
} @NoProfile

surface_area :: inline (aabb: AABB) -> float {
    return (aabb.max.x - aabb.min.x) * (aabb.max.y - aabb.min.y);
} @NoProfile

merge :: inline (a: AABB, b: AABB) -> AABB {
    return a + b;
}

translate:: inline (using box: AABB, translation: Vector2) -> AABB {
    return .{min = min + translation, max = max + translation };
}

box_center :: inline (using box: AABB) -> Vector2 {
    return .{ (min.x + max.x / 2.), (min.y + max.y) / 2. };
}

box_extent :: inline (using box: AABB) -> Vector2 {
    return max - min;
}

closest_point_on_aabb :: (using box: AABB, point: Vector2) -> Vector2, float{
    min_dist := abs(point.x - min.x);
    point_on_bounds := Vector2.{min.x, point.y};

    d := abs(max.x - point.x);
    if d < min_dist {
        min_dist = d;
        point_on_bounds = Vector2.{max.x, point.y};
    }
    d = abs(max.y - point.y);
    if d < min_dist {
        min_dist = d;
        point_on_bounds = Vector2.{point.x, max.y};
    }
    d = abs(min.y - point.y);
    if d < min_dist {
        min_dist = d;
        point_on_bounds = Vector2.{point.x, min.y};
    }

    return point_on_bounds, min_dist;
}

minkowsky_difference :: (a: AABB, b: AABB) -> AABB {
    top_left := a.min - b.max;
    extent := box_extent(a) + box_extent(b);
    return make_aabb(top_left + (extent / 2.), extent);
}

get_angle :: inline (vec: Vector2) -> float {
    return atan2(vec.x, vec.y);
}

cross_product :: inline (a: Vector2, b: Vector2) -> float {
    return a.x * b.y - b.x * a.y;
}

find_intersection :: (ray: Ray, line_seg: Line_Segment, $epsilon := 0.000001) -> float, bool {
    v1 := ray.start - line_seg.start;
    v2 := line_seg.end - line_seg.start;
    v3 := Vector2.{-ray.dir.y, ray.dir.x};

    assert(abs(length(ray.dir) - 1.) < epsilon, "Ray has non-unit length %", length(ray.dir));

    dot := dot_product(v2, v3);
    if (abs(dot) < epsilon)
        return 0xffff_ffff, false;

    t1 := cross_product(v2, v1) / dot;
    t2 := dot_product(v1, v3) / dot;

    if (t1 >= 0.0 && (t2 >= 0.0 && t2 <= 1.0))
        return t1, true;

    return 0xffff_ffff, false;
}

find_intersection :: (a: Line_Segment, b: Line_Segment) -> Vector2 {
    // From http://paulbourke.net/geometry/lineline2d/
    s :=    ((b.end.x - b.start.x) * (a.start.y - b.start.y) - (b.end.y - b.start.y) * (a.start.x - b.start.x))
            / ((b.end.y - b.start.y) * (a.end.x - a.start.x) - (b.end.x - b.start.x) * (a.end.y - a.start.y));
    return .{a.start.x + s * (a.end.x - a.start.x), a.start.y + s * (a.end.y - a.start.y)};
}

radians :: inline (angle: float) -> float {
    return (PI / 180.) * angle;
}

degrees :: inline (angle: float) -> float {
    return (180. / PI) * angle;
}

equals :: inline (a: float, b: float, ERROR_MARGIN := 0.0001) -> bool {
    return abs(a - b) <= ERROR_MARGIN;
}

round_up_power_2 :: (a: int) -> int {
    a -= 1;
    a |= a >> 1;
    a |= a >> 2;
    a |= a >> 4;
    a |= a >> 8;
    a |= a >> 16;
    return a + 1;
}

round_up_power_2 :: (a: float) -> float {
    return pow(2., ceil(log(a) / log(2.)));
}

round_up_multiple_of_n :: (a: int, n: int) -> int {
    if n == 0 then return a;

    remainder := abs(a) % n;
    if remainder == 0 then return a;
    if a < 0 return -(abs(a) - remainder);
    else return a + n - remainder;
}

round_up_multiple_of_n :: (a: float, n: float) -> float {
    return ifx n == 0 then a else ceil(a / n) * n;
}

#load "aabb_tree.jai";