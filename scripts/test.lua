local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h:h")
vim.opt.rtp:prepend(root)

local test_dir = root .. "/tests"
local files = vim.fn.globpath(test_dir, "*_spec.lua", false, true)
table.sort(files)

local total = 0
local passed = 0
local failures = {}

for _, file in ipairs(files) do
  package.loaded["tests.helpers"] = nil
  local specs = assert(loadfile(file))()
  for _, spec in ipairs(specs) do
    total = total + 1
    local ok, err = xpcall(spec.fn, debug.traceback)
    if ok then
      passed = passed + 1
      io.stdout:write(string.format("PASS %s\n", spec.name))
    else
      failures[#failures + 1] = {
        name = spec.name,
        err = err,
      }
      io.stdout:write(string.format("FAIL %s\n", spec.name))
    end
  end
end

io.stdout:write(string.format("\n%d/%d tests passed\n", passed, total))

if #failures > 0 then
  io.stdout:write("\nFailures:\n")
  for _, failure in ipairs(failures) do
    io.stdout:write(string.format("\n[%s]\n%s\n", failure.name, failure.err))
  end
  os.exit(1)
end

os.exit(0)
