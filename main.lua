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
filenames = {"white", "blue", "black", "red", "green", "purple", "neutral"}
local used_names = {}
for _,name in pairs(filenames) do
  local cards = json.decode(file_contents(name..".json"))
  for _,card in pairs(cards) do
    if not used_names[card.name] then
      codex_cards[#codex_cards+1] = card
      used_names[card.name] = true
    end
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

function format_hero(card)
  return "I'm iron man."
end

function format_card(card)
  if card.type == "Hero" then return format_hero(card) end
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

handle_msg = function(msg)
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
    TCP_sock:send("JOIN :#disguised_dog\r\n")
    joined = true
  end
  socket.select({TCP_sock}, {}, 1)
end