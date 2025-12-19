local balancer = require "ngx.balancer"

local _M = {
}

function _M.Work()
    local pos = string.find(ngx.ctx.dbip, ":")
    if pos ~= nil then
        ngx.ctx.dbip = "[" .. ngx.ctx.dbip .. "]"
    end

    ngx.log(ngx.INFO, "begin connect to dstSource ", ngx.ctx.dbip, ":", ngx.ctx.dbport, ", dbdomain ", ngx.ctx.dbdomain)

    local ok, err = balancer.set_current_peer(ngx.ctx.dbip, ngx.ctx.dbport)
    if not ok then
        ngx.log(ngx.ERR, "failed to set the current peer: ", err)
        return ngx.exit(ngx.ERROR)
    end
end

return _M