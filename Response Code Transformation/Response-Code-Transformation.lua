local cjson = require("cjson")
local http = require("resty.http")

local plugin_name = "response-code-transformation"

local plugin_schema = {
    type = "object",
    properties = {
        endpoint = {
            description = "endpoint",
            type = "string",
            minLength = 1,
            maxLength = 4096,
        },
    },
}

local _M = {
    version = 1.0,
    priority = 100,
    name = plugin_name,
    schema = plugin_schema,
}

function _M.body_filter(conf)
    ngx.log(ngx.ERR, "------------------response-code-transformation Plugin Working---------------")

    local eof = ngx.arg[2]

    if eof then
        local status_code = ngx.status
        local headers = ngx.resp.get_headers()
        local body = ngx.arg[1]

        local requestBody = cjson.encode({
            responseCode = status_code or "",
            body = body or "",
        })

        local targetUrl = conf.endpoint
        local httpc = http.new()
        local res, err = httpc:request_uri(targetUrl, {
            method = "POST",
            body = requestBody,
            headers = headers,
        })

        -- Handle the response as needed

        -- Değiştirilmiş yanıtı son kullanıcıya gönderme
        ngx.arg[1] = res.body

        -- Yanıtın gönderildiğini işaretleme
        ngx.eof()
    end
end

return _M
