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

codex_cards = json.decode(file_contents("codex.json"))

function format_card(card)
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
    str = str .. " (" .. card.cost .. "):"
  end
  if card.ATK then
    str = str .. " " .. card.ATK .. "/" .. card.HP
  elseif card.HP then
    str = str .. " " .. card.HP .. "HP"
  end
  local rules_text = ""
  for i=1,3 do
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

function handle_codex(reply_to, args)
  local name = table.concat(args):lower()
  for _,card in pairs(codex_cards) do
    if card.name:gsub("%s+", ""):lower() == name then
      TCP_sock:send("PRIVMSG "..reply_to.." :"..format_card(card).."\r\n")
      return
    end
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
  socket.sleep(1)
  print("slept")
end