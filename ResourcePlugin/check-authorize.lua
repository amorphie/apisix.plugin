local base64 = require("base64")
local cjson = require("cjson")
local ngx =ngx
local core     = require("apisix.core")
local io       = require("io")
local http = require("resty.http")

local plugin_name="check-authorize"

local plugin_schema = {
    type = "object",
    properties = {
        endpoint = {
            description = "endpoint",
            type        = "string",
            minLength   = 1,
            maxLength   = 4096,
        },
    },
}
local _M = {
        version = 1.0,
        priority = 2585,
        name = plugin_name,
        schema   = plugin_schema,
}
-- Function to check if the plugin configuration is correct
function _M.check_schema(conf)
  -- Validate the configuration against the schema
  local ok, err = core.schema.check(plugin_schema, conf)
  -- If validation fails, return false and the error
  if not ok then
      return false, err
  end
  -- If validation succeeds, return true
  return true
end

function _M.rewrite(conf, ctx)

    local headers = ngx.req.get_headers()
    local userinfoHeader = headers["x-userinfo"]
    local req_body_data, err = ngx.req.get_body_data()
    ngx.log(ngx.ERR, "Plugin Working")

    if userinfoHeader then
        local decodedData, decodeErr = ngx.decode_base64(userinfoHeader)
        if not decodeErr then
            local jsonData, parseErr = cjson.decode(decodedData)
            if not parseErr then
                if type(jsonData) == "table" then
                    ngx.log(ngx.ERR, "Valid x-userinfo payload detected")
                    local headers = {
                    ["Content-Type"] = "application/json",
                    }
                    for key, value in pairs(jsonData) do
                        headers[key] = value
                        core.request.set_header(ctx, key, value)
                    end
                    local json_data = cjson.encode({
                        url = ngx.var.uri or "",
                        data = req_body_data or "",
                    })
                            -- ngx.req.get_uri_args() ile sorgu parametrelerini al
                    local args = ngx.req.get_uri_args()
                    for key, value in pairs(args) do
                        headers[key] = value
                    end
                    local targetUrl  = conf.endpoint
                    local httpc = http.new()
                    local res, err = httpc:request_uri(conf.endpoint, {
                        method = "POST",
                        body = json_data,
                        headers =headers
                    })                  
if res then
    -- Cevap kodunu kontrol et
    if res.status == 200 then
        -- Başarılı cevap
        ngx.log(ngx.ERR, "POST request successful. Response Code: ", res.status, " Return Message: ", res.body)
    else
        ngx.log(ngx.ERR, "POST Request unsuccessful. Error Code: ", res.status, " Error Message: ", res.body)
        ngx.status = ngx.HTTP_UNAUTHORIZED -- 401 durum kodunu ayarla
        ngx.say("Unauthorized") -- Opsiyonel: İstek yanıtında bir mesaj gönderebilirsiniz
        return ngx.exit(ngx.HTTP_UNAUTHORIZED) -- 401 durum koduyla işlemi sonlandır
    end
else
    ngx.say("POST Request unsuccesfull. Error: ", err)
end
                else
                    ngx.log(ngx.ERR, "Invalid JSON payload in x-userinfo header. Expected a JSON object.")
                    ngx.exit(ngx.HTTP_BAD_REQUEST)
                end
            else
                ngx.log(ngx.ERR, "Error decoding JSON payload: ", parseErr)
                ngx.exit(ngx.HTTP_BAD_REQUEST)
            end
        else
            ngx.log(ngx.ERR, "Error decoding base64 content: ", decodeErr)
            ngx.exit(ngx.HTTP_BAD_REQUEST)
        end
    else
        ngx.log(ngx.INFO, "x-userinfo Header not found")
        ngx.exit(ngx.HTTP_BAD_REQUEST)
    end
end

return _M
