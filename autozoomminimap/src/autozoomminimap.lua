local author = 'NAYURI';
local addonName = 'AutoZoomMiniMap';
local addonNameUpper = string.upper(addonName);
local addonNameLower = string.lower(addonName);

_G['ADDONS'] = _G['ADDONS'] or {};
_G['ADDONS'][author] = _G['ADDONS'][author] or {};
_G['ADDONS'][author][addonNameUpper] = _G['ADDONS'][author][addonNameUpper] or {};
local g = _G['ADDONS'][author][addonNameUpper];
g.settingsFile = string.format('../addons/%s/settings.json', addonNameLower);

local acutil = require('acutil');

if not g.loaded then
  g.settings = {
    -- 有効/無効
    enable = false,
    -- 自動ズーム
    autoZoomSize = 120, -- 10倍した値を使用
  };
end

function g.SaveSettings()
  acutil.saveJSON(g.settingsFile, g.settings);
end

function g.SetupHook(str, func)
  g.hook[str] = g.hook[str] or _G[str];
  _G[str] = func;
end

function g.ProcessCommand(cmd)
  local arg = ''; 
  if #cmd > 0 then 
    arg = string.lower(table.remove(cmd, 1)); 
  else
    g.Update(not(g.settings.enable));
    return;
  end
  if arg == 'on' then
    g.Update(true);
    return;
  elseif arg == 'off' then
    g.Update(false);
    return;
  elseif tonumber(arg) then
    local zoomRatio = tonumber(arg);
    if zoomRatio >= 10 and zoomRatio <= 500 then
      g.settings.autoZoomSize = zoomRatio;
      g.Update(true);
      return;
    end
  end
  CHAT_SYSTEM(string.format('[%s] Invalid Command', addonName));
end

function g.Update(flag)
  g.settings.enable = flag;
  g.SaveSettings();

  local frame = ui.GetFrame('minimap');
  UPDATE_MINIMAP(frame);
  MINIMAP_CHAR_UDT(frame);
end

function g.GET_MINIMAPSIZE()
  if not g.settings.enable then
    return g.hook['GET_MINIMAPSIZE']();
  else
    local frame = ui.GetFrame('map');
    local mapui = GET_CHILD(frame, 'map', 'ui::CPicture');

    -- rader.lua:RADER_AUTO_ZOOM
    local zoomSize = g.settings.autoZoomSize * 10;
    local mapprop = g.mapprop;

    -- 1だけ動かしたマップの位置
    local w = mapui:GetImageWidth();
    local h = mapui:GetImageHeight();
    local pos1 = mapprop:WorldPosToMinimapPos(0, 0, w, h);
    local pos2 = mapprop:WorldPosToMinimapPos(1, 0, w, h);
    -- 距離1あたりのピクセル
    local pix = pos2.x - pos1.x;
    -- 距離100で見える範囲をフレームの長さに合わせた場合
    local frame_mm = ui.GetFrame('minimap');
    local zoomRate = frame_mm:GetWidth() / (pix * zoomSize);
    local percentage = zoomRate * 100 - 100;
    -- CHAT_SYSTEM('percentage'..percentage);
    return percentage;
  end
end

function g.SET_MINIMAPSIZE(cursize)
  if not g.settings.enable then
    g.hook['SET_MINIMAPSIZE'](cursize);
  end
end

function g.SET_MINIMAP_SIZE(amplify)
  g.settings.enable = false;
  g.SaveSettings();

  g.hook['SET_MINIMAP_SIZE'](amplify);
end

function g.UPDATE_MINIMAP(frame, isFirst)
  g.hook['UPDATE_MINIMAP'](frame, isFirst);

  local cursize = GET_MINIMAPSIZE();
  local zoominfo = frame:GetChild('ZOOM_INFO');
  local percent = (100 + cursize) / 100;
  zoominfo:SetText(string.format('x{b}%1.2f', percent));

  local azmm = frame:GetChild('AUTOZOOMMINIMAP');
  if g.settings.enable then
    azmm:SetText('{@st41}{#00FF00}A');
  else
    azmm:SetText('{@st41}A');
  end
end

function AUTOZOOMMINIMAP_GAME_START()
  local frame = ui.GetFrame('minimap');
  local azmm;
  if MAPMATE_ON_INIT ~= nil then
    azmm = tolua.cast(frame:CreateOrGetControl('button', 'AUTOZOOMMINIMAP', 0, 0, 30, 24), 'ui::CButton');
    azmm:SetGravity(ui.RIGHT, ui.BOTTOM);
    azmm:SetMargin(0, 0, 2, 46);
  else
    azmm = tolua.cast(frame:CreateOrGetControl('button', 'AUTOZOOMMINIMAP', 0, 0, 30, 30), 'ui::CButton');
    azmm:SetGravity(ui.LEFT, ui.BOTTOM);
    azmm:SetMargin(55, 0, 0, 5);
  end
  azmm:SetClickSound('button_click_big');
  azmm:SetOverSound('button_over');
  azmm:SetEventScript(ui.LBUTTONUP, 'AUTOZOOMMINIMAP_TOGGLE');
  azmm:ShowWindow(1);

  UPDATE_MINIMAP(frame);
  MINIMAP_CHAR_UDT(frame);
end

function AUTOZOOMMINIMAP_TOGGLE()
  ui.Chat('/azmm');
end

g.hook = g.hook or {}
function AUTOZOOMMINIMAP_ON_INIT(addon, frame)
  g.addon = addon;
  g.frame = frame;

  local mapName = session.GetMapName();
  g.mapprop = geMapTable.GetMapProp(mapName);

  if not g.loaded then
    local t, err = acutil.loadJSON(g.settingsFile, g.settings);
    if not err then
      g.settings = t;
    end
    g.loaded = true;
  end
  g.SaveSettings();

  addon:RegisterMsg('GAME_START', 'AUTOZOOMMINIMAP_GAME_START');

  g.SetupHook('GET_MINIMAPSIZE',  g.GET_MINIMAPSIZE);
  g.SetupHook('SET_MINIMAPSIZE',  g.SET_MINIMAPSIZE);
  g.SetupHook('SET_MINIMAP_SIZE', g.SET_MINIMAP_SIZE);
  g.SetupHook('UPDATE_MINIMAP',   g.UPDATE_MINIMAP);

  acutil.slashCommand('/azmm', g.ProcessCommand);
end
