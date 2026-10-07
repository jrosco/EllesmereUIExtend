-- Integration tests inspect EUI without bundling or modifying its source.
-- EUI_TEST_ROOT points to the checkout containing EllesmereUI_Kick.lua.
local root = os.getenv("EUI_TEST_ROOT") or "../EllesmereUI"
return function(path)
    local file = root .. "/" .. path
    local chunk, err = loadfile(file)
    assert(chunk, "Missing upstream test dependency: " .. file
        .. ". Set EUI_TEST_ROOT to an EUI checkout.\n" .. tostring(err))
    return chunk
end
