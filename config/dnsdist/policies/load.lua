-- Load optional dnsdist policy modules (generated at container start).
-- Enabled via DNSDIST_POLICIES env (comma-separated basenames).

local policyDir = "/etc/dnsdist/policies"
local enabled = os.getenv("DNSDIST_POLICIES") or ""

if enabled == "" then
  return
end

for name in string.gmatch(enabled, "[^,%s]+") do
  local path = policyDir .. "/" .. name .. ".lua"
  local ok, err = pcall(dofile, path)
  if not ok then
    warnlog("policy load failed for " .. path .. ": " .. tostring(err))
  else
    infolog("loaded dnsdist policy: " .. name)
  end
end
