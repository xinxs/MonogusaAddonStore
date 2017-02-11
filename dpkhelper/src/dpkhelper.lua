--アドオン名（大文字）
local addonName = "DPKHelper";
local addonNameUpper = string.upper(addonName);
local addonNameLower = string.lower(addonName);
--作者名
local author = "MONOGUSA";

--アドオン内で使用する領域を作成。以下、ファイル内のスコープではグローバル変数gでアクセス可
_G["ADDONS"] = _G["ADDONS"] or {};
_G["ADDONS"][author] = _G["ADDONS"][author] or {};
_G["ADDONS"][author][addonNameUpper] = _G["ADDONS"][author][addonNameUpper] or {};
local g = _G["ADDONS"][author][addonNameUpper];

--設定ファイル保存先
g.settingsFileLoc = string.format("../addons/%s/settings.json", addonNameLower);

--ライブラリ読み込み
local acutil = require('acutil');

--デフォルト設定
if not g.loaded then
  g.settings = {
    --有効/無効
    enable = true,
    start = false,
    --フレーム表示場所
    position = {
      x = 500,
      y = 500
    }
  };
end

--lua読み込み時のメッセージ
CHAT_SYSTEM(string.format("%s.lua is loaded", addonNameLower));

function DPKHELPER_SAVE_SETTINGS()
  acutil.saveJSON(g.settingsFileLoc, g.settings);
end

--マップ読み込み時処理（1度だけ）
function DPKHELPER_ON_INIT(addon, frame)
  g.addon = addon;
  g.frame = frame;

  frame:ShowWindow(0);
  acutil.slashCommand("/dpkh", DPKHELPER_PROCESS_COMMAND);
  if not g.loaded then
    local t, err = acutil.loadJSON(g.settingsFileLoc, g.settings);
    if err then
      --設定ファイル読み込み失敗時処理
      CHAT_SYSTEM(string.format("[%s] cannot load setting files", addonName));
    else
      --設定ファイル読み込み成功時処理
      g.settings = t;
    end
    g.loaded = true;
  end

  --設定ファイル保存処理
  DPKHELPER_SAVE_SETTINGS();
  --メッセージ受信登録処理
  addon:RegisterMsg("FPS_UPDATE", "DPKHELPER_WATCH_WIKI_UPDATE");
  addon:RegisterMsg("MON_ENTER_SCENE", "DPKHELPER_ON_MON_ENTER_SCENE");

  --コンテキストメニュー
  frame:SetEventScript(ui.RBUTTONDOWN, "DPKHELPER_CONTEXT_MENU");
  --ドラッグ
  frame:SetEventScript(ui.LBUTTONUP, "DPKHELPER_END_DRAG");

  --フレーム初期化処理
  if g.settings.start then
    DPKHELPER_INIT_ENEMYTEXT();
  else
    DPKHELPER_INIT_FRAME();
  end

  --再表示処理
  if g.settings.enable then
    frame:ShowWindow(1);
  else
    frame:ShowWindow(0);
  end
  --Moveではうまくいかないので、OffSetを使用する…
  frame:Move(0, 0);
  frame:SetOffset(g.settings.position.x, g.settings.position.y);
end

function DPKHELPER_INIT_FRAME()
  local frame = g.frame;

  --フレーム初期化処理
  local text = frame:CreateOrGetControl("richtext", "text", 5, 10, 0, 0);
  tolua.cast(text, "ui::CRichText");
  text:SetText("{@st48}DPK Helper{/}");
  text:EnableHitTest(0);
  local button = frame:CreateOrGetControl("button", "startButton", 0, 10, 60, 20);
  tolua.cast(text, "ui::CButton");
  button:SetText("{@st48}Start{/}");
  button:SetEventScript(ui.LBUTTONDOWN, 'DPKHELPER_START_COUNT');
  button:SetGravity(ui.RIGHT, ui.TOP);
  local w = text:GetWidth() + 20 + button:GetWidth();
  local h = button:GetHeight() + 10;
  frame:Resize(w, h);
  frame:ShowWindow(1);
