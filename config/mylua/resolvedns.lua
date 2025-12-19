local resolver = require "resty.dns.resolver"

local _M = {
}

local dns_servers = {
}

if #localnameservers > 0 then
    for _,value in ipairs(localnameservers) do
        local single_ns = {}
        table.insert(single_ns, value)
        table.insert(single_ns, dns_default_port)
        local double_ns = {}
        table.insert(double_ns, single_ns)
        table.insert(dns_servers, double_ns)
    end
end

local GetIpByDomain = function(dn)
    if #localnameservers == 0 then
        ngx.log(ngx.ERR, "local nameserver num is 0")
        return ngx.exit(ngx.ERROR)
    end

    local resolver_table = {}
    for i=1, #dns_servers do
        local r, err = resolver:new{
            nameservers = dns_servers[i],
            retrans = 2,      -- 5 retransmissions on receive timeout
            timeout = 2000,   -- 2 sec
            no_random = true, -- always start with first nameserver
        }
    
        if not r then
            ngx.log(ngx.ERR, "failed to instance the resolver: ", err)
            goto continue
        end

        table.insert(resolver_table, r)
    
        ::continue::
    end

    -- query ipv4 addr
    for i=1, #resolver_table do
        local answers, err, tries = resolver_table[i]:query(dn, {qtype = resolver_table[i].TYPE_A})
        if answers == nil then
            ngx.log(ngx.ERR, "TYPE_A, failed to query the DNS server: ", err)
            goto continue
        end

        if answers.errcode then
            ngx.log(ngx.ERR, "TYPE_A, server returned error code: ", answers.errcode)
            goto continue
        end

        for i, ans in ipairs(answers) do
            return ans.address
        end

        break

        ::continue::
    end

    -- query ipv6 addr
    for i=1, #resolver_table do
        local answers, err, tries = resolver_table[i]:query(dn, {qtype = resolver_table[i].TYPE_AAAA})
        if answers == nil then
            ngx.log(ngx.ERR, "TYPE_AAAA, failed to query the DNS server: ", err)
            goto continue
        end

        if answers.errcode then
            ngx.log(ngx.ERR, "TYPE_AAAA, server returned error code: ", answers.errcode)
            goto continue
        end

        for i, ans in ipairs(answers) do
            return ans.address
        end

        break

        ::continue::
    end

    return nil
end

_M.GetIpByDomain = GetIpByDomain
return _M