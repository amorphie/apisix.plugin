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

    -- Bu değişken, yanıtın tamamının alındığını belirtir
    local eof = ngx.arg[2]

    -- Eğer eof true ise, bu son paket demektir
    if eof then
        local status_code = ngx.status
        local headers = ngx.resp.get_headers()
        local body = ngx.arg[1]

        local requestBody = cjson.encode({
            responseCode = status_code or "",
            body = body or "",
        })

        local targetUrl = conf.endpoint
        ngx.log(ngx.ERR, "URL =>  ", conf.endpoint)
        ngx.log(ngx.ERR, "response-code-transformation---***************Headers => ", cjson.encode(headers))
        ngx.log(ngx.ERR, "response-code-transformation---***************REQUESTBODY => ", requestBody)

        local httpc = http.new()
        local res, err = httpc:request_uri(targetUrl, {
            method = "POST",
            body = requestBody,
            headers = headers,
        })

        -- Handle the response as needed
        ngx.arg[1] = res.body
        ngx.eof()
    end
end

return _M
