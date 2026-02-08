-- c_o_shield/init.lua
-- Scudi personalizzati per rank (staffranks) con swap automatico.
-- FIX: usa staffranks:rank (chiave interna) invece di staffranks:rank_prefix (testo visuale/AFK).
-- FIX: esclude chi ha il privilegio "server" (non viene mai swappato).
-- Compatibile con 3d_armor (armor:register_armor).

local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

-- Configurazione: abilita o disabilita l'aggiunta automatica dello scudo se non presente
local auto_add_shield = true  -- true = abilita automatic false = disable


-- 0) CONTROLLI MOD DIPENDENTI

if not armor or not armor.register_armor then
  minetest.log("error", "[" .. modname .. "] 3d_armor non trovato (variabile globale 'armor' assente).")
  return
end


local shields_list = {
  {name = "owner",     descr = S("Owner Shield"),        prot = 20},
  {name = "admin",     descr = S("Admin Shield"),        prot = 20},
  {name = "dev",       descr = S("Developer Shield"),    prot = 18},
  {name = "mod",       descr = S("Moderator Shield"),    prot = 15},
  {name = "manager",   descr = S("Manager Shield"),      prot = 17},
  {name = "builder",   descr = S("Builder Shield"),      prot = 12},
  {name = "guardian",  descr = S("Guardian Shield"),     prot = 14},
  {name = "tguardian", descr = S("T-Guardian Shield"),   prot = 11},
  {name = "hacker",    descr = S("Hacker Shield"),       prot = 20},
  {name = "cont",      descr = S("Contributor Shield"),  prot = 10},
  {name = "noob",      descr = S("Noob Shield"),         prot = 5},
  {name = "Idle",      descr = S("Idle Shield"),         prot = 5},
}

-- Indice rapido: rank_key -> true
local valid_ranks = {}
for _, s in ipairs(shields_list) do valid_ranks[s.name] = true end


for _, s in ipairs(shields_list) do
  armor:register_armor("c_o_shield:shield_" .. s.name, {
    description = s.descr,
    inventory_image = "c_o_shield_inv_" .. s.name .. ".png",
    texture = "c_o_shield_shield_" .. s.name .. ".png",
    preview = "c_o_shield_shield_" .. s.name .. "_preview.png",
    groups = {
      armor_shield = 1,
      armor_heal = 0,
      armor_use = 0,
      armor_name = 1,
      not_in_creative_inventory = 0,
    },
    armor_groups = {fleshy = s.prot},
    damage_groups = {cracky = 2, snappy = 1, level = 3},
  })
end



-- staffranks:rank è la chiave interna affidabile (es: "admin", "cont", ...)

local function get_rank_key(player)
  local meta = player:get_meta()

  local rank_key = (meta:get_string("staffranks:rank") or ""):lower()
  rank_key = rank_key:gsub("^%s*(.-)%s*$", "%1") -- trim

  if valid_ranks[rank_key] then
    return rank_key
  end

  -- Fallback sicuro
  return "cont"
end

local function shield_item_for_rank(rank_key)
  if not valid_ranks[rank_key] then
    rank_key = "cont"
  end
  return "c_o_shield:shield_" .. rank_key
end


-- Cambia SOLO scudi di questa mod (c_o_shield:shield_*)

local function is_cos_item(name)
  return type(name) == "string" and name:find("^c_o_shield:shield_") ~= nil
end

local function enforce_shield(player)
  if not player then return end
  local pname = player:get_player_name()
  if not pname or pname == "" then return end

  -- Escludi chi ha il privilegio server
  if minetest.check_player_privs(pname, {server = true}) then
    return
  end

  local inv = player:get_inventory()
  if not inv then return end

  local rank_key = get_rank_key(player)
  local target_name = shield_item_for_rank(rank_key)
  local target_stack = ItemStack(target_name)

  local changed = false

  -- Slot ARMOR
  local armor_list = inv:get_list("armor") or {}

  local found_cos_shield = false
  for i = 1, #armor_list do
    local st = armor_list[i]
    if not st:is_empty() and is_cos_item(st:get_name()) then
      found_cos_shield = true
      -- Rimuovi lo scudo attuale prima di impostare quello nuovo
      inv:set_stack("armor", i, ItemStack(""))
      inv:set_stack("armor", i, target_stack)
      changed = true
      break
    end
  end

  -- Aggiunta automatica se abilitata e scudo non trovato
  if not found_cos_shield and auto_add_shield then
    for i = 1, #armor_list do
      local st = armor_list[i]
      if st:is_empty() then
        inv:set_stack("armor", i, target_stack)
        changed = true
        break
      end
    end
  end

  -- Inventario MAIN
  local main_list = inv:get_list("main") or {}
  for i = 1, #main_list do
    local st = main_list[i]
    if not st:is_empty() and is_cos_item(st:get_name()) and st:get_name() ~= target_name then
      inv:set_stack("main", i, target_stack)
      changed = true
    end
  end

  -- Oggetto in mano
  local wield = player:get_wielded_item()
  if not wield:is_empty() and is_cos_item(wield:get_name()) and wield:get_name() ~= target_name then
    player:set_wielded_item(target_stack)
    changed = true
  end

  if changed then
    -- Aggiorna armatura subito dopo la modifica
    armor:set_player_armor(player)
  end
end


-- (Se staffranks non esiste, nessun errore.)

local function hook_staffranks()
  if not minetest.get_modpath("staffranks") then return end
  if not staffranks then return end

  if staffranks.add_rank and type(staffranks.add_rank) == "function" then
    local orig_add_rank = staffranks.add_rank
    staffranks.add_rank = function(player_name, rankname, ...)
      local ret = orig_add_rank(player_name, rankname, ...)
      local pl = minetest.get_player_by_name(player_name)
      if pl then enforce_shield(pl) end
      return ret
    end
  end

  if staffranks.clear_rank and type(staffranks.clear_rank) == "function" then
    local orig_clear_rank = staffranks.clear_rank
    staffranks.clear_rank = function(player_name, ...)
      local ret = orig_clear_rank(player_name, ...)
      local pl = minetest.get_player_by_name(player_name)
      if pl then enforce_shield(pl) end
      return ret
    end
  end
end

hook_staffranks()

-- join + timer di sicurezza leggero

minetest.register_on_joinplayer(function(player)
  if staffranks and staffranks.init_nametag then
    pcall(staffranks.init_nametag, player)
  end

  minetest.after(0.2, function()
    if player and player:is_player() then
      enforce_shield(player)
    end
  end)
end)

local t = 0
minetest.register_globalstep(function(dtime)
  t = t + dtime
  if t < 3 then return end
  t = 0

  for _, player in ipairs(minetest.get_connected_players()) do
    enforce_shield(player)
  end
end)
