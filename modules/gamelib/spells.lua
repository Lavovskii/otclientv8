SpelllistSettings = {
  ['Default'] = {
    iconFile = '/images/game/spells/defaultspells',
    iconSize = {width = 32, height = 32},
    spellListWidth = 210,
    spellWindowWidth = 550,
    spellOrder = {'Antidote', 'Antidote Rune', 'Berserk', 'Blood Rage', 'Cancel Invisibility', 'Challenge', 'Chameleon', 'Charge', 'Creature Illusion', 'Death Strike', 'Desintegrate', 'Destroy Field', 'Divine Caldera', 'Divine Healing', 'Divine Missile', 'Druid14k', 'Druid24k', 'Druid30k', 'Druid34k', 'Druid60k', 'Druid70k', 'Druid75k', 'Enchant Party', 'Energy Beam', 'Energy Field', 'Energy Strike', 'Energy Wall', 'Energy Wave', 'Eternal Winter', 'Ethereal Spear', 'Exevo Trap', 'Explosion', 'Fierce Berserk', 'Find Person', 'Fire Field', 'Fire Wall', 'Fire Wave', 'Fireball', 'Firebomb', 'Flame Strike', 'Freeze Crystal', 'Freeze Shard', 'Great Energy Beam', 'Great Fireball', 'Great Light', 'Groundshaker', 'Haste', 'Heal Friend', 'Heal Party', 'Healing Rune', 'Heavy Magic Missile', 'Hells Core', 'Holy Missile', 'Ice Strike', 'Ice Wave', 'Icicle', 'Intense Healing', 'Intense Healing Rune', 'Invisibility', 'Knight12k', 'Knight14k', 'Knight1k', 'Knight20k', 'Knight24k', 'Knight30k', 'Knight34k', 'Knight3k', 'Knight40k', 'Knight4k', 'Knight50k', 'Knight60k', 'Knight6k', 'Knight70k', 'Knight75k', 'Levitate', 'Light', 'Light Healing', 'Light Magic Missile', 'Mage12k', 'Mage1k', 'Mage20k', 'Mage2k', 'Mage3k', 'Mage40k', 'Mage4k', 'Mage50k', 'Mage5k', 'Mage6k', 'Magic Rope', 'Magic Shield', 'Magic Wall', 'Mass Healing', 'Mega Super Sd', 'Paladin12k', 'Paladin14k', 'Paladin1k', 'Paladin20k', 'Paladin24k', 'Paladin2k', 'Paladin30k', 'Paladin34k', 'Paladin3k', 'Paladin40k', 'Paladin50k', 'Paladin60k', 'Paladin6k', 'Paladin70k', 'Paladin75k', 'Paralyze', 'Poison Bomb', 'Poison Field', 'Poison Wall', 'Poisoned Rune', 'Protect Party', 'Protector', 'Rage Of The Skies', 'Sharpshooter', 'Sorc14k', 'Sorc24k', 'Sorc34k', 'Sorc60k', 'Sorc70k', 'Sorc75k', 'Sorcerer30k', 'Soulfire', 'Stalagmite', 'Stone Shower', 'Strong Haste', 'Sudden Death', 'Super Sd', 'Swift Foot', 'Terra Strike', 'Terra Wave', 'Train Party', 'Trap Rune', 'Ultimate Healing', 'Ultimate Light', 'Whirlwind Throw', 'Wound Cleansing', 'Wrath Of Nature'}
  }--[[,

  ['Sample'] =  {
    iconFile = '/images/game/spells/sample',
    iconSize = {width = 64, height = 64},
    spellOrder = {'Critical Strike', 'Firefly', 'Fire Breath', 'Moonglaives', 'Wind Walk'}
  }]]
}

