addon.name    = 'e2j'
addon.author  = 'Silkrea'
addon.version = '1.0'
addon.desc    = 'e2j'

-------------------------------------------------
-- ■ パス
-------------------------------------------------
local base_path = addon.path .. '\\'
local py_path   = base_path .. 'fetch.py'
local dict_path = base_path .. 'dict.lua'
local unknown_path = base_path .. 'unknown.txt'

-------------------------------------------------
-- ■ Python実行
-------------------------------------------------
local function run_python()
    os.execute('python "' .. py_path .. '"')
end

-------------------------------------------------
-- ■ 辞書
-------------------------------------------------
local dict = {}

local function load_dict()
    dict = dofile(dict_path)
end

-------------------------------------------------
-- ■ 入力正規化（記号対策）
-------------------------------------------------
local function normalize_input(str)

    if type(str) ~= "string" then return str end

    str = str:gsub("-", " ")
    str = str:gsub("–", " ")
    str = str:gsub("—", " ")

    str = str:gsub("!", "!")
    str = str:gsub("?", "?")
    str = str:gsub(",", ",")
    str = str:gsub("^Q", "")

    return str
end

-------------------------------------------------
-- ■ ログクリーニング（制御文字除去）
-------------------------------------------------
local function clean_log(str)

    if type(str) ~= "string" then return str end

    -- 制御文字
    str = str:gsub("[%c%z]", "")

    -- 不正バイト除去（重要）
    str = str:gsub("[\128-\255]", "")

    -- 色コード
    str = str:gsub("%^%x%x", "")

    -- soft hyphen
    str = str:gsub("\194\173", "")

    return str
end

-------------------------------------------------
-- ■ {}タグ保護
-------------------------------------------------
local function protect_braces(str)

    local map = {}
    local i = 0

    str = str:gsub("{.-}", function(s)
        i = i + 1
        map[i] = s
        return "##BR"..i.."##"
    end)

    return str, map
end

local function restore_braces(str, map)

    for i, v in pairs(map) do
        str = str:gsub("##BR"..i.."##", v)
    end

    return str
end

-------------------------------------------------
-- ■ SJIS変換
-------------------------------------------------
local ffi = require("ffi")

ffi.cdef[[
int MultiByteToWideChar(unsigned int, unsigned long,
    const char*, int, wchar_t*, int);
int WideCharToMultiByte(unsigned int, unsigned long,
    const wchar_t*, int, char*, int,
    const char*, int*);
]]

local CP_UTF8 = 65001
local CP_SJIS = 932

local function utf8_to_sjis(str)

    if type(str) ~= "string" then return str end

    local wlen = ffi.C.MultiByteToWideChar(CP_UTF8, 0, str, -1, nil, 0)
    local wbuf = ffi.new("wchar_t[?]", wlen)

    ffi.C.MultiByteToWideChar(CP_UTF8, 0, str, -1, wbuf, wlen)

    local blen = ffi.C.WideCharToMultiByte(CP_SJIS, 0, wbuf, -1, nil, 0, nil, nil)
    local buf = ffi.new("char[?]", blen)

    ffi.C.WideCharToMultiByte(CP_SJIS, 0, wbuf, -1, buf, blen, nil, nil)

    return ffi.string(buf)
end

-------------------------------------------------
-- ■ unknownログ
-------------------------------------------------
local function log_unknown(msg)

    local f = io.open(unknown_path, "a")
    if f then
        f:write(msg .. "\n")
        f:close()
    end
end

-------------------------------------------------
-- ■ 翻訳（完全＋部分一致＋タグ保護）
-------------------------------------------------
local function translate(msg)

    if type(msg) ~= "string" then return nil end

    msg = clean_log(msg)
    msg = normalize_input(msg)

    local protected, map = protect_braces(msg)

    local result = protected

    -- ① 完全一致
    if dict[result] then
        return restore_braces(dict[result], map)
    end

    local hit = false

    -- ② 部分一致（複数）
    for eng, jpn in pairs(dict) do

        if #eng >= 3 then

            if result:find(eng, 1, true) then
                result = result:gsub(eng, jpn)
                hit = true
            end

        end
    end

    if hit then
        return restore_braces(result, map)
    end

    return nil
end

-------------------------------------------------
-- ■ text_in
-------------------------------------------------
ashita.events.register('text_in', 'e2j_cb', function (e)

    if not e or not e.message_modified then return end

    local msg = e.message_modified

    local res = translate(msg)

    if res then
        e.message_modified = utf8_to_sjis(res)
    else
        --log_unknown(clean_log(msg))
    end

end)

-------------------------------------------------
-- ■ 初期化
-------------------------------------------------
--run_python()
load_dict()
print('[E2J] ready')