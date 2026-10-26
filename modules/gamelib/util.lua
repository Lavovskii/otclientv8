function postostring(pos)
  return pos.x .. " " .. pos.y .. " " .. pos.z
end

function dirtostring(dir)
  for k,v in pairs(Directions) do
    if v == dir then
      return k
    end
  end
end

-- capacity as the game windows show it: 10000 or more in thousands (10k, 11k...), 1000 or more without decimals,
-- less with one decimal at most
function formatCapacity(value)
  if value >= 10000 then
    return math.floor(value / 1000) .. 'k'
  elseif value >= 1000 then
    return math.floor(value)
  end
  return math.floor(value * 10) / 10
end
