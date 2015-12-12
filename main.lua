socket = require("socket")
json = require("dkjson")
require("util")
require("stridx")

TCP_sock = socket.tcp()
TCP_sock:settimeout(7)
if not TCP_sock:connect("irc.mibbit.com", 6667) then
  error("failed to connect yolo")
end
TCP_sock:settimeout(0)

local sent_nick = false
local can_join = false
local joined = false
local leftovers = ""

codex_cards = {}
filenames = {"white", "blue", "black", "red", "green", "purple", "neutral", "heroes"}
color_to_specs = {White={"Discipline","Ninjutsu","Strength"},
                  Blue={"Law","Peace","Truth"},
                  Black={"Demonology","Disease","Necromancy"},
                  Red={"Anarchy","Blood","Fire"},
                  Green={"Balance","Feral","Growth"},
                  Purple={"Past","Present","Future"},
                  Neutral={"Bashing","Finesse"}}

local used_names = {}
for _,name in pairs(filenames) do
  local cards = json.decode(file_contents(name..".json"))
  for _,card in pairs(cards) do
    if not used_names[card.name] then
      if card.spec then
        specs[card.spec] = true
      end
      codex_cards[#codex_cards+1] = card
      used_names[card.name] = true
    end
  end
end

for color, specs in pairs(color_to_specs) do
  codex_cards[#codex_cards+1] = {type="Color", name=color}
  for _, spec in pairs(specs) do
    codex_cards[#codex_cards+1] = {type="Spec", name=spec}
  end
end

circled_digits = {[0]="⓪", "①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨", "⑩",
                           "⑪", "⑫", "⑬", "⑭", "⑮", "⑯", "⑰", "⑱", "⑲", "⑳",}

function levenshtein_distance(s, t)
  s,t = procat(s), procat(t)
  local m,n = #s, #t
  local d = {}
  for i=0,m do
    d[i] = {}
    d[i][0] = i
  end
  for j=1,n do
    d[0][j] = j
  end
  for j=1,n do
    for i=1,m do
      if s[i] == t[j] then
        d[i][j] = d[i-1][j-1]
      else
        d[i][j] = math.min(d[i-1][j]+1,
                           d[i][j-1]+1, d[i-1][j-1]+1)
      end
    end
  end
  return d[m][n]
end

function card_to_int_for_sort(card)
  local ret = 0
  if card.type == "Hero" then
    ret = 0
  elseif card.type == "Unit" or card.type == "Legendary Unit" then
    ret = 100
  elseif card.type == "Building" or card.type == "Legendary Building" then
    ret = 200
  elseif card.type == "Upgrade" or card.type == "Legendary Upgrade" then
    ret = 300
  elseif card.type == "Ultimate Spell" or card.type == "Ultimate Ongoing Spell" then
    ret = 500
  else
    ret = 400
  end
  ret = ret + card.cost
  if card.starting_zone == "deck" or card.starting_zone == "command" then
    return ret
  elseif card.starting_zone == "trash" then
    return 9000 + ret
  elseif card.tech_level == nil then
    return 1000 + ret
  else
    return card.tech_level * 1000 + 1000 + ret
  end
end

function compare_cards(a,b)
  local na, nb = card_to_int_for_sort(a), card_to_int_for_sort(b)
  if na ~= nb then
    return na < nb
  end
  return a.name < b.name
end

function format_color(color)
  local deck = {}
  for k,v in pairs(codex_cards) do
    if card.starting_zone == "deck" and card.color == color then
      deck[#deck + 1] = card
    end
  end
  table.sort(deck, compare_cards)
  local card_names = map(function(c) return c.name end, deck)
  local ret = color..": "
  ret = ret .. table.concat(color_to_specs[color], ", ") .. ". "
  ret = ret .. "Starting deck: "
  ret = ret .. table.concat(card_named, ", ") .. "."
  return ret
end

function format_spec(card)
end

function format_hero(card)
  local str = card.name .. " - "
  str = str .. card.spec .. " Hero - " .. card.subtype .. " "
  str = str .. "(" .. card.cost .. "): "
  str = str .. "1: " .. card.ATK_1 .. "/" .. card.HP_1 .. " "
  if card.base_text_1 then
    str = str .. card.base_text_1 .. " "
  end
  if card.base_text_2 then
    str = str .. card.base_text_2 .. " "
  end
  str = str .. "/ " .. card.mid_level .. ": "
  str = str .. card.ATK_2 .. "/" .. card.HP_2 .. " "
  if card.mid_text_1 then
    str = str .. card.mid_text_1 .. " "
  end
  if card.mid_text_2 then
    str = str .. card.mid_text_2 .. " "
  end
  str = str .. "/ " .. card.max_level .. ": "
  str = str .. card.ATK_3 .. "/" .. card.HP_3 .. " "
  if card.max_text_1 then
    str = str .. card.max_text_1 .. " "
  end
  if card.max_text_2 then
    str = str .. card.max_text_2 .. " "
  end
  return str
end

function format_card(card)
  if card.type == "Hero" then return format_hero(card) end
  if card.type == "Color" then return format_color(card.name) end
  if card.type == "Spec" then return format_spec(card.name) end
  local str = card.name .. " - "
  if card.spec then
    str = str .. card.spec
  else
    str = str .. card.color
  end
  if card.tech_level then
    str = str .. " Tech ".. (({[0]="0", "I", "II", "III"})[card.tech_level])
  end
  str = str .. " " .. card.type
  if card.subtype then
    str = str .. " - " .. card.subtype
  end
  if card.target_icon then
    str = str .. " ◎ "
  end
  if card.cost then
    --str = str .. " " .. circled_digits[card.cost] .. " :"
    str = str .. " (" .. card.cost .. "):"
  end
  if card.ATK then
    str = str .. " " .. card.ATK .. "/" .. card.HP
  elseif card.HP then
    str = str .. " " .. card.HP .. "HP"
  end
  local rules_text = ""
  for i=1,4 do
    if card["rules_text_"..i] then
      rules_text = rules_text .. " " .. card["rules_text_"..i]
    end
  end
  if rules_text ~= "" then
    if card.HP then
      str = str .. " -"
    end
    str = str .. rules_text
  end
  return str
end

function format_didyoumean(cards)
  local str = "Did you mean "
  if #cards == 2 then
    str = str .. cards[1].name .. " or " .. cards[2].name .. "?"
    return str
  end
  for i=1,#cards-1 do
    str = str .. cards[i].name .. ", "
  end
  str = str .. "or " .. cards[#cards].name .. "?"
  return str
end

function handle_codex(reply_to, args)
  local name = table.concat(args):lower()
  for _,card in pairs(codex_cards) do
    if card.name:gsub('%W',''):lower() == name then
      TCP_sock:send("PRIVMSG "..reply_to.." :"..format_card(card).."\r\n")
      return
    end
  end
  local bests = {}
  local best_score = 99999999
  for _,card in pairs(codex_cards) do
    local this_score = levenshtein_distance(card.name:gsub('%W',''):lower(), name)
    if this_score < best_score then
      best_score = this_score
      bests = {card}
    elseif this_score == best_score then
      bests[#bests+1] = card
    end
  end
  if #bests == 1 then
    TCP_sock:send("PRIVMSG "..reply_to.." :"..format_card(bests[1]).."\r\n")
    return
  end
  if #bests <= 5 then
    TCP_sock:send("PRIVMSG "..reply_to.." :"..format_didyoumean(bests).."\r\n")
    return
  end
end

function handle_msg(msg)
  parts = msg:split(" ")
  if parts[1] == "PING" then
    TCP_sock:send("PONG "..parts[2].."\r\n")
    can_join = true
  end
  if parts[1] and parts[1][1] == ":" and parts[2] == "PRIVMSG" then
    local channel = parts[3]
    local cmd = parts[4]
    local args = {}
    for i=5, #parts do args[#args+1] = parts[i] end
    local reply_to = channel
    if reply_to[1] ~= "#" then
      reply_to = parts[1]:sub(2):split("!")[1]
    end
    if cmd == ":!codex" then
      handle_codex(reply_to, args)
    end
  end
end

while true do
  local junk, err, data = TCP_sock:receive('*a')
  if not err then
    print("oh teh noes")
    data = junk
  end
  print(data)
  leftovers = leftovers .. data
  msgs = leftovers:split("\r\n")
  print(json.encode(msgs))
  if leftovers[#leftovers] == "\n" then
    leftovers = ""
  else
    leftovers = msgs[#msgs] or ""
    msgs[#msgs] = nil
  end
  for i=1,#msgs do
    handle_msg(msgs[i])
  end
  if not sent_nick then
    TCP_sock:send("NICK disguised_monkey\r\n")
    TCP_sock:send("USER disguised_monkey 8 * :Real disguised_monkey\r\n")
    sent_nick = true
  end
  if can_join and not joined then
    TCP_sock:send("JOIN :#sirlin\r\n")
    joined = true
  end
  socket.select({TCP_sock}, {}, 1)
end