end

function DPKHELPER_INIT_ENEMYTEXT()
  local frame = g.frame;
  frame:RemoveAllChild();

  local color = "FFFFFF";
  --計測中のチャンネルではない場合灰色
  if g.settings.mapName ~= session.GetMapName() or g.settings.channel ~= session.loginInfo.GetChannel() then
    color = "6666FF"
  end

  local text = frame:CreateOrGetControl("richtext", "text", 5, 10, 0, 0);
  tolua.cast(text, "ui::CRichText");
  local mapCls = GetClass("Map", g.settings.mapName);
  local title = string.format("{@st48}{#%s}%s ch%d{/}{/}",color, mapCls.Name, g.settings.channel + 1);
  text:SetText(title);
  text:EnableHitTest(0);
  local button = frame:CreateOrGetControl("button", "startButton", 0, 10, 60, 20);
  tolua.cast(text, "ui::CButton");
  button:SetText("{@st48}Reset{/}");
  button:SetEventScript(ui.LBUTTONDOWN, 'DPKHELPER_RESET_COUNT');
  button:SetGravity(ui.RIGHT, ui.TOP);


  --モンスター名のテキストを表示
  local y = 30
  local w = text:GetWidth() + 50;
  local h = button:GetHeight() + 10;
  frame:Resize(w, h);
  local maxWidth = w;

  for k, v in pairs(g.settings.enemyList) do
    local monCls = GetClass("Monster", k);
    local monGroup = frame:CreateOrGetControl("groupbox", "monGroup_"..k, 0, y, 0, 0);
    tolua.cast(monGroup, "ui::CGroupBox");
    monGroup:SetSkinName("none");
    monGroup:EnableHitTest(1);
    monGroup:SetUserValue("MONCLS", k);
    monGroup:SetEventScript(ui.RBUTTONDOWN, "DPKHELPER_ENEMY_CONTEXT_MENU");
    monGroup:SetEventScriptArgString(ui.RBUTTONDOWN, k);

    local monName = monGroup:CreateOrGetControl("richtext", "monName_"..k, 5, 0, 0, 0);
    local monCount = monGroup:CreateOrGetControl("richtext", "monCount_"..k, 5, 0, 0, 0);
    tolua.cast(monName, "ui::CRichText");
    tolua.cast(monCount, "ui::CRichText");

    monName:EnableHitTest(0);
    monCount:EnableHitTest(0);
    monName:SetText(string.format("{@st48}{#%s}%s{/}{/}", color, monCls.Name));
    monCount:SetText(string.format("{@st48}{#%s}%d{/}{/}", color, v.count));
    monCount:SetGravity(ui.RIGHT, ui.TOP);
    maxWidth = maxWidth < monName:GetWidth() and monName:GetWidth() or maxWidth;
    y = y + monName:GetHeight();
  end

  --時刻
  local time = frame:CreateOrGetControl("richtext", "time", 5, y, 0, 0);
  time:SetGravity(ui.RIGHT, ui.TOP);
  time:EnableHitTest(0);
  time:RunUpdateScript("DPKHELPER_UPDATE_TIME", 1);
  DPKHELPER_UPDATE_TIME();
  y = y + time:GetHeight();

  --サイズあわせ
  local h = y + 10;
  local w = maxWidth + 50;

  for k, v in pairs(g.settings.enemyList) do
    local monGroup = GET_CHILD(frame, "monGroup_"..k, "ui::CGroupBox");
    local monName = GET_CHILD(monGroup, "monName_"..k, "ui::CRichText");
    monGroup:Resize(maxWidth + 50, monName:GetHeight());
  end

  frame:Resize(w, h);
end


