Position :: struct @Component {
    using #as value: Vector2;
}

Velocity :: struct @Component {
    using #as value: Vector2;
}

Name :: struct @Component {
    name: string;
}

Dead :: struct @Component {}

/** Entities with the Transient component will be destroyed automatically before the next frame */
Transient :: struct @Component {}

destroy_transients :: (q: Query) {
    for 0..q.count-1 {
        destroy_entity(q.world, q.entities[it]);
    }
} @System(PreUpdate) @Write() @Read(Transient)