SpellInfo = {
  ['Default'] = {
    ['Antidote'] = {id = 1000, words = 'exana pox', exhaustion = 1000, premium = false, type = 'Instant', icon = 'antidote', mana = 30, level = 10, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Antidote Rune'] = {id = 1001, words = 'adana pox', exhaustion = 1000, premium = false, type = 'Rune', icon = 'curepoison', mana = 0, level = 15, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Berserk'] = {id = 80, words = 'exori', exhaustion = 1000, premium = true, type = 'Instant', icon = 'berserk', mana = 115, level = 35, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Blood Rage'] = {id = 133, words = 'utito tempo', exhaustion = 1000, premium = true, type = 'Instant', icon = 'bloodrage', mana = 290, level = 60, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {4, 8}},
    ['Cancel Invisibility'] = {id = 90, words = 'exana ina', exhaustion = 1000, premium = true, type = 'Instant', icon = 'cancelinvisibility', mana = 200, level = 26, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 5}},
    ['Challenge'] = {id = 93, words = 'exeta res', exhaustion = 1000, premium = true, type = 'Instant', icon = 'challenge', mana = 30, level = 20, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {8}},
    ['Chameleon'] = {id = 14, words = 'adevo ina', exhaustion = 1000, premium = false, type = 'Rune', icon = 'chameleon', mana = 0, level = 27, maglevel = 4, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Charge'] = {id = 131, words = 'utani tempo hur', exhaustion = 1000, premium = true, type = 'Instant', icon = 'charge', mana = 100, level = 25, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {4, 8}},
    ['Creature Illusion'] = {id = 38, words = 'utevo res ina', exhaustion = 1000, premium = false, type = 'Instant', icon = 'creatureillusion', mana = 100, level = 23, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 5, 6}, parameter = true},
    ['Death Strike'] = {id = 87, words = 'exori mort', exhaustion = 1000, premium = true, type = 'Instant', icon = 'deathstrike', mana = 20, level = 16, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Desintegrate'] = {id = 78, words = 'adito tera', exhaustion = 1000, premium = false, type = 'Rune', icon = 'desintegrate', mana = 0, level = 21, maglevel = 4, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Destroy Field'] = {id = 30, words = 'adito grav', exhaustion = 1000, premium = false, type = 'Rune', icon = 'destroyfield', mana = 0, level = 17, maglevel = 3, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Divine Caldera'] = {id = 124, words = 'exevo mas san', exhaustion = 1000, premium = true, type = 'Instant', icon = 'divinecaldera', mana = 160, level = 50, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Divine Healing'] = {id = 125, words = 'exura san', exhaustion = 1000, premium = true, type = 'Instant', icon = 'divinehealing', mana = 210, level = 35, maglevel = 0, soul = 0, group = {[2] = 1000}, vocations = {3, 7}},
    ['Divine Missile'] = {id = 122, words = 'exori san', exhaustion = 1000, premium = true, type = 'Instant', icon = 'divinemissile', mana = 20, level = 40, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Druid14k'] = {id = 1002, words = 'exevo mas vanish', exhaustion = 1000, premium = false, type = 'Instant', icon = 'wrathofnature', mana = 1500, level = 14000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}, needlearn = true},
    ['Druid24k'] = {id = 1003, words = 'exevo mas vis ris', exhaustion = 1000, premium = false, type = 'Instant', icon = 'wrathofnature', mana = 1500, level = 24000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}, needlearn = true},
    ['Druid30k'] = {id = 1004, words = 'Verms', exhaustion = 1000, premium = false, type = 'Instant', icon = 'wrathofnature', mana = 1300, level = 30000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}},
    ['Druid34k'] = {id = 1005, words = 'mas mort gran', exhaustion = 1000, premium = false, type = 'Instant', icon = 'wrathofnature', mana = 1500, level = 34000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}, needlearn = true},
    ['Druid60k'] = {id = 1006, words = 'exevo gran mas dead', exhaustion = 1000, premium = false, type = 'Instant', icon = 'wrathofnature', mana = 10000, level = 60000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}, needlearn = true},
    ['Druid70k'] = {id = 1007, words = 'exeva mas destroyer', exhaustion = 1000, premium = false, type = 'Instant', icon = 'wrathofnature', mana = 12000, level = 70000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}, needlearn = true},
    ['Druid75k'] = {id = 1008, words = 'exeva mas totum', exhaustion = 1000, premium = false, type = 'Instant', icon = 'wrathofnature', mana = 12000, level = 75000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}, needlearn = true},
    ['Enchant Party'] = {id = 129, words = 'utori mas sio', exhaustion = 1000, premium = true, type = 'Instant', icon = 'enchantparty', mana = 120, level = 32, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {5}},
    ['Energy Beam'] = {id = 22, words = 'exevo vis lux', exhaustion = 1000, premium = false, type = 'Instant', icon = 'energybeam', mana = 40, level = 23, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}},
    ['Energy Field'] = {id = 27, words = 'adevo grav vis', exhaustion = 1000, premium = false, type = 'Rune', icon = 'energyfield', mana = 0, level = 18, maglevel = 3, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Energy Strike'] = {id = 88, words = 'exori vis', exhaustion = 1000, premium = true, type = 'Instant', icon = 'energystrike', mana = 20, level = 12, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Energy Wall'] = {id = 33, words = 'adevo mas grav vis', exhaustion = 1000, premium = false, type = 'Rune', icon = 'energywall', mana = 0, level = 41, maglevel = 9, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Energy Wave'] = {id = 13, words = 'exevo vis hur', exhaustion = 1000, premium = false, type = 'Instant', icon = 'energywave', mana = 170, level = 38, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}},
    ['Eternal Winter'] = {id = 118, words = 'exevo gran mas frigo', exhaustion = 1000, premium = true, type = 'Instant', icon = 'eternalwinter', mana = 1200, level = 60, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}},
    ['Ethereal Spear'] = {id = 111, words = 'exori con', exhaustion = 1000, premium = true, type = 'Instant', icon = 'etherealspear', mana = 35, level = 23, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Exevo Trap'] = {id = 1009, words = 'exevo trap', exhaustion = 1000, premium = false, type = 'Instant', icon = 'magicwall', mana = 100, level = 150000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 5, 6, 7}},
    ['Explosion'] = {id = 18, words = 'adevo mas hur', exhaustion = 1000, premium = false, type = 'Rune', icon = 'explosion', mana = 0, level = 31, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Fierce Berserk'] = {id = 105, words = 'exori gran', exhaustion = 1000, premium = true, type = 'Instant', icon = 'fierceberserk', mana = 340, level = 70, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Find Person'] = {id = 20, words = 'exiva', exhaustion = 1000, premium = false, type = 'Instant', icon = 'findperson', mana = 20, level = 8, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}, parameter = true},
    ['Fire Field'] = {id = 25, words = 'adevo grav flam', exhaustion = 1000, premium = false, type = 'Rune', icon = 'firefield', mana = 0, level = 15, maglevel = 1, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Fire Wall'] = {id = 28, words = 'adevo mas grav flam', exhaustion = 1000, premium = false, type = 'Rune', icon = 'firewall', mana = 0, level = 33, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Fire Wave'] = {id = 19, words = 'exevo flam hur', exhaustion = 1000, premium = false, type = 'Instant', icon = 'firewave', mana = 25, level = 18, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}},
    ['Fireball'] = {id = 15, words = 'adori flam', exhaustion = 1000, premium = false, type = 'Rune', icon = 'fireball', mana = 0, level = 27, maglevel = 4, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Firebomb'] = {id = 17, words = 'adevo mas flam', exhaustion = 1000, premium = false, type = 'Rune', icon = 'firebomb', mana = 0, level = 27, maglevel = 5, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Flame Strike'] = {id = 89, words = 'exori flam', exhaustion = 1000, premium = true, type = 'Instant', icon = 'flamestrike', mana = 20, level = 12, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Freeze Crystal'] = {id = 1010, words = 'freeze crystal', exhaustion = 1000, premium = false, type = 'Rune', icon = 'ultimateicestrike', mana = 0, level = 0, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Freeze Shard'] = {id = 1011, words = 'freeze shard', exhaustion = 1000, premium = false, type = 'Rune', icon = 'icestrike', mana = 0, level = 0, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Great Energy Beam'] = {id = 23, words = 'exevo gran vis lux', exhaustion = 1000, premium = false, type = 'Instant', icon = 'greatenergybeam', mana = 110, level = 29, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}},
    ['Great Fireball'] = {id = 16, words = 'adori mas flam', exhaustion = 1000, premium = false, type = 'Rune', icon = 'greatfireball', mana = 0, level = 30, maglevel = 4, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Great Light'] = {id = 11, words = 'utevo gran lux', exhaustion = 1000, premium = false, type = 'Instant', icon = 'greatlight', mana = 60, level = 13, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Groundshaker'] = {id = 106, words = 'exori mas', exhaustion = 1000, premium = true, type = 'Instant', icon = 'groundshaker', mana = 160, level = 33, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Haste'] = {id = 6, words = 'utani hur', exhaustion = 1000, premium = true, type = 'Instant', icon = 'haste', mana = 60, level = 14, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Heal Friend'] = {id = 84, words = 'exura sio', exhaustion = 1000, premium = true, type = 'Instant', icon = 'healfriend', mana = 140, level = 18, maglevel = 0, soul = 0, group = {[2] = 1000}, vocations = {2, 6}, parameter = true},
    ['Heal Party'] = {id = 128, words = 'utura mas sio', exhaustion = 1000, premium = true, type = 'Instant', icon = 'healparty', mana = 120, level = 32, maglevel = 0, soul = 0, group = {[2] = 1000}, vocations = {6}},
    ['Healing Rune'] = {id = 1012, words = 'adura vita', exhaustion = 100, premium = false, type = 'Rune', icon = 'ultimatehealingrune', mana = 0, level = 24, maglevel = 4, soul = 0, group = {[2] = 100}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Heavy Magic Missile'] = {id = 8, words = 'adori vis', exhaustion = 1000, premium = false, type = 'Rune', icon = 'heavymagicmissile', mana = 0, level = 25, maglevel = 3, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Hells Core'] = {id = 24, words = 'exevo gran mas flam', exhaustion = 1000, premium = true, type = 'Instant', icon = 'hellscore', mana = 1200, level = 60, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}},
    ['Holy Missile'] = {id = 130, words = 'adori san', exhaustion = 1000, premium = false, type = 'Rune', icon = 'holymissile', mana = 0, level = 27, maglevel = 4, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Ice Strike'] = {id = 112, words = 'exori frigo', exhaustion = 1000, premium = true, type = 'Instant', icon = 'icestrike', mana = 20, level = 15, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Ice Wave'] = {id = 121, words = 'exevo frigo hur', exhaustion = 1000, premium = false, type = 'Instant', icon = 'icewave', mana = 25, level = 18, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}},
    ['Icicle'] = {id = 114, words = 'adori frigo', exhaustion = 1000, premium = false, type = 'Rune', icon = 'icicle', mana = 0, level = 28, maglevel = 4, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Intense Healing'] = {id = 2, words = 'exura gran', exhaustion = 1000, premium = false, type = 'Instant', icon = 'intensehealing', mana = 70, level = 11, maglevel = 0, soul = 0, group = {[2] = 1000}, vocations = {1, 2, 3, 5, 6, 7}},
    ['Intense Healing Rune'] = {id = 4, words = 'adura gran', exhaustion = 1000, premium = false, type = 'Rune', icon = 'intensehealingrune', mana = 0, level = 15, maglevel = 1, soul = 0, group = {[2] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Invisibility'] = {id = 45, words = 'utana vid', exhaustion = 1000, premium = false, type = 'Instant', icon = 'invisible', mana = 440, level = 35, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 5, 6, 7}},
    ['Knight12k'] = {id = 1013, words = 'mystique quara', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 4000, level = 12000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Knight14k'] = {id = 1014, words = 'berserkerx', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 8000, level = 14000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}, needlearn = true},
    ['Knight1k'] = {id = 1015, words = 'deadly rings', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 1500, level = 1000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Knight20k'] = {id = 1016, words = 'mystique avalanche', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 5000, level = 20000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Knight24k'] = {id = 1017, words = 'death berserker', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 8000, level = 24000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}, needlearn = true},
    ['Knight30k'] = {id = 1018, words = 'jumbo berserk', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 6000, level = 30000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Knight34k'] = {id = 1019, words = 'death guard', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 8000, level = 34000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}, needlearn = true},
    ['Knight3k'] = {id = 1020, words = 'super fighter', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 2000, level = 3000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Knight40k'] = {id = 1021, words = 'super berserker', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 7000, level = 40000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Knight4k'] = {id = 1022, words = 'super knight', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 2500, level = 4000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Knight50k'] = {id = 1023, words = 'ultimate berserker', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 8000, level = 50000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Knight60k'] = {id = 1024, words = 'exevo mas rip berserker', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 8000, level = 60000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}, needlearn = true},
    ['Knight6k'] = {id = 1025, words = 'berserk guard', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 3000, level = 6000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Knight70k'] = {id = 1026, words = 'exevo mas destroyer', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 10000, level = 70000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}, needlearn = true},
    ['Knight75k'] = {id = 1027, words = 'exevo mas totum', exhaustion = 1000, premium = false, type = 'Instant', icon = 'annihilation', mana = 11000, level = 75000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {4, 8}, needlearn = true},
    ['Levitate'] = {id = 81, words = 'exani hur', exhaustion = 1000, premium = true, type = 'Instant', icon = 'levitate', mana = 50, level = 12, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}, parameter = true},
    ['Light'] = {id = 10, words = 'utevo lux', exhaustion = 1000, premium = false, type = 'Instant', icon = 'light', mana = 20, level = 8, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Light Healing'] = {id = 1, words = 'exura', exhaustion = 1000, premium = false, type = 'Instant', icon = 'lighthealing', mana = 20, level = 9, maglevel = 0, soul = 0, group = {[2] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Light Magic Missile'] = {id = 7, words = 'adori min vis', exhaustion = 1000, premium = false, type = 'Rune', icon = 'lightmagicmissile', mana = 0, level = 15, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Mage12k'] = {id = 1028, words = 'exevo vis mort', exhaustion = 1000, premium = false, type = 'Instant', icon = 'rageoftheskies', mana = 1000, level = 12000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Mage1k'] = {id = 1029, words = 'exevo gran mas love', exhaustion = 1000, premium = false, type = 'Instant', icon = 'rageoftheskies', mana = 2000, level = 1000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Mage20k'] = {id = 1030, words = 'Death Core', exhaustion = 1000, premium = false, type = 'Instant', icon = 'rageoftheskies', mana = 1300, level = 20000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Mage2k'] = {id = 1031, words = 'exevo gran mas labay', exhaustion = 1000, premium = false, type = 'Instant', icon = 'rageoftheskies', mana = 1300, level = 2000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Mage3k'] = {id = 1032, words = 'exevo gran mas magical', exhaustion = 1000, premium = false, type = 'Instant', icon = 'rageoftheskies', mana = 1300, level = 3000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Mage40k'] = {id = 1033, words = 'super avalanche', exhaustion = 1000, premium = false, type = 'Instant', icon = 'rageoftheskies', mana = 2000, level = 40000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Mage4k'] = {id = 1034, words = 'xx fireworks', exhaustion = 1000, premium = false, type = 'Instant', icon = 'rageoftheskies', mana = 1300, level = 4000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Mage50k'] = {id = 1035, words = 'wild avalanche', exhaustion = 1000, premium = false, type = 'Instant', icon = 'rageoftheskies', mana = 2000, level = 50000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Mage5k'] = {id = 1036, words = 'pimpeen', exhaustion = 1000, premium = false, type = 'Instant', icon = 'wrathofnature', mana = 1300, level = 5000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}},
    ['Mage6k'] = {id = 1037, words = 'Dead Neo', exhaustion = 1000, premium = false, type = 'Instant', icon = 'rageoftheskies', mana = 1300, level = 6000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Magic Rope'] = {id = 76, words = 'exani tera', exhaustion = 1000, premium = true, type = 'Instant', icon = 'magicrope', mana = 20, level = 9, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Magic Shield'] = {id = 44, words = 'utamo vita', exhaustion = 1000, premium = false, type = 'Instant', icon = 'magicshield', mana = 50, level = 14, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 5, 6, 7}},
    ['Magic Wall'] = {id = 86, words = 'adevo grav tera', exhaustion = 1000, premium = false, type = 'Rune', icon = 'magicwall', mana = 0, level = 32, maglevel = 9, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Mass Healing'] = {id = 82, words = 'exura gran mas res', exhaustion = 1000, premium = true, type = 'Instant', icon = 'masshealing', mana = 150, level = 36, maglevel = 0, soul = 0, group = {[2] = 1000}, vocations = {2, 6}},
    ['Mega Super Sd'] = {id = 1038, words = 'Level 0', exhaustion = 300, premium = false, type = 'Rune', icon = 'suddendeath', mana = 0, level = 0, maglevel = 70, soul = 0, group = {[1] = 300}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Paladin12k'] = {id = 1039, words = 'mystique pala', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 4000, level = 12000, maglevel = 10, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Paladin14k'] = {id = 1040, words = 'xxdeadxx', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 4500, level = 14000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {3, 7}, needlearn = true},
    ['Paladin1k'] = {id = 1041, words = 'exevo gran mas staff member', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 1300, level = 1000, maglevel = 9, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Paladin20k'] = {id = 1042, words = 'mystique bla', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 5000, level = 20000, maglevel = 10, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Paladin24k'] = {id = 1043, words = 'massivex death', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 5500, level = 24000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {3, 7}, needlearn = true},
    ['Paladin2k'] = {id = 1044, words = 'FU', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 1300, level = 2000, maglevel = 7, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Paladin30k'] = {id = 1045, words = 'rx roxxor', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 6000, level = 30000, maglevel = 15, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Paladin34k'] = {id = 1046, words = 'death of the seven', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 6500, level = 34000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {3, 7}, needlearn = true},
    ['Paladin3k'] = {id = 1047, words = 'deadx', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 1300, level = 3000, maglevel = 7, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Paladin40k'] = {id = 1048, words = 'paladin destruction', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 7000, level = 40000, maglevel = 15, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Paladin50k'] = {id = 1049, words = 'paladin revenge', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 8000, level = 50000, maglevel = 15, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Paladin60k'] = {id = 1050, words = 'mas gran deadx', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 10000, level = 60000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {3, 7}, needlearn = true},
    ['Paladin6k'] = {id = 1051, words = 'deadx fireworks', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 1300, level = 6000, maglevel = 20, soul = 0, group = {[1] = 1000}, vocations = {3, 7}},
    ['Paladin70k'] = {id = 1052, words = 'mas gran destroyer', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 10000, level = 70000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {3, 7}, needlearn = true},
    ['Paladin75k'] = {id = 1053, words = 'mas gran totum', exhaustion = 1000, premium = false, type = 'Instant', icon = 'divinecaldera', mana = 11000, level = 75000, maglevel = 6, soul = 0, group = {[1] = 1000}, vocations = {3, 7}, needlearn = true},
    ['Paralyze'] = {id = 54, words = 'adana ani', exhaustion = 1000, premium = false, type = 'Rune', icon = 'paralyze', mana = 0, level = 54, maglevel = 18, soul = 0, group = {[3] = 1000}, vocations = {2, 6}},
    ['Poison Bomb'] = {id = 91, words = 'adevo mas pox', exhaustion = 1000, premium = false, type = 'Rune', icon = 'poisonbomb', mana = 0, level = 25, maglevel = 4, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Poison Field'] = {id = 26, words = 'adevo grav pox', exhaustion = 1000, premium = false, type = 'Rune', icon = 'poisonfield', mana = 0, level = 14, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Poison Wall'] = {id = 32, words = 'adevo mas grav pox', exhaustion = 1000, premium = false, type = 'Rune', icon = 'poisonwall', mana = 0, level = 29, maglevel = 5, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Poisoned Rune'] = {id = 1054, words = 'poisoned rune', exhaustion = 1000, premium = false, type = 'Rune', icon = 'poisonbomb', mana = 0, level = 15000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Protect Party'] = {id = 127, words = 'utamo mas sio', exhaustion = 1000, premium = true, type = 'Instant', icon = 'protectparty', mana = 90, level = 32, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {7}},
    ['Protector'] = {id = 132, words = 'utamo tempo', exhaustion = 1000, premium = true, type = 'Instant', icon = 'protector', mana = 200, level = 55, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {4, 8}},
    ['Rage Of The Skies'] = {id = 119, words = 'exevo gran mas vis', exhaustion = 1000, premium = true, type = 'Instant', icon = 'rageoftheskies', mana = 650, level = 55, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}},
    ['Sharpshooter'] = {id = 135, words = 'utito tempo san', exhaustion = 1000, premium = true, type = 'Instant', icon = 'sharpshooter', mana = 450, level = 60, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {3, 7}},
    ['Sorc14k'] = {id = 1055, words = 'exevo gran mas mortal', exhaustion = 1000, premium = false, type = 'Instant', icon = 'hellscore', mana = 1500, level = 14000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}, needlearn = true},
    ['Sorc24k'] = {id = 1056, words = 'exevo mas power', exhaustion = 1000, premium = false, type = 'Instant', icon = 'hellscore', mana = 1500, level = 24000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}, needlearn = true},
    ['Sorc34k'] = {id = 1057, words = 'exevo gran mas brutal', exhaustion = 1000, premium = false, type = 'Instant', icon = 'hellscore', mana = 1500, level = 34000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}, needlearn = true},
    ['Sorc60k'] = {id = 1058, words = 'exevo gran mas rip', exhaustion = 1000, premium = false, type = 'Instant', icon = 'hellscore', mana = 8000, level = 60000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}, needlearn = true},
    ['Sorc70k'] = {id = 1059, words = 'exevo gran mas destroyer', exhaustion = 1000, premium = false, type = 'Instant', icon = 'hellscore', mana = 10000, level = 70000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}, needlearn = true},
    ['Sorc75k'] = {id = 1060, words = 'exevo gran mas totum', exhaustion = 1000, premium = false, type = 'Instant', icon = 'hellscore', mana = 10000, level = 75000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}, needlearn = true},
    ['Sorcerer30k'] = {id = 1061, words = 'Holyyy', exhaustion = 1000, premium = false, type = 'Instant', icon = 'hellscore', mana = 1300, level = 30000, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 5}},
    ['Soulfire'] = {id = 50, words = 'adevo res flam', exhaustion = 1000, premium = false, type = 'Rune', icon = 'soulfire', mana = 0, level = 27, maglevel = 7, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Stalagmite'] = {id = 77, words = 'adori tera', exhaustion = 1000, premium = false, type = 'Rune', icon = 'stalagmite', mana = 0, level = 24, maglevel = 3, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Stone Shower'] = {id = 116, words = 'adori mas tera', exhaustion = 1000, premium = false, type = 'Rune', icon = 'stoneshower', mana = 0, level = 28, maglevel = 4, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Strong Haste'] = {id = 39, words = 'utani gran hur', exhaustion = 1000, premium = true, type = 'Instant', icon = 'stronghaste', mana = 100, level = 20, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Sudden Death'] = {id = 21, words = 'adori gran mort', exhaustion = 1000, premium = false, type = 'Rune', icon = 'suddendeath', mana = 0, level = 45, maglevel = 15, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Super Sd'] = {id = 1062, words = 'super sd', exhaustion = 50, premium = false, type = 'Rune', icon = 'suddendeath', mana = 0, level = 0, maglevel = 1, soul = 0, group = {[1] = 50}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Swift Foot'] = {id = 134, words = 'utamo tempo san', exhaustion = 1000, premium = true, type = 'Instant', icon = 'swiftfoot', mana = 400, level = 55, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {3, 7}},
    ['Terra Strike'] = {id = 113, words = 'exori tera', exhaustion = 1000, premium = true, type = 'Instant', icon = 'terrastrike', mana = 20, level = 13, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 5, 6}},
    ['Terra Wave'] = {id = 120, words = 'exevo tera hur', exhaustion = 1000, premium = false, type = 'Instant', icon = 'terrawave', mana = 210, level = 38, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}},
    ['Train Party'] = {id = 126, words = 'utito mas sio', exhaustion = 1000, premium = true, type = 'Instant', icon = 'trainparty', mana = 60, level = 32, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {8}},
    ['Trap Rune'] = {id = 1063, words = 'trap rune', exhaustion = 1000, premium = false, type = 'Rune', icon = 'magicwall', mana = 0, level = 0, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {1, 2, 3, 5, 6, 7}},
    ['Ultimate Healing'] = {id = 3, words = 'exura vita', exhaustion = 1000, premium = false, type = 'Instant', icon = 'ultimatehealing', mana = 160, level = 20, maglevel = 0, soul = 0, group = {[2] = 1000}, vocations = {1, 2, 3, 5, 6, 7}},
    ['Ultimate Light'] = {id = 75, words = 'utevo vis lux', exhaustion = 1000, premium = true, type = 'Instant', icon = 'ultimatelight', mana = 140, level = 26, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {1, 2, 3, 4, 5, 6, 7, 8}},
    ['Whirlwind Throw'] = {id = 107, words = 'exori hur', exhaustion = 1000, premium = true, type = 'Instant', icon = 'whirlwindthrow', mana = 40, level = 15, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {4, 8}},
    ['Wound Cleansing'] = {id = 123, words = 'exana mort', exhaustion = 1000, premium = true, type = 'Instant', icon = 'woundcleansing', mana = 65, level = 30, maglevel = 0, soul = 0, group = {[3] = 1000}, vocations = {4, 8}},
    ['Wrath Of Nature'] = {id = 56, words = 'exevo gran mas tera', exhaustion = 1000, premium = true, type = 'Instant', icon = 'wrathofnature', mana = 770, level = 55, maglevel = 0, soul = 0, group = {[1] = 1000}, vocations = {2, 6}},
  }--[[,

  ['Sample'] = {
    ['Wind Walk'] =                {id = 1, words = 'windwalk',        description = 'Run at enormous speed.',          exhaustion = 2000,  premium = false, type = 'Instant', icon = 1,  mana = 50,     level = 10, soul = 0, group = {[3] = 2000}, vocations = {1, 2}},
    ['Fire Breath'] =              {id = 2, words = 'firebreath',      description = 'A strong firewave.',              exhaustion = 2000,  premium = false, type = 'Instant', icon = 2,  mana = 350,    level = 27, soul = 0, group = {[1] = 2000}, vocations = {4, 8}},
    ['Moonglaives'] =              {id = 3, words = 'moonglaives',     description = 'Throw moonglaives around you.',   exhaustion = 2000,  premium = false, type = 'Instant', icon = 3,  mana = 90,     level = 55, soul = 0, group = {[1] = 2000}, vocations = {3, 7}},
    ['Critical Strike'] =          {id = 4, words = 'criticalstrike',  description = 'Land a critical strike.',         exhaustion = 2000,  premium = false, type = 'Instant', icon = 4,  mana = 350,    level = 27, soul = 0, group = {[1] = 2000}, vocations = {3, 4, 7, 8}},
    ['Firefly'] =                  {id = 5, words = 'firefly',         description = 'Summon a angry firefly',          exhaustion = 2000,  premium = false, type = 'Instant', icon = 5,  mana = 350,    level = 27, soul = 0, group = {[1] = 2000}, vocations = {1, 2, 5, 6}}
  }]]
}