function DPKHELPER_UPDATE_TIME()
  if g.settings.start then
    local color = "FFFFFF";
    --計測中のチャンネルではない場合灰色
    if g.settings.mapName ~= session.GetMapName() or g.settings.channel ~= session.loginInfo.GetChannel() then
      color = "6666FF"
    end

    local time = GET_CHILD(g.frame, "time", "ui::CRichText");
    g.settings.startTime = g.settings.startTime or os.time()
    local totalSec = os.time() - g.settings.startTime
    local hour = math.floor(totalSec / 3600)
    local min = math.floor(totalSec % 3600 / 60)
    local sec = math.floor(totalSec % 60)
    
    local timeText = string.format("{@st48}{#%s}%02d:%02d:%02d{/}{/}", color,  hour, min, sec);
    time:SetText(timeText);
    return 1;
  end

  return 0;  
end

--コンテキストメニュー表示処理
function DPKHELPER_CONTEXT_MENU(frame, msg, argStr, argNum)
  local context = ui.CreateContextMenu("DPKHELPER_RBTN", addonName, 0, 0, 150, 100);

  if g.settings.start then
    ui.AddContextMenuItem(context, "Reset", "DPKHELPER_RESET_COUNT()");
    ui.AddContextMenuItem(context, "Stop", "DPKHELPER_STOP_COUNT()");
  else
    ui.AddContextMenuItem(context, "Start", "DPKHELPER_START_COUNT()");
  end
  context:Resize(150, context:GetHeight());
  ui.OpenContextMenu(context);
end

function DPKHELPER_ENEMY_CONTEXT_MENU(frame, msg, argStr, argNum)
  local className = argStr;
  local monCls = GetClass("Monster", className);
  local context = ui.CreateContextMenu("DPKHELPER_RBTN", monCls.Name, 0, 0, 150, 100);
  ui.AddContextMenuItem(context, "Reset　Count", string.format('DPKHELPER_RESET_COUNT_BY_CLASSNAME("%s")', className));
  context:Resize(150, context:GetHeight());
  ui.OpenContextMenu(context);
end


--表示非表示切り替え処理
function DPKHELPER_TOGGLE_FRAME()
  if g.frame:IsVisible() == 0 then
    --非表示->表示
    g.frame:ShowWindow(1);
    g.settings.enable = true;
  else
    --表示->非表示
    g.frame:ShowWindow(0);
    g.settings.enable = false;
  end

  DPKHELPER_SAVE_SETTINGS();
end

--フレーム場所保存処理
function DPKHELPER_END_DRAG()
  g.settings.position.x = g.frame:GetX();
  g.settings.position.y = g.frame:GetY();
  DPKHELPER_SAVE_SETTINGS();
end

--チャットコマンド処理（acutil使用時）
function DPKHELPER_PROCESS_COMMAND(command)
  local cmd = "";

  if #command > 0 then
    cmd = string.lower(table.remove(command, 1));
  else
    local msg = "/dpkh start{nl}"
    msg = msg.."計測開始{nl}";
    msg = msg.."/dpkh reset{nl}";
    msg = msg.."カウントリセット{nl}";
    msg = msg.."/dpkh stop{nl}";
    msg = msg.."計測終了{nl}";
    return ui.MsgBox(msg,"","Nope")
  end

  if cmd == "start" then
    DPKHELPER_START_COUNT();
    return;
  elseif cmd == "stop" then
    DPKHELPER_STOP_COUNT()
    return;
  end

  CHAT_SYSTEM(string.format("[%s] Invalid Command", addonName));
end

function DPKHELPER_START_COUNT()
  --敵リスト初期化処理
  g.settings.start = true;
  DPKHELPER_INIT_ENEMY_LIST();

  --近くにいる敵をリストに入れる
  local fndList, fndCnt = SelectObject(GetMyPCObject(), 800, "ENEMY")
  for i, enemy in ipairs(fndList) do
    local handle = GetHandle(enemy);
    DPKHELPER_ADD_MON_INTO_LIST(handle)
  end

  DPKHELPER_INIT_ENEMYTEXT();
  CHAT_SYSTEM(string.format("[%s] Count Start", addonName));
end

function DPKHELPER_STOP_COUNT()
  --敵リスト初期化処理
  g.settings.start = false;
  DPKHELPER_INIT_ENEMY_LIST();
  DPKHELPER_INIT_FRAME();
  CHAT_SYSTEM(string.format("[%s] Count Stop", addonName));
