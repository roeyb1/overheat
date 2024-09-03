

//@TODO this should be generated code or something
Fragment_List_Indecies :: enum {
    PROJECTILE;
    TOUCH;
    DAMAGE;
}

#if SERVER {
//make sure the indecies here match the fragment list indecies array
FRAGMENT_LIST :: (world: *World, skill: Entity).[add_projectile,add_touch,add_damage];

}
#load "skill_fragments/damage.jai";
#load "skill_fragments/touch.jai";
#load "skill_fragments/projectile.jai";