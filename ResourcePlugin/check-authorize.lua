local base64 = require("base64")
local cjson = require("cjson")
local ngx =ngx

local plugin_name="check-authorize"

local _M = {
        version = 1.0,
        priority = 1000,
        name = plugin_name
}

function _M.access()

    local headers = ngx.req.get_headers()
    local userinfoHeader = headers["x-userinfo"]
    ngx.log(ngx.ERR, "Plugin Working")

    if userinfoHeader then

        local decodedData, decodeErr = ngx.decode_base64(userinfoHeader)

        if not decodeErr then
            local jsonData, parseErr = cjson.decode(decodedData)

            if not parseErr then
                if type(jsonData) == "table" then
                    ngx.log(ngx.INFO, "Valid x-userinfo payload detected")

                    local redirectUri = ngx.var.upstream_url

                    for key, value in pairs(jsonData) do
                        ngx.req.set_header(key, value)
                    end

                    local pathOnly = ngx.re.match(ngx.var.uri, "^([^?]+)")
                    local path = pathOnly and pathOnly[1] or ""

                    local requestBody = {
                        path = path
                    }

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
