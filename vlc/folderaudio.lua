--[[
  folderaudio.lua — VLC 3.x interface (auto-loaded via extraintf=luaintf)
  D:\Movies\eng     → English, highest quality
  D:\Movies\Kannada → Kannada, highest quality
  D:\Movies\Hindi   → Hindi if present, else default
]]

local MOVIES_ROOT = "d:/movies/"

local FOLDER_LANGS = {
  eng = { "eng", "english", "en" },
  english = { "eng", "english", "en" },
  kannada = { "kan", "kannada", "kn" },
  kan = { "kan", "kannada", "kn" },
  hindi = { "hin", "hindi", "hi" },
  hin = { "hin", "hindi", "hi" },
}

local last_uri = nil
local last_applied = nil

local function lower(s)
  if not s then return "" end
  return string.lower(tostring(s))
end

local function decode_path(uri)
  if not uri then return nil end
  local path = vlc.strings.decode_uri(uri)
  path = path:gsub("^file:///", "")
  path = path:gsub("^file://", "")
  path = path:gsub("^/([A-Za-z]):", "%1:")
  path = path:gsub("\\", "/")
  return lower(path)
end

local function folder_prefs(path)
  if not path then return nil end
  if path:sub(1, #MOVIES_ROOT) ~= MOVIES_ROOT then
    return nil
  end
  local rest = path:sub(#MOVIES_ROOT + 1)
  local folder = rest:match("^([^/]+)")
  if not folder then return nil end
  return FOLDER_LANGS[folder]
end

local function lang_rank(text, prefs)
  if not prefs then return 0 end
  local t = " " .. lower(text) .. " "
  for i, code in ipairs(prefs) do
    if t:find("%[" .. code .. "%]") or t:find("%W" .. code .. "%W") then
      return (#prefs - i + 1) * 100
    end
  end
  return 0
end

local function quality_score(text)
  local t = lower(text or "")
  local score = 0

  if t:find("atmos", 1, true) or t:find("truehd", 1, true) then score = score + 50000000 end
  if t:find("dts%-hd") or t:find("dtshd", 1, true) then score = score + 45000000 end
  if t:find("eac3", 1, true) or t:find("dd%+") or t:find("ddp", 1, true) then score = score + 30000000 end
  if t:find("ac3", 1, true) or t:find("ac%-3") then score = score + 20000000 end
  if t:find("aac", 1, true) then score = score + 5000000 end

  if t:find("7%.1", 1, true) or t:find("channels:8", 1, true) then
    score = score + 8000000
  elseif t:find("5%.1", 1, true) or t:find("channels:6", 1, true) then
    score = score + 6000000
  elseif t:find("2%.0", 1, true) or t:find("stereo", 1, true) or t:find("channels:2", 1, true) then
    score = score + 2000000
  end

  local br = t:match("(%d+)%s*kbps")
  if br then
    score = score + tonumber(br) * 100
  else
    br = t:match("bitrate[%s:]*([%d]+)")
    if br then
      local n = tonumber(br)
      if n and n > 10000 then n = math.floor(n / 1000) end
      if n then score = score + n * 100 end
    end
  end

  return score
end

local function stream_infos(item)
  local list = {}
  if not item then return list end
  local ok, info = pcall(function() return item:info() end)
  if not ok or not info then return list end

  local rows = {}
  for cat, data in pairs(info) do
    if type(data) == "table" then
      local blob = lower(tostring(cat))
      local is_audio, is_video = false, false
      for k, v in pairs(data) do
        local lk, lv = lower(k), lower(tostring(v))
        blob = blob .. " " .. lk .. ":" .. lv
        if lk:find("type", 1, true) then
          if lv:find("audio", 1, true) then is_audio = true end
          if lv:find("video", 1, true) then is_video = true end
        end
        if lk == "codec" then
          if lv:find("^a_") or lv:find("aac", 1, true) or lv:find("ac3", 1, true)
            or lv:find("eac3", 1, true) or lv:find("dts", 1, true)
            or lv:find("truehd", 1, true) or lv:find("mp4a", 1, true) then
            is_audio = true
          end
          if lv:find("^v_") or lv:find("h264", 1, true) or lv:find("hev", 1, true)
            or lv:find("avc", 1, true) then
            is_video = true
          end
        end
      end
      if is_audio and not is_video then
        table.insert(rows, { cat = tostring(cat), blob = blob })
      end
    end
  end

  table.sort(rows, function(a, b) return a.cat < b.cat end)
  for _, r in ipairs(rows) do
    table.insert(list, r.blob)
  end
  return list
end

local function collect_tracks(input, item)
  local tracks = {}
  local values, texts = vlc.var.get_list(input, "audio-es")
  if not values then return tracks end

  local infos = stream_infos(item)
  local idx = 0
  for i, id in ipairs(values) do
    local nid = tonumber(id)
    if nid and nid >= 0 then
      idx = idx + 1
      local text = (texts and texts[i]) and tostring(texts[i]) or ("track " .. tostring(idx))
      local extra = infos[idx] or ""
      table.insert(tracks, {
        id = id,
        text = text,
        combined = lower(text) .. " " .. extra,
      })
    end
  end
  return tracks
end

local function pick_best(tracks, prefs)
  if not prefs or #tracks == 0 then return nil end

  local best_id, best_score = nil, -1
  local matched = false

  for _, tr in ipairs(tracks) do
    local lr = lang_rank(tr.combined, prefs)
    if lr > 0 then
      matched = true
      local score = lr * 100000000 + quality_score(tr.combined)
      if score > best_score then
        best_score = score
        best_id = tr.id
      end
    end
  end

  if not matched then return nil end
  return best_id
end

local function apply_for_uri(uri)
  local path = decode_path(uri)
  local prefs = folder_prefs(path)
  if not prefs then
    return true
  end

  local input = vlc.object.input()
  if not input then return false end

  local item = vlc.input.item()
  local tracks = collect_tracks(input, item)
  if #tracks == 0 then return false end

  local best = pick_best(tracks, prefs)
  if not best then
    return true -- Hindi rule: no match → keep default
  end

  local cur = vlc.var.get(input, "audio-es")
  if tostring(cur) ~= tostring(best) then
    vlc.var.set(input, "audio-es", best)
    vlc.msg.info("[folderaudio] " .. table.concat(prefs, "/") .. " → audio-es=" .. tostring(best))
  end
  return true
end

local tries = {}
while true do
  pcall(function()
    local item = vlc.input.item()
    if item then
      local uri = item:uri()
      if uri and uri ~= "" then
        if uri ~= last_uri then
          last_uri = uri
          last_applied = nil
          tries[uri] = 0
        end
        if last_applied ~= uri then
          tries[uri] = (tries[uri] or 0) + 1
          local ok = apply_for_uri(uri)
          if ok or tries[uri] >= 25 then
            last_applied = uri
          end
        end
      end
    else
      last_uri = nil
      last_applied = nil
    end
  end)
  vlc.misc.mwait(vlc.misc.mdate() + 400000)
end
