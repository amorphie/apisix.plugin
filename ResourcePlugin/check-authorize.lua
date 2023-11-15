

local base64 = require("base64")
local cjson = require("cjson")

local _M = {}

function _M.access()

    local headers = ngx.req.get_headers()
    local userinfoHeader = headers["x-userinfo"]

    if userinfoHeader then

        local decodedData = ngx.decode_base64(userinfoHeader)

        local jsonData = cjson.decode(decodedData)

        local redirectUri = "/your/redirect/service"

        local headers = {
            ["Content-Type"] = "application/json",
            ["Your-Custom-Header"] = jsonData.key 
        }
        local requestBody = {
            url = ngx.var.uri 
        }


        local res = ngx.location.capture(redirectUri, { method = ngx.HTTP_POST, body = cjson.encode(requestBody), headers = headers })

        if res.status == 200 then
            ngx.say("Redirect Service Response: ", res.body)
        else
            ngx.log(ngx.ERR, "Error while making subrequest. Status: ", res.status)
            ngx.exit(res.status)
        end
    else
        ngx.log(ngx.INFO, "x-userinfo Header not found")
    end
end

return _M
