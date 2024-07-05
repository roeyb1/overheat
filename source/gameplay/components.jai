Position :: struct @Component {
    using #as value: Vector2; @Sync @Interp
}

lerp :: (a: Position, b: Position, alpha: float) -> Position {
    return .{lerp(a.value, b.value, alpha)};
}

Velocity :: struct @Component {
    using #as value: Vector2; @Sync
}

Name :: struct @Component {
    name: string;
}

/** Entities with the Transient component will be destroyed automatically before the next frame */
Transient :: struct @Component {}

destroy_transients :: (q: Query) {
    for 0..q.count-1 {
        destroy_entity(q.world, q.entities[it]);
    }
} @System(PreUpdate) @Write() @Read(Transient)