Status_Component :: struct {
    is_alive: bool;

    maximum_health: float;
    current_health: float;
    maximum_energy: float;
    current_energy: float;

    movement_speed: float;
}

initialize_status_component :: (entity_status_component: *Status_Component, $status_component_type: Type){
    status_component : status_component_type;
    <<entity_status_component = status_component;
}

update_status_component :: (using status_component: *Status_Component){
    if current_health <= 0 {
        is_alive = false;
    }
}

add_health :: (using status_component: *Status_Component,amount: float){
    status_component.current_health = max(current_health + amount,maximum_health);
}

add_energy :: (using status_component: *Status_Component,amount: float){
    status_component.current_energy = max(current_energy + amount,maximum_energy);
}

Player_Status_Component :: struct {
    using #as status_component : Status_Component;
    is_alive = true;

    maximum_health = 100;
    maximum_energy = 100;

    movement_speed = 5;
}

Goblin_Status_Component :: struct {
    using #as status_component : Status_Component;
    is_alive = true;

    maximum_health = 50;
    maximum_energy = 100;

    movement_speed = 3;
}

test_status_component :: () -> bool {
    //test applying status component  probably also delete the created player idk
    {
        test_status_component: Status_Component;
        player_test: Player_Status_Component;
        goblin_test: Goblin_Status_Component;
        initialize_status_component(*test_status_component,Player_Status_Component);
        assert(test_status_component.maximum_health == player_test.maximum_health);

        initialize_status_component(*test_status_component,Goblin_Status_Component);
        assert(test_status_component.maximum_health == goblin_test.maximum_health);
    }
    return true;
}@UnitTest