-- c_o_shield/init.lua
-- Scudi personalizzati per rank (staffranks) con swap automatico.

local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

-- 🔧 INIZIALIZZA LA TABELLA GLOBALE SUBITO!
if not c_o_shield then
  c_o_shield = {}
end

-- CONFIGURAZIONE AMMINISTRATORE

-- Imposta true/false per abilitare/disabilitare ogni scudo
-- true = scudo abilitato | false = scudo disabilitato
-- c_o_shield/init.lua
-- Custom shields for ranks (staffranks) with automatic swap.

local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

-- 🔧 INITIALIZE GLOBAL TABLE
if not c_o_shield then
  c_o_shield = {}
end


-- ️ ADMINISTRATOR CONFIGURATION

-- Set true/false to enable/disable each shield
-- true = shield enabled | false = shield disabled
local ENABLED_SHIELDS = {
  admin     = true,   -- Admin Shield
  dev       = false,  -- Developer Shield
  mod       = true,   -- Moderator Shield
  manager   = false,  -- Manager Shield
  builder   = true,   -- Builder Shield
  guardian  = false,  -- Guardian Shield
  tguardian = false,  -- T-Guardian Shield
  hacker    = false,  -- Hacker Shield
  cont      = true,   -- Contributor Shield
  noob      = false,  -- Noob Shield
  idle      = false,  -- Idle Shield
}

-- Configuration: enable or disable automatic shield addition if not present
local auto_add_shield = true

-- 0) DEPENDENT MOD CHECKS
if not armor or not armor.register_armor then
  minetest.log("error", "[" .. modname .. "] 3d_armor not found (global variable 'armor' missing).")
  return
end

local shields_list = {
  {name = "admin",     descr = S("Admin Shield"),        prot = 20},
  {name = "dev",       descr = S("Developer Shield"),    prot = 18},
  {name = "mod",       descr = S("Moderator Shield"),    prot = 15},
  {name = "manager",   descr = S("Manager Shield"),      prot = 12},
  {name = "builder",   descr = S("Builder Shield"),      prot = 14},
  {name = "guardian",  descr = S("Guardian Shield"),     prot = 30},
  {name = "tguardian", descr = S("T-Guardian Shield"),   prot = 18},
  {name = "hacker",    descr = S("Hacker Shield"),       prot = 20},
  {name = "cont",      descr = S("Contributor Shield"),  prot = 15},
  {name = "noob",      descr = S("Noob Shield"),         prot = 15},
  {name = "idle",      descr = S("Idle Shield"),         prot = 510},
}

local valid_ranks = {}

--  Register only enabled shields
for _, s in ipairs(shields_list) do
  if ENABLED_SHIELDS[s.name] then
    valid_ranks[s.name] = true
    
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
    
    minetest.log("action", "[c_o_shield] Shield registered: " .. s.name)
  else
    minetest.log("action", "[c_o_shield] Shield disabled: " .. s.name)
  end
end

local function get_rank_key(player)
  local meta = player:get_meta()
  local rank_key = (meta:get_string("staffranks:rank") or ""):lower()
  rank_key = rank_key:gsub("^%s*(.-)%s*$", "%1") -- trim

  -- If the rank is not enabled, use fallback "cont"
  if not valid_ranks[rank_key] then
    if valid_ranks["cont"] then
      return "cont"
    else
      -- If "cont" is also disabled, use the first enabled shield
      for rank, _ in pairs(valid_ranks) do
        return rank
      end
    end
  end

  return rank_key
end

local function shield_item_for_rank(rank_key)
  if not valid_ranks[rank_key] then
    -- Fallback: use the first enabled shield
    for rank, _ in pairs(valid_ranks) do
      rank_key = rank
      break
    end
  end
  return "c_o_shield:shield_" .. rank_key
end

local function is_cos_item(name)
  return type(name) == "string" and name:find("^c_o_shield:shield_") ~= nil
end

