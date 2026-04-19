local storage = require("split-typer.storage")

local M = {}

local HISTORY_CAP = 300

local definitions = {
  {
    id = "benchmark_prose_1m",
    key = "1",
    name = "Prose 1m",
    description = "One-minute stable prose baseline",
    duration = 60,
    profile = "prose",
    chunks = {
      "Programming is not about typing fast for its own sake. It is about keeping thought and execution close together, so ideas survive the trip from your head to the screen without friction.",
      "Touch typing feels slow while the movement system is rebuilding. That awkward phase is temporary. Consistent, accurate reps are what eventually make the keyboard disappear from conscious attention.",
    },
  },
  {
    id = "benchmark_prose_3m",
    key = "2",
    name = "Prose 3m",
    description = "Three-minute sustained prose benchmark",
    duration = 180,
    profile = "prose",
    chunks = {
      "Split keyboards reward deliberate technique. They expose every lazy diagonal reach and every habit built on looking down. The payoff is not just speed. The payoff is cleaner movement and more attention left for the work itself.",
      "A benchmark is useful only when it stays stable. If the material changes too much, the score tells you more about surprise than skill. Repeating comparable text is how a typing tool can show whether fluency is actually improving over time.",
      "Accuracy and correction behavior matter together. A fast run full of repairs is not the same as a clean run that leaves your focus intact. Real typing quality appears in the gap between what you intended, what you typed, and how much cleanup it required.",
    },
  },
  {
    id = "benchmark_code_1m",
    key = "3",
    name = "Code 1m",
    description = "One-minute code and punctuation benchmark",
    duration = 60,
    profile = "code",
    chunks = {
      [[const parseConfig = (input) => {
  if (!input) return { debug: false, port: 8080 };
  const port = Number(input.port ?? 8080);
  return { debug: Boolean(input.debug), port };
};]],
      [[fn render(items: &[String]) -> Result<(), Box<dyn Error>> {
    for (i, item) in items.iter().enumerate() {
        println!("[{}] {}", i, item);
    }
    Ok(())
}]],
    },
  },
  {
    id = "benchmark_code_3m",
    key = "4",
    name = "Code 3m",
    description = "Three-minute sustained code benchmark",
    duration = 180,
    profile = "code",
    chunks = {
      [[type Config = {
  host: string;
  port: number;
  retries?: number;
};

export async function fetchJson(url: string, cfg: Config) {
  const response = await fetch(url, { headers: { "x-port": String(cfg.port) } });
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.json();
}]],
      [[func handleRequest(w http.ResponseWriter, r *http.Request) {
    if r.Method != "POST" {
        http.Error(w, "method not allowed", 405)
        return
    }
    var payload map[string]interface{}
    if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
        http.Error(w, err.Error(), 400)
        return
    }
}]],
      [[SELECT u.name, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2025-01-01'
GROUP BY u.name
HAVING COUNT(o.id) > 3
ORDER BY order_count DESC;]],
    },
  },
  {
    id = "benchmark_transition_90s",
    key = "5",
    name = "Transitions 90s",
    description = "Fixed transition and symbol movement benchmark",
    duration = 90,
    profile = "drill",
    chunks = {
      "tg tgtg tg yn ynyn yn rt rtrt rt ui uiui ui cv cvcv cv nm nmnm nm",
      "-> => == != <= >= ++ -- :: .. || && () [] {} <> -> => == != <= >=",
      "shift split center same finger rhythm repeat clean reach return steady pace",
    },
  },
  {
    id = "benchmark_covered_90s",
    key = "6",
    name = "Covered 90s",
    description = "Self-declared covered-key prose benchmark",
    duration = 90,
    profile = "prose",
    generated_desc = "Benchmark - cover the keys and keep your eyes on the screen",
    chunks = {
      "When the keyboard drops out of attention, typing becomes part of thinking instead of a separate task. The point of covered key practice is not heroics. The point is to notice whether the map is stable enough that your eyes can stay with the work.",
      "A covered benchmark should feel honest rather than fast. If the hands drift, slow down and keep the reach small. The score is useful only when it reflects what you can actually sustain without peeking.",
    },
  },
}

local function get_history_file()
  return storage.layout_data_path("benchmarks")
end

local function load_history()
  return storage.read_json(get_history_file(), {})
end

local function append_history(entry)
  local _, ok = storage.append_capped(get_history_file(), entry, HISTORY_CAP)
  if ok == false then
    vim.schedule(function()
      vim.notify("split-typer: failed to save benchmark history", vim.log.levels.WARN)
    end)
  end
end

function M.get_definitions()
  return definitions
end

function M.get_definition(id)
  for _, def in ipairs(definitions) do
    if def.id == id then
      return def
    end
  end
  return nil
end

function M.make_chunk_generator(def)
  local idx = 0
  local chunks = def and def.chunks or { "" }
  return function()
    idx = (idx % #chunks) + 1
    return chunks[idx]
  end
end

function M.save_result(entry)
  append_history(entry)
end

function M.get_history(benchmark_id)
  local history = load_history()
  if not benchmark_id then
    return history
  end
  local out = {}
  for _, item in ipairs(history) do
    if item.benchmark_id == benchmark_id then
      out[#out + 1] = item
    end
  end
  return out
end

function M.get_summary()
  local history = load_history()
  local by_id = {}
  for _, def in ipairs(definitions) do
    by_id[def.id] = {
      definition = def,
      count = 0,
      first = nil,
      latest = nil,
      best = nil,
    }
  end

  for _, item in ipairs(history) do
    local bucket = by_id[item.benchmark_id]
    if bucket then
      bucket.count = bucket.count + 1
      if not bucket.first then
        bucket.first = item
      end
      bucket.latest = item
      if not bucket.best or (item.score or 0) > (bucket.best.score or 0) then
        bucket.best = item
      end
    end
  end

  local out = {}
  for _, def in ipairs(definitions) do
    out[#out + 1] = by_id[def.id]
  end
  return out
end

return M
