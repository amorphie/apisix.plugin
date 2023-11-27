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
        priority = 1000,
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

function _M.access(conf)

    local headers = ngx.req.get_headers()
    local userinfoHeader = headers["x-userinfo"]
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
                        ngx.req.set_header(key, value)
                    end

                    local requestBody = ngx.var.uri
                    local json_data = cjson.encode({requestBody})
                    local targetUrl  = conf.endpoint
                    ngx.log(ngx.ERR, "URL =>  ", conf.endpoint)
                    ngx.log(ngx.ERR, "***************Headers => ", cjson.encode(headers))
                    ngx.log(ngx.ERR, "***************REQUESTBODY => ",  cjson.encode(requestBody))
                    local httpc = http.new()
                    local res, err = httpc:request_uri(conf.endpoint, {
                        method = "POST",
                        body = cjson.encode(requestBody),
                        headers =headers
                    })                  
-- İstek başarılı ise
if res then
    -- Cevap kodunu kontrol et
    if res.status == 200 then
        -- Başarılı cevap
        ngx.log(ngx.ERR,"POST request succesfull. Response Code: ", res.status, "Return Message: ", res.body)
    else        
        ngx.say("POST Request unsuccesfull. Error Code: ", res.status, " Error Message: ", res.body)
        ngx.exit(res.status)
    end
else
    -- İstek hatası
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
