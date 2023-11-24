local base64 = require("base64")
local cjson = require("cjson")
local ngx =ngx
local core     = require("apisix.core")
local io       = require("io")

local plugin_name="check-authorize"

local plugin_schema = {
    type = "object",
    properties = {
        uri = {
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
                    
                    local redirectUri = conf.uri

                    for key, value in pairs(jsonData) do
                        ngx.log(ngx.ERR, "JSONDATA ", value)
                        ngx.req.set_header(key, value)
                    end

                    local requestBody = {
                       ngx.var.uri
                    }
                    ngx.log(ngx.ERR, "URL =>  ", conf.uri)
                    ngx.log(ngx.ERR, "REQUEST BODY =>  ", cjson.encode(requestBody))
                    local res = ngx.location.capture(redirectUri, { method = ngx.HTTP_POST, body = cjson.encode(requestBody) })

                    if res.status == 200 then
                        ngx.say("Redirect Service Response: ", res.body)
                    else
                        ngx.log(ngx.ERR, "Error while making subrequest. Status: ", res.status)
                        ngx.exit(res.status)
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
    end
end

return _M
