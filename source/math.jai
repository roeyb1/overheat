// Axis aligned bounding box
AABB :: struct  {
    min: Vector2;
    max: Vector2;
}

Line_Segment :: struct {
    start: Vector2;
    end: Vector2;
}

Ray :: struct {
    start: Vector2;
    dir: Vector2;
}

// returns true if the bounding box contains the vector
is_inside :: (bounds: AABB, vec: Vector2) -> bool {
    return  (vec.x >= bounds.min.x && vec.x <= bounds.max.x) &&
            (vec.y >= bounds.min.y && vec.y <= bounds.max.y);
}

intersects :: (a: AABB, b: AABB) -> bool {
    if a.max.x < b.min.x || a.min.x > b.max.x then return false;
    if a.max.y < b.min.y || a.min.y > b.max.y then return false;
    return true;
}

make_bounds :: (center: Vector2, extent: Vector2) -> AABB {
    half_extent := extent / 2.;
    return .{min = center - half_extent, max = center + half_extent};
}

translate:: (bounds: AABB, translation: Vector2) -> AABB {
    return .{min = bounds.min + translation, max = bounds.max + translation };
}

get_angle :: (vec: Vector2) -> float {
    return atan2(vec.x, vec.y);
}

cross_product :: (a: Vector2, b: Vector2) -> float {
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
