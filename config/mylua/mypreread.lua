local ffi = require("ffi")
local base = require("resty.core.base")
local C = ffi.C
local cjson = require "cjson";
local resolverdns = require("resolvedns")

local get_request = base.get_request
local subsystem = ngx.config.subsystem

local aessm4lib = ffi.load("/usr/local/openresty/lualib/libgocommonlib.so")
local aes_crypto_key = "63dTjxISXlwAso0n"
local aes_crypto_iv = "a1b2c3d4e5f6g7h8"

if subsystem == 'stream' then
    ffi.cdef[[
        void ngx_stream_lua_remove_bytes(ngx_stream_lua_request_t *r, int length, int flag);
		void ngx_stream_lua_add_custom_message(ngx_stream_lua_request_t *r, const unsigned char *custom_msg, size_t custom_msg_len, int flag);
        char* AESCBCDecrypt(const char* ciphertext, const char* key, const char* iv, char* errMsg, int errMsgLen);
        void FreeCString(char* str);
    ]]
end

local _M = {
}

-- AES解密函数
local aes_decrypt = function(input)
    local err_msg_len = 256
    local err_msg_buf = ffi.new("char[?]", err_msg_len)
    local result_ptr = aessm4lib.AESCBCDecrypt(input, aes_crypto_key, aes_crypto_iv, err_msg_buf, err_msg_len)
    if result_ptr == nil or result_ptr == ffi.NULL then
        if err_msg_buf[0] ~= 0 then  -- 错误消息非空
            ngx.log(ngx.INFO, "Decrypt failed, EncryptData: ", input, ", ErrMsg: ", ffi.string(err_msg_buf))
        end
        return nil
    end
    
    -- 将 C 字符串转换为 Lua 字符串
    local plain_proxy_data = ffi.string(result_ptr)

    -- 释放内存
    aessm4lib.FreeCString(result_ptr)

    ngx.log(ngx.INFO, "Decrypt Success, EncryptData: ", input)
    return plain_proxy_data
end

local ParseJsonData = function(proxydata)
    ngx.log(ngx.INFO, "ParseJsonData: ", proxydata)

    local status, lua_table = pcall(cjson.decode, proxydata)
    if not status then
        return "parse proxydata failed !"
    end

    local dstip = lua_table["dstip"]
    local dstport = lua_table["dstport"]
    local dstdomain = lua_table["dstdomain"]
    
    if dstip == nil or dstport == nil or dstdomain == nil then
        return "dstip or dstport or dstdomain is nil !"
    end

    if dstip == "" and dstdomain == "" then
        return "dstip and dstdomain is empty !"
    end

    if dstport == "" then
        return "dstport is empty !"
    end

    if dstdomain ~= "" then
        local dstiptmp = resolverdns.GetIpByDomain(dstdomain)
        if dstiptmp == nil then
            ngx.log(ngx.ERR, "GetIpByDomain failed, dstdomain: ", dstdomain)
            return ngx.exit(ngx.ERROR)
        else
            ngx.ctx.dbip = dstiptmp
            ngx.log(ngx.INFO, "GetIpByDomain success, dstip: ", dstiptmp, ", dstdomain: ", dstdomain)
        end
    else
        ngx.ctx.dbip = dstip
    end

    ngx.ctx.dbport = dstport
    ngx.log(ngx.INFO, "UseIp: ", ngx.ctx.dbip, ", Port: ", ngx.ctx.dbport, " connect dst resource")
end

function _M.Work(bDecryptData, bAddCustomMessage)
    local sock,err = ngx.req.socket(true)
    if not sock then
        ngx.log(ngx.ERR, "failed to create socket: ", err)
        return ngx.exit(ngx.ERROR)
    end

    local magic = sock:peek(5)
    if magic ~= "proxy" then
        ngx.log(ngx.ERR, "magic=", magic, ", != proxy")
        return ngx.exit(ngx.ERROR)
    end

    local data = sock:peek(7)
    data = string.sub(data, -2);
    local type_hi = string.byte(data, 1)
    local type_lo = string.byte(data, 2)
    local datalen = bit.lshift(type_hi, 8) + type_lo
    if datalen > 1024 then
        ngx.log(ngx.ERR, "datalen:", datalen, ", more than 1024")
        return ngx.exit(ngx.ERROR)
    end

    data = string.sub(sock:peek(7+datalen), 8, 7+datalen)
    if bDecryptData == true then
        data = aes_decrypt(data)
        if data == nil then
            return ngx.exit(ngx.ERROR)
        end
    end

    local result = ParseJsonData(data)
    if result ~= nil then
        ngx.log(ngx.ERR, result)
        return ngx.exit(ngx.ERROR)
    end

	local r = get_request()
    if not r then
        error("no request found")
    end

	C.ngx_stream_lua_remove_bytes(r, 7+datalen, 0)

	if bAddCustomMessage == true then
		local jsondata = {name = "zhangsan", age = 100}
		local json_str = cjson.encode(jsondata)
		C.ngx_stream_lua_add_custom_message(r, json_str, #json_str, 1)
	end
end

return _M