-- ['const_name'] =       {client_id, TFS_id}
-- Conversion from TFS icon id to the id used by client (icons.png order)  
SpellIcons = {
  -- new tibia spells, server owners - you will probably need to adjust TFS_id
  ['summonsorcererfamiliar']    = {130, 173},
  ['summondruidfamiliar']       = {129, 172},
  ['summonpaladinfamiliar']     = {127, 171},
  ['summonknightfamiliar']      = {128, 170},
  ['exposeweakness']            = {134, 106},
  ['sapstrenght']               = {135, 105},
  ['restoration']               = {137, 103},
  ['fairwoundcleansing']        = {132, 102},
  ['chivalrouschallange']       = {131, 101},
  ["naturesembrace"]            = {138, 101},
  ['divinedazzle']              = {139, 101},
  ['greatfirewave']             = {136, 100},
  ['conjurewandofdarkness']     = {133, 92},
  -- old spells
  ['intenserecovery']           = {16, 160},
  ['recovery']                  = {15, 159},
  ['intensewoundcleansing']     = {4, 158},
  ['ultimateterrastrike']       = {37, 157},
  ['ultimateicestrike']         = {34, 156},
  ['ultimateenergystrike']      = {31, 155},
  ['ultimateflamestrike']       = {28, 154},
  ['strongterrastrike']         = {36, 153},
  ['strongicestrike']           = {33, 152},
  ['strongenergystrike']        = {30, 151},
  ['strongflamestrike']         = {27, 150},
  ['lightning']                 = {51, 149},
  ['physicalstrike']            = {17, 148},
  ['curecurse']                 = {11, 147},
  ['curseelectrification']      = {14, 146},
  ['cureburning']               = {13, 145},
  ['curebleeding']              = {12, 144},
  ['holyflash']                 = {53, 143},
  ['envenom']                   = {58, 142},
  ['inflictwound']              = {57, 141},
  ['electrify']                 = {56, 140},
  ['curse']                     = {54, 139},
  ['ignite']                    = {55, 138},
  -- [[ 136 / 137 Unknown ]]
  ['sharpshooter']              = {121, 135},
  ['swiftfoot']                 = {119, 134},
  ['bloodrage']                 = {96, 133},
  ['protector']                 = {122, 132},
  ['charge']                    = {98, 131},
  ['holymissile']               = {76, 130},
  ['enchantparty']              = {113, 129},
  ['healparty']                 = {126, 128},
  ['protectparty']              = {123, 127},
  ['trainparty']                = {120, 126},
  ['divinehealing']             = {2, 125},
  ['divinecaldera']             = {40, 124},
  ['woundcleansing']            = {3, 123},
  ['divinemissile']             = {39, 122},
  ['icewave']                   = {45, 121},
  ['terrawave']                 = {47, 120},
  ['rageoftheskies']            = {52, 119},
  ['eternalwinter']             = {50, 118},
  ['thunderstorm']              = {63, 117},
  ['stoneshower']               = {65, 116},
  ['avalanche']                 = {92, 115},
  ['icicle']                    = {75, 114},
  ['terrastrike']               = {35, 113},
  ['icestrike']                 = {32, 112},
  ['etherealspear']             = {18, 111},
  ['enchantspear']              = {104, 110},
  ['piercingbolt']              = {110, 109},
  ['sniperarrow']               = {112, 108},
  ['whirlwindthrow']            = {19, 107},
  ['groundshaker']              = {25, 106},
  ['fierceberserk']             = {22, 105},
  -- [[ 96 - 104 Unknown ]]
  ['powerbolt']                 = {108, 95},
  ['wildgrowth']                = {61, 94},
  ['challenge']                 = {97, 93},
  ['enchantstaff']              = {103, 92},
  ['poisonbomb']                = {70, 91},
  ['cancelinvisibility']        = {95, 90},
  ['flamestrike']               = {26, 89},
  ['energystrike']              = {29, 88},
  ['deathstrike']               = {38, 87},
  ['magicwall']                 = {72, 86},
  ['healfriend']                = {8, 84},
  ['animatedead']               = {93, 83},
  ['masshealing']               = {9, 82},
  ['levitate']                  = {125, 81},
  ['berserk']                   = {21, 80},
  ['conjurebolt']               = {107, 79},
  ['desintegrate']              = {88, 78},
  ['stalagmite']                = {66, 77},
  ['magicrope']                 = {105, 76},
  ['ultimatelight']             = {115, 75},
  -- [[ 71 - 64 TFS House Commands ]]
  -- [[ 63 - 70 Unknown ]]
  ['annihilation']              = {24, 62},
  ['brutalstrike']              = {23, 61},
  -- [[ 60 Unknown ]]
  ['frontsweep']                = {20, 59},
  -- [[ 58 Unknown ]]
  ['strongetherealspear']       = {59, 57},
  ['wrathofnature']             = {48, 56},
  ['energybomb']                = {86, 55},
  ['paralyze']                  = {71, 54},
  --  [[ 53 Unknown ]]
  --  [[ 52 TFS Retrieve Friend ]]
  ['conjurearrow']              = {106, 51},
  ['soulfire']                  = {67, 50},
  ['explosivearrow']            = {109, 49},
  ['poisonedarrow']             = {111, 48},
  -- [[ 46 / 47 Unknown ]]
  ['invisible']                 = {94, 45},
  ['magicshield']               = {124, 44},
  ['strongicewave']             = {46, 43},
  ['food']                      = {99, 42},
  -- [[ 40 / 41 Unknown ]]
  ['stronghaste']               = {102, 39},
  ['creatureillusion']          = {100, 38},
  -- [[ 37 TFS Move ]]
  ['salvation']                 = {60, 36},
  -- [[ 34 / 35 Unknown ]]
  ['energywall']                = {84, 33},
  ['poisonwall']                = {68, 32},
  ['antidote']                  = {10, 31},
  ['destroyfield']              = {87, 30},
  ['curepoison']                = {10, 29},
  ['firewall']                  = {80, 28},
  ['energyfield']               = {85, 27},
  ['poisonfield']               = {69, 26},
  ['firefield']                 = {81, 25},
  ['hellscore']                 = {49, 24},
  ['greatenergybeam']           = {42, 23},
  ['energybeam']                = {41, 22},
  ['suddendeath']               = {64, 21},
  ['findperson']                = {114, 20},
  ['firewave']                  = {44, 19},
  ['explosion']                 = {83, 18},
  ['firebomb']                  = {82, 17},
  ['greatfireball']             = {78, 16},
  ['fireball']                  = {79, 15},
  ['chameleon']                 = {91, 14},
  ['energywave']                = {43, 13},
  ['convincecreature']          = {90, 12},
  ['greatlight']                = {116, 11},
  ['light']                     = {117, 10},
  ['summoncreature']            = {118, 9},
  ['heavymagicmissile']         = {77, 8},
  ['lightmagicmissile']         = {73, 7},
  ['haste']                     = {101, 6},
  ['ultimatehealingrune']       = {62, 5},
  ['intensehealingrune']        = {74, 4},
  ['ultimatehealing']           = {1, 3},
  ['intensehealing']            = {7, 2},
  ['lighthealing']              = {6, 1},
}

VocationNames = {
  [1] = 'Sorcerer',
  [2] = 'Druid',
  [3] = 'Paladin',
  [4] = 'Knight',
  [5] = 'Master Sorcerer',
  [6] = 'Elder Druid',
  [7] = 'Royal Paladin',
  [8] = 'Elite Knight'
}

SpellGroups = {
  [1] = 'Attack',
  [2] = 'Healing',
  [3] = 'Support',
  [4] = 'Special',
  [5] = 'Cripple'
}

Spells = {}

function Spells.getClientId(spellName)
  local profile = Spells.getSpellProfileByName(spellName)

  local id = SpellInfo[profile][spellName].icon
  if not tonumber(id) and SpellIcons[id] then
    return SpellIcons[id][1]
  end
  return tonumber(id)
end

function Spells.getServerId(spellName)
  local profile = Spells.getSpellProfileByName(spellName)

  local id = SpellInfo[profile][spellName].icon
  if not tonumber(id) and SpellIcons[id] then
    return SpellIcons[id][2]
  end
  return tonumber(id)
end

function Spells.getSpellByName(name)
  return SpellInfo[Spells.getSpellProfileByName(name)][name]
end

function Spells.getSpellByWords(words)
  local words = words:lower():trim()
  for profile,data in pairs(SpellInfo) do
    for k,spell in pairs(data) do
      if spell.words == words then
        return spell, profile, k
      end
    end
  end
  return nil