local function enforce_shield(player)
  if not player then return end
  local pname = player:get_player_name()
  if not pname or pname == "" then return end

  -- Exclude players with server privilege
  if minetest.check_player_privs(pname, {server = true}) then
    return
  end

  local rank_key = get_rank_key(player)
  minetest.log("action", "[c_o_shield] enforce_shield - player: " .. pname .. ", rank_key: " .. rank_key)
  
  local target_name = shield_item_for_rank(rank_key)
  minetest.log("action", "[c_o_shield] target_shield: " .. target_name)
  
  local target_stack = ItemStack(target_name)
  local changed = false

  --  CHECK 1: Equipped armor inventory (active slots)
  local armor_inv = minetest.get_inventory({type="detached", name=pname.."_armor"})
  
  if armor_inv then
    minetest.log("action", "[c_o_shield] Found armor inventory for " .. pname)
    
    -- Armor slots: 1=head, 2=torso, 3=legs, 4=feet, 5=shield
    for i = 1, 6 do
      local st = armor_inv:get_stack("armor", i)
      if not st:is_empty() and is_cos_item(st:get_name()) then
        local old_name = st:get_name()
        minetest.log("action", "[c_o_shield] Found shield in armor slot " .. i .. ": " .. old_name)
        
        if old_name ~= target_name then
          minetest.log("action", "[c_o_shield] Swapping equipped shield " .. old_name .. " -> " .. target_name)
          armor_inv:set_stack("armor", i, target_stack)
          changed = true
        else
          minetest.log("action", "[c_o_shield] Equipped shield is already correct: " .. old_name)
        end
        break
      end
    end
  else
    minetest.log("action", "[c_o_shield] No armor inventory found for " .. pname)
  end

  --  CHECK 2: Main inventory (non-equipped shields)
  local inv = player:get_inventory()
  if inv then
    local main_list = inv:get_list("main") or {}
    minetest.log("action", "[c_o_shield] Checking main inventory for non-equipped shields")
    
    for i = 1, #main_list do
      local st = main_list[i]
      if not st:is_empty() and is_cos_item(st:get_name()) then
        local old_name = st:get_name()
        
        if old_name ~= target_name then
          minetest.log("action", "[c_o_shield] Found non-equipped shield in main slot " .. i .. ": " .. old_name)
          minetest.log("action", "[c_o_shield] Swapping " .. old_name .. " -> " .. target_name)
          inv:set_stack("main", i, target_stack)
          changed = true
        end
      end
    end
  end

  if changed then
    armor:set_player_armor(player)
    minetest.log("action", "[c_o_shield] Armor updated for " .. pname)
  else
    minetest.log("action", "[c_o_shield] No changes needed for " .. pname)
  end
end

--  AUTOMATIC HOOK ON STAFFRANK (without modifying its code!)
minetest.register_on_mods_loaded(function()
  if minetest.get_modpath("staffranks") and staffranks then
    minetest.log("action", "[c_o_shield] Hooking into staffranks.add_rank")
    
    -- Hook on staffrank's add_rank function
    if staffranks.add_rank and type(staffranks.add_rank) == "function" then
      local orig_add_rank = staffranks.add_rank
      staffranks.add_rank = function(player_name, rankname, ...)
        minetest.log("action", "[c_o_shield] staffranks.add_rank intercepted: " .. player_name .. " -> " .. rankname)
        local result = orig_add_rank(player_name, rankname, ...)
        
        local player = minetest.get_player_by_name(player_name)
        if player then
          minetest.after(0.1, function()
            if player and player:is_player() then
              minetest.log("action", "[c_o_shield] Running enforce_shield after rank change")
              enforce_shield(player)
            end
          end)
        end
        return result
      end
    end
    
  else
    minetest.log("warning", "[c_o_shield] staffranks mod not found, automatic rank detection disabled")
  end
end)

-- Player join + safety timer
minetest.register_on_joinplayer(function(player)
  if staffranks and staffranks.init_nametag then
    pcall(staffranks.init_nametag, player)
  end

  minetest.after(0.2, function()
    if player and player:is_player() then
      minetest.log("action", "[c_o_shield] Player joined: " .. player:get_player_name())
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

local valid_ranks = {}

--  Registra solo gli scudi abilitati
for _, s in ipairs(shields_list) do
  if ENABLED_SHIELDS[s.name] then
    valid_ranks[s.name] = true
    
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
    
    minetest.log("action", "[c_o_shield] Shield registered: " .. s.name)
  else
    minetest.log("action", "[c_o_shield] Shield disabled: " .. s.name)
  end
end

local function get_rank_key(player)
  local meta = player:get_meta()
  local rank_key = (meta:get_string("staffranks:rank") or ""):lower()
  rank_key = rank_key:gsub("^%s*(.-)%s*$", "%1") -- trim

  -- Se il rank non è abilitato, usa il fallback "cont"
  if not valid_ranks[rank_key] then
    if valid_ranks["cont"] then
      return "cont"
    else
      -- Se nemmeno "cont" è abilitato, cerca il primo scudo abilitato
      for rank, _ in pairs(valid_ranks) do
        return rank
      end
    end
  end

  return rank_key
end

local function shield_item_for_rank(rank_key)
  if not valid_ranks[rank_key] then
    -- Fallback: usa il primo scudo abilitato
    for rank, _ in pairs(valid_ranks) do
      rank_key = rank
      break
    end
  end
  return "c_o_shield:shield_" .. rank_key
end

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

  local rank_key = get_rank_key(player)
  minetest.log("action", "[c_o_shield] enforce_shield - player: " .. pname .. ", rank_key: " .. rank_key)
  
  local target_name = shield_item_for_rank(rank_key)
  minetest.log("action", "[c_o_shield] target_shield: " .. target_name)
  
  local target_stack = ItemStack(target_name)
  local changed = false

  --  CONTROLLO 1: Inventario armor equipaggiato (slot attivi)
  local armor_inv = minetest.get_inventory({type="detached", name=pname.."_armor"})
  
  if armor_inv then
    minetest.log("action", "[c_o_shield] Found armor inventory for " .. pname)
    
    -- Slot armor: 1=head, 2=torso, 3=legs, 4=feet, 5=shield
    for i = 1, 6 do
      local st = armor_inv:get_stack("armor", i)
      if not st:is_empty() and is_cos_item(st:get_name()) then
        local old_name = st:get_name()
        minetest.log("action", "[c_o_shield] Found shield in armor slot " .. i .. ": " .. old_name)
        
        if old_name ~= target_name then
          minetest.log("action", "[c_o_shield] Swapping equipped shield " .. old_name .. " -> " .. target_name)
          armor_inv:set_stack("armor", i, target_stack)
          changed = true
        else
          minetest.log("action", "[c_o_shield] Equipped shield is already correct: " .. old_name)
        end
        break
      end
    end
  else
    minetest.log("action", "[c_o_shield] No armor inventory found for " .. pname)
  end

  --  CONTROLLO 2: Inventario principale (scudi non equipaggiati)
  local inv = player:get_inventory()
  if inv then
    local main_list = inv:get_list("main") or {}
    minetest.log("action", "[c_o_shield] Checking main inventory for non-equipped shields")
    
    for i = 1, #main_list do
      local st = main_list[i]
      if not st:is_empty() and is_cos_item(st:get_name()) then
        local old_name = st:get_name()
        
        if old_name ~= target_name then
          minetest.log("action", "[c_o_shield] Found non-equipped shield in main slot " .. i .. ": " .. old_name)
          minetest.log("action", "[c_o_shield] Swapping " .. old_name .. " -> " .. target_name)
          inv:set_stack("main", i, target_stack)
          changed = true
        end
      end
    end
  end

  if changed then
    armor:set_player_armor(player)
    minetest.log("action", "[c_o_shield] Armor updated for " .. pname)
  else
    minetest.log("action", "[c_o_shield] No changes needed for " .. pname)
  end
end

--  HOOK AUTOMATICO SU STAFFRANK (senza modificare il suo codice!)
minetest.register_on_mods_loaded(function()
  if minetest.get_modpath("staffranks") and staffranks then
    minetest.log("action", "[c_o_shield] Hooking into staffranks.add_rank")
    
    -- Hook sulla funzione add_rank di staffrank
    if staffranks.add_rank and type(staffranks.add_rank) == "function" then
      local orig_add_rank = staffranks.add_rank
      staffranks.add_rank = function(player_name, rankname, ...)
        minetest.log("action", "[c_o_shield] staffranks.add_rank intercepted: " .. player_name .. " -> " .. rankname)
        local result = orig_add_rank(player_name, rankname, ...)
        
        local player = minetest.get_player_by_name(player_name)
        if player then
          minetest.after(0.1, function()
            if player and player:is_player() then
              minetest.log("action", "[c_o_shield] Running enforce_shield after rank change")
              enforce_shield(player)
            end
          end)
        end
        return result
      end
    end
    
  else
    minetest.log("warning", "[c_o_shield] staffranks mod not found, automatic rank detection disabled")
  end
end)

-- join + timer di sicurezza
minetest.register_on_joinplayer(function(player)
  if staffranks and staffranks.init_nametag then
    pcall(staffranks.init_nametag, player)
  end

  minetest.after(0.2, function()
    if player and player:is_player() then
      minetest.log("action", "[c_o_shield] Player joined: " .. player:get_player_name())
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
