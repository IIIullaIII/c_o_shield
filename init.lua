local S = minetest.get_translator(minetest.get_current_modname())

local shields_list = {
    {name = "admin",       descr = S("Supreme Admin Shield"),  prot = 20},
    {name = "staff",       descr = S("Official Staff Shield"), prot = 15},
    {name = "contributor", descr = S("Contributor Shield"),    prot = 12},
    {name = "builder",     descr = S("Builder Shield"),        prot = 10},
}
for _, s in ipairs(shields_list) do
    armor:register_armor("c_o_shield:shield_" .. s.name, {
        description = s.descr,
        -- Icona quadrata pulita per l'hotbar
        inventory_image = "c_o_shield_inv_" .. s.name .. ".png",
        
        -- Texture HD che "veste" il modello 3D sul giocatore
        texture = "c_o_shield_shield_" .. s.name .. ".png",
        
        -- Questa immagine DEVE avere lo scudo piccolo e centrato per non coprire tutto
        preview = "c_o_shield_shield_" .. s.name .. "_preview.png",
        
        groups = {
            armor_shield = 1,
            armor_heal = 0,
            armor_use = 0,
            -- Fondamentale per evitare che 3D Armor generi icone automatiche sballate
            armor_name = 1,
        },
        armor_groups = {fleshy = s.prot},
        damage_groups = {cracky = 2, snappy = 1, level = 3},
    })
end