end

function Spells.getSpellByIcon(iconId)
  for profile,data in pairs(SpellInfo) do
    for k,spell in pairs(data) do
      if spell.id == iconId then
        return spell, profile, k
      end
    end
  end
  return nil
end

function Spells.getSpellIconIds()
  local ids = {}
  for profile,data in pairs(SpellInfo) do
    for k,spell in pairs(data) do
      table.insert(ids, spell.id)
    end
  end
  return ids
end

function Spells.getSpellProfileById(id)
  for profile,data in pairs(SpellInfo) do
    for k,spell in pairs(data) do
      if spell.id == id then
        return profile
      end
    end
  end
  return nil
end

function Spells.getSpellProfileByWords(words)
  for profile,data in pairs(SpellInfo) do
    for k,spell in pairs(data) do
      if spell.words == words then
        return profile
      end
    end
  end
  return nil
end

function Spells.getSpellProfileByName(spellName)
  for profile,data in pairs(SpellInfo) do
    if table.findbykey(data, spellName:trim(), true) then
      return profile
    end
  end
  return nil
end

function Spells.getSpellsByVocationId(vocId)
  local spells = {}
  for profile,data in pairs(SpellInfo) do
    for k,spell in pairs(data) do
      if table.contains(spell.vocations, vocId) then
        table.insert(spells, spell)
      end
    end
  end
  return spells
end

function Spells.filterSpellsByGroups(spells, groups)
  local filtered = {}
  for v,spell in pairs(spells) do
    local spellGroups = Spells.getGroupIds(spell)
    if table.equals(spellGroups, groups) then
      table.insert(filtered, spell)
    end
  end
  return filtered
end

function Spells.getGroupIds(spell)
  local groups = {}
  for k,_ in pairs(spell.group) do
    table.insert(groups, k)
  end
  return groups
end

function Spells.getImageClip(id, profile)
  return (((id-1)%12)*SpelllistSettings[profile].iconSize.width) .. ' ' 
    .. ((math.ceil(id/12)-1)*SpelllistSettings[profile].iconSize.height) .. ' ' 
    .. SpelllistSettings[profile].iconSize.width .. ' ' 
    .. SpelllistSettings[profile].iconSize.height
end