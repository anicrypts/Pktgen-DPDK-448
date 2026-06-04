local function inspect(tbl, prefix)
    prefix = prefix or "pktgen"
    for k, v in pairs(tbl) do
        local key = prefix .. "." .. k
        print(key, type(v))
        if type(v) == "table" then
            inspect(v, key)
        end
    end
end
inspect(pktgen)
