function splitstring(input, delimiter)
    if type(delimiter) ~= "string" or #delimiter <= 0 then
        return
    end

    local start = 1
	local dstsubstr = ""
    local arr = {}

    while true do
        local pos = string.find(input, delimiter, start, true)
        if not pos then
            break
        end

		dstsubstr = string.sub(input, start, pos - 1)
		if #dstsubstr ~= 0 then
	        table.insert (arr, dstsubstr)
		end
        start = pos + string.len (delimiter)
    end

	dstsubstr = string.sub(input, start)
	if #dstsubstr ~= 0 then
	    table.insert (arr, dstsubstr)
	end

    return arr
end

--global var
localnameservers = {}

for line in io.lines("/etc/resolv.conf") do
    local tinfo = splitstring(line, " ")
    if tinfo ~= nil and tinfo[1] == "nameserver" and tinfo[2] ~= nil then
        table.insert(localnameservers, tinfo[2])
    end
end

ngx.log(ngx.NOTICE, "localnameservers.size() = ", #localnameservers)
for _,value in ipairs(localnameservers) do
    ngx.log(ngx.NOTICE, "nginx start nameserver: ", value)
end