end

function DPKHELPER_RESET_COUNT()
  --敵リスト初期化処理
  for k, v in pairs(g.settings.enemyList) do
    v.count = 0;
    local gbox = GET_CHILD(g.frame, "monGroup_"..k, "ui::CGroupBox");
    local monCount = GET_CHILD(gbox, "monCount_"..k, "ui::CRichText");
    monCount:SetText("{@st48}"..v.count.."{/}");
  end

  CHAT_SYSTEM(string.format("[%s] Count Reset", addonName));
end

function DPKHELPER_RESET_COUNT_BY_CLASSNAME(className)
  --敵リスト初期化処理
  if g.settings.enemyList[className] then
    local v = g.settings.enemyList[className]
    local monCls = GetClass("Monster", className);
    v.count = 0;
    local gbox = GET_CHILD(g.frame, "monGroup_"..className, "ui::CGroupBox");
    local monCount = GET_CHILD(gbox, "monCount_"..className, "ui::CRichText");
    monCount:SetText("{@st48}"..v.count.."{/}");
    CHAT_SYSTEM(string.format("[%s] %s Count Reset", addonName, monCls.Name));
  end
end

--敵リスト初期化処理
function DPKHELPER_INIT_ENEMY_LIST()
  g.settings.enemyList = {};
  g.settings.mapName = session.GetMapName();
  g.settings.channel = session.loginInfo.GetChannel();
  g.settings.startTime = os.time();
  DPKHELPER_SAVE_SETTINGS()
end

function DPKHELPER_WATCH_WIKI_UPDATE()
  if not g.settings.start then
    return;
  end

  local frame = g.frame;
  local save = false;

  for k, v in pairs(g.settings.enemyList) do
    local monCls = GetClass("Monster", k);
    local wiki = GetWikiByName(monCls.Journal);
    local wikiCount = GetWikiIntProp(wiki, "KillCount")

    --SATSUGAI数に変更があった場合、カウントを更新する
    if v.wikiCount < wikiCount then
      save = true;
      --計測中のチャンネルと等しい場合
      if g.settings.mapName == session.GetMapName() and g.settings.channel == session.loginInfo.GetChannel() then
        local diff = wikiCount - v.wikiCount;
        v.count = v.count + diff;
        local gbox = GET_CHILD(g.frame, "monGroup_"..k, "ui::CGroupBox");
        local monCount = GET_CHILD(gbox, "monCount_"..k, "ui::CRichText");
        monCount:SetText("{@st48}"..v.count.."{/}");
      end
      --計測中のチャンネルと異なる場合、冒険日誌のカウントのみ更新する
      v.wikiCount = wikiCount;
    end
  end

  if save then
    DPKHELPER_SAVE_SETTINGS()
  end
end

function DPKHELPER_ON_MON_ENTER_SCENE(frame, msg, str, handle)
  DPKHELPER_ADD_MON_INTO_LIST(handle);
end

function DPKHELPER_ADD_MON_INTO_LIST(handle)
  if not g.settings.start then
    return;
  end

  --計測中のチャンネルと異なる場合
  if g.settings.mapName ~= session.GetMapName() or g.settings.channel ~= session.loginInfo.GetChannel() then
    return;
  end

  local actor = world.GetActor(handle);
  if actor and actor:GetObjType() == GT_MONSTER then
    local monCls = GetClassByType("Monster", actor:GetType());

    --敵対的
    if not g.settings.enemyList[monCls.ClassName] and monCls.Faction ~= "RootCrystal" and info.IsNegativeRelation(handle) ~= 0 then
      local wiki = GetWikiByName(monCls.Journal);
      if wiki then
        --キル数とWikiのキル数を保存
        g.settings.enemyList[monCls.ClassName] = {count = 0, wikiCount = GetWikiIntProp(wiki, "KillCount") or 0};
        --表示を更新
        DPKHELPER_INIT_ENEMYTEXT()
        DPKHELPER_SAVE_SETTINGS()
      end
    end
  end
end
