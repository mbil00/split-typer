local layouts = require("split-typer.layouts")

local function home_row() return layouts.chars_by_row.home end
local function left_letters() return layouts.chars_by_hand.left end
local function right_letters() return layouts.chars_by_hand.right end

--- Concat the glyphs of the 5th and 6th columns (the two inward index reaches)
--- across top/home/bottom rows. These are the "center column" physical keys.
local function center_column_chars()
  local rows = layouts.active and layouts.active.rows or {}
  local out = {}
  for _, row_name in ipairs({ "top", "home", "bottom" }) do
    local glyphs = rows[row_name]
    if glyphs then
      for _, col in ipairs({ 5, 6 }) do
        local ch = glyphs[col]
        if ch then out[#out + 1] = ch end
      end
    end
  end
  return table.concat(out)
end

local M = {}

local function refresh_layout_categories()
  local home = home_row()
  local left = left_letters()
  local right = right_letters()
  local center = center_column_chars()

  for _, cat in ipairs(M.categories or {}) do
    if cat.id == "home_row" then
      cat.description = "Home-row muscle memory (" .. home .. ")"
      cat.gen_config.chars = home
    elseif cat.id == "left_hand" then
      cat.description = "Strengthen left hand (" .. left .. ")"
      cat.gen_config.chars = left
    elseif cat.id == "right_hand" then
      cat.description = "Strengthen right hand (" .. right .. ")"
      cat.gen_config.chars = right
    elseif cat.id == "center_column" then
      cat.description = "Split-boundary index reaches (" .. center .. ")"
      cat.gen_config.focus_chars = center
    end
  end
end

M.groups = {
  { id = "general", name = "General", description = "Home row, hands, center column, common words" },
  { id = "characters", name = "Characters", description = "Numbers, brackets, symbols" },
  { id = "code_prose", name = "Code & Prose", description = "Code languages, prose paragraphs, mixed challenge" },
  { id = "fingers", name = "Fingers", description = "Per-column isolation, thumbs, finger combinations" },
  { id = "advanced", name = "Advanced Tracks", description = "Task-specific prose, shell, symbol, and split-keyboard fluency" },
  { id = "custom", name = "Custom Words", description = "Drills drawn from your configured word list" },
}

M.categories = {
  {
    id = "home_row",
    name = "Home Row",
    group = "general",
    description = "Home-row muscle memory (" .. home_row() .. ")",
    gen_config = { chars = home_row(), min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "left_hand",
    name = "Left Hand",
    group = "general",
    description = "Strengthen left hand (" .. left_letters() .. ")",
    gen_config = { chars = left_letters(), min_words = 8, max_words = 14 },
    exercises = {},
  },
  {
    id = "right_hand",
    name = "Right Hand",
    group = "general",
    description = "Strengthen right hand (" .. right_letters() .. ")",
    gen_config = { chars = right_letters(), min_words = 8, max_words = 14 },
    exercises = {},
  },
  {
    id = "center_column",
    name = "Center Column",
    group = "general",
    description = "Split-boundary index reaches (" .. center_column_chars() .. ")",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = center_column_chars(), min_focus_density = 0.25, min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "numbers",
    name = "Numbers & Digits",
    group = "characters",
    description = "Top row numbers on columnar layout",
    exercises = {
      "1234567890 0987654321 1234567890",
      "192.168.1.1 10.0.0.1 255.255.255.0",
      "2026-04-14 14:30:00 +0200 08:15:45",
      "port 8080 pid 12345 size 1024 count 42",
      "100 + 200 = 300; 50 * 4 = 200; 999 - 1 = 998",
      "v2.1.0 node18 python3.12 gcc14 rust1.78",
    },
  },
  {
    id = "brackets_isolated",
    name = "Brackets: Isolated",
    group = "characters",
    description = "Bracket shapes, spacing, and nesting with no letters or numbers",
    exercises = {
      "() () () [] [] [] {} {} {} <> <> <>",
      "( ) ( ) [ ] [ ] { } { } < > < >",
      "() [] {} <> () [] {} <> () [] {} <>",
      "(()) [[]] {{}} <<>> (()) [[]] {{}} <<>>",
      "()() [] [] {}{} <><> ()() [] [] {}{} <><>",
      "( [ { < > } ] ) ( [ { < > } ] )",
      "([]) {<>} [()] <{}> ([]) {<>} [()] <{}>",
      "({[]}) <{()}> ([{}]) <([])> ({[]}) <{()}>",
      "(([])) {{<>}} [[{}]] <<()>> (([])) {{<>}}",
      "()[{}] <>() {}[]() <>{}[] ()[{}] <>()",
      "({}) [<>] (() ) {{}} [()] <{}> ({}) [<>]",
      "[({<>})] <[{()}]> [({<>})] <[{()}]>",
    },
  },
  {
    id = "brackets",
    name = "Brackets & Pairs",
    group = "characters",
    description = "Bracket practice integrated with text and code-like content",
    exercises = {
      "(a) [b] {c} <d> (e) [f] {g} <h>",
      "fn(x, y) -> { vec![1, 2, 3] }",
      "map[key] = {a: (1 + 2), b: [3, 4]}",
      "if (x > 0) { arr[i] = (a + b) * c; }",
      "dict = {'key': [1, (2, 3)], 'b': {4: 5}}",
      "<div className={styles.box}>{items.map((x) => <span>[{x}]</span>)}</div>",
    },
  },
  {
    id = "symbols_isolated",
    name = "Symbols: Isolated",
    group = "characters",
    description = "Punctuation, shifted row, and symbol pairs with no words",
    exercises = {
      "! ? . , ; : ! ? . , ; : ! ? . , ; :",
      "+ - * / = + - * / = + - * / =",
      "_ - + = _ - + = _ - + =",
      "| | || || & & && && ! ! !! !!",
      ". , . , ; : ; : / / \\ \\",
      "@ # $ % ^ & * @ # $ % ^ & *",
      "!@#$%^&*() !@#$%^&*() !@#$%^&*()",
      "! ! @ @ # # $ $ % % ^ ^ & & * * ( ( ) )",
      "~ _ + | : \" < > ? ~ _ + | : \" < > ?",
      "~~ __ ++ || :: \"\" << >> ?? ~~ __ ++ ||",
      "!@# $%^ &*() !@# $%^ &*() !@# $%^ &*()",
      "<><> ???? |||| ++++ ____ :::: \"\"\"\"",
      "-> -> => => == == != != <= <= >= >=",
      "++ ++ -- -- ** ** // // || || && &&",
      ":: :: .. .. ?? ?? !! !! ## ## @@ @@",
      "-> => == != <= >= ++ -- ** // || &&",
      "... ::: ;;; ,,, !!! ??? --- === +++",
      "|-| |_| /-/ \\-/ <-> <=> |-| |_| /-/",
      "! ! ! @ @ @ # # # $ $ $ % % % ^ ^ ^ & & & * * * ( ( ( ) ) )",
      "!@#$%^&*() )(*&^%$#@! !@#$% ^&*() !@#$%^&*()",
      [[~ ~ _ _ + + { { } } | | : : " " < < > > ? ?]],
    },
  },
  {
    id = "symbols",
    name = "Symbols & Punctuation",
    group = "characters",
    description = "Mixed punctuation in context with text and numbers",
    exercises = {
      "!@#$%^&*() !@#$%^&*() !@#$%^&*()",
      "a + b = c; x - y * z / w % 2;",
      "user@email.com http://example.com/path?q=1&r=2",
      "price: $99.99; tax: 8.5%; total: $108.49",
      "yes/no; true|false; on&&off; 1||0; !done",
      "#include <stdio.h> /* comment */ // note",
      "$99 100% #tag @user &ref *ptr (ok) 2^8 !done",
      "fn(*args, **kwargs); x = a ^ b & c | !d;",
      "#[derive(Debug)] !important @media $HOME %d",
      "(a + b) * (c - d) ^ 2 != $0 & !false % 100",
      "~/.config ~/bin ~/.local/share ~root",
      [[{ "name": "test", "value": 42 } | { "ok": true }]],
      [[a + b > c ? "yes" : "no" | "default"]],
      "type Config = { host: string; port?: number };",
      [[cmd | grep "TODO" | sort > out.txt 2>&1]],
    },
  },
  {
    id = "common_words",
    name = "Common Words",
    group = "general",
    description = "Most frequent English words for speed building",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", min_words = 14, max_words = 24 },
    exercises = {
      "the be to of and a in that have I it for not on with",
      "he as you do at this but his by from they we say her she",
      "or an will my one all would there their what so up out if",
      "about who get which go me when make can like time no just",
      "him know take people into year your good some could them",
      "than other only new very when also back after use how our",
      "work first well way even because any these give day most",
    },
  },
  {
    id = "code_python",
    name = "Code: Python",
    group = "code_prose",
    description = "Python code with indentation and syntax",
    exercises = {
      [[def fibonacci(n):
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)]],
      [[for i in range(10):
    if i % 2 == 0:
        print(f"even: {i}")
    else:
        print(f"odd: {i}")]],
      [[class Stack:
    def __init__(self):
        self.items = []

    def push(self, item):
        self.items.append(item)

    def pop(self):
        return self.items.pop()]],
      [[data = {"name": "Alice", "age": 30, "scores": [95, 87, 92]}
result = {k: v for k, v in data.items() if k != "age"}
print(f"filtered: {result}")]],
      [[try:
    with open("config.json", "r") as f:
        config = json.load(f)
except FileNotFoundError:
    config = {"debug": False, "port": 8080}]],
    },
  },
  {
    id = "code_js",
    name = "Code: JavaScript",
    group = "code_prose",
    description = "JavaScript/TypeScript with modern syntax",
    exercises = {
      [[const fetchData = async (url) => {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`HTTP ${response.status}`);
  }
  return response.json();
};]],
      [[const users = items
  .filter((item) => item.active)
  .map(({ name, email }) => ({ name, email }))
  .sort((a, b) => a.name.localeCompare(b.name));]],
      [[function debounce(fn, ms) {
  let timer;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), ms);
  };
}]],
      [[interface Config {
  port: number;
  host: string;
  debug?: boolean;
  routes: Record<string, () => void>;
}]],
      [[const [count, setCount] = useState(0);
useEffect(() => {
  const id = setInterval(() => setCount((c) => c + 1), 1000);
  return () => clearInterval(id);
}, []);]],
    },
  },
  {
    id = "code_rust",
    name = "Code: Rust / Go / C",
    group = "code_prose",
    description = "Systems code with lots of types and symbols",
    exercises = {
      [[fn main() {
    let mut vec: Vec<i32> = Vec::new();
    for i in 0..10 {
        vec.push(i * i);
    }
    println!("{:?}", vec);
}]],
      [[impl<T: Clone + PartialOrd> BinaryTree<T> {
    fn insert(&mut self, value: T) {
        match self {
            Node { val, left, right } => {
                if value < *val {
                    left.insert(value);
                }
            }
        }
    }
}]],
      [[func handleRequest(w http.ResponseWriter, r *http.Request) {
    if r.Method != "POST" {
        http.Error(w, "method not allowed", 405)
        return
    }
    var body map[string]interface{}
    json.NewDecoder(r.Body).Decode(&body)
}]],
      [[#include <stdio.h>
#include <stdlib.h>

int *create_array(int n) {
    int *arr = (int *)malloc(n * sizeof(int));
    for (int i = 0; i < n; i++) {
        arr[i] = i * 2;
    }
    return arr;
}]],
      [[match result {
    Ok(value) => println!("Got: {}", value),
    Err(e) => eprintln!("Error: {:?}", e),
}
let x: Option<&str> = Some("hello");
let y = x.unwrap_or("default");]],
    },
  },
  {
    id = "code_shell",
    name = "Code: Shell & Config",
    group = "code_prose",
    description = "Shell scripts, YAML, JSON, TOML",
    exercises = {
      [[#!/bin/bash
for file in *.txt; do
    echo "Processing: $file"
    wc -l "$file" | awk '{print $1}'
done]],
      [[export PATH="$HOME/.local/bin:$PATH"
alias ll='ls -alF --color=auto'
[ -f ~/.fzf.bash ] && source ~/.fzf.bash]],
      [[server:
  host: "0.0.0.0"
  port: 8080
  tls:
    cert: /etc/ssl/cert.pem
    key: /etc/ssl/key.pem
  logging:
    level: info
    format: json]],
      [[{
  "name": "@scope/package",
  "version": "2.1.0",
  "scripts": {
    "build": "tsc && vite build",
    "test": "vitest run --coverage",
    "lint": "eslint src/ --ext .ts,.tsx"
  }
}]],
      [[find . -name "*.log" -mtime +30 -exec rm {} \;
grep -rn "TODO\|FIXME" src/ | sort | uniq -c | sort -rn
tar czf backup_$(date +%Y%m%d).tar.gz --exclude=node_modules .]],
    },
  },
  {
    id = "prose",
    name = "Prose Paragraphs",
    group = "code_prose",
    description = "Flowing text for sustained typing practice",
    exercises = {
      "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump.",
      "Programming is not about typing speed, it is about thinking clearly and expressing ideas precisely. The keyboard is merely the bridge between thought and code.",
      "Split keyboards force proper touch typing technique by physically separating the hands. Each finger must learn its true home on the columnar grid, unlearning years of diagonal reaching.",
      "In the beginning was the command line. Before windows and mice, there were terminals and keyboards. The craft of typing well has always been the foundation of productive computing.",
      "Muscle memory takes time to develop. The first week with a new keyboard layout feels impossibly slow, but persistence pays off. Within a month, the new layout becomes natural.",
      "Every expert was once a beginner. The frustration of relearning how to type is temporary. What matters is showing up each day and putting in the practice, one keystroke at a time.",
    },
  },
  {
    id = "mixed",
    name = "Ultimate Challenge",
    group = "code_prose",
    description = "Everything combined - the final test",
    exercises = {
      [[SELECT u.name, COUNT(o.id) AS order_count
FROM users u
LEFT JOIN orders o ON u.id = o.user_id
WHERE u.created_at > '2024-01-01'
GROUP BY u.name
HAVING COUNT(o.id) > 5
ORDER BY order_count DESC;]],
      [[# Build v2.3.1 (2026-04-14)
- Fix: handle null in parse_config() [#1234]
- Add: retry logic with exp. backoff (max 3x)
- Perf: reduce allocs by 40% in hot path
- BREAKING: remove deprecated `--legacy` flag]],
      [[const API = "https://api.example.com/v2";
async function sync(ids: number[]) {
  const results = await Promise.all(
    ids.map((id) => fetch(`${API}/items/${id}`))
  );
  return results.filter((r) => r.ok);
}
// Usage: sync([1, 2, 3]).then(console.log);]],
      [[IPv4: 192.168.0.1/24 -> 10.0.0.0/8
IPv6: fe80::1%eth0 | ::ffff:127.0.0.1
Ports: 22/tcp (SSH), 443/tcp (HTTPS), 53/udp (DNS)
Regex: ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$]],
      [[fn process<T: Serialize + Debug>(items: &[T]) -> Result<(), Box<dyn Error>> {
    for (i, item) in items.iter().enumerate() {
        let json = serde_json::to_string(&item)?;
        println!("[{}/{}] {}", i + 1, items.len(), json);
    }
    Ok(())
}]],
      [[mix = {
  "name": "app", "version": 3,
  "env": {"DEBUG": true, "PORT": 8080},
  "deps": ["react@^18.2", "next@14.1.0"],
  "scripts": {
    "dev": "next dev --turbo",
    "build": "next build && cp -r public/ out/"
  },
  "flags": ["--strict", "--no-emit", "-p", "tsconfig.json"]
}]],
    },
  },
  -- Finger isolation drills: each focuses on a single physical column of the
  -- columnar split. The glyphs drilled depend on the active layout.
  {
    id = "finger_l_pinky",
    name = "Finger: Left Pinky",
    group = "fingers",
    description = "Left pinky column (" .. layouts.chars_by_col.l_pinky .. ")",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = layouts.chars_by_col.l_pinky, min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "finger_l_ring",
    name = "Finger: Left Ring",
    group = "fingers",
    description = "Left ring column (" .. layouts.chars_by_col.l_ring .. ")",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = layouts.chars_by_col.l_ring, min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "finger_l_middle",
    name = "Finger: Left Middle",
    group = "fingers",
    description = "Left middle column (" .. layouts.chars_by_col.l_middle .. ")",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = layouts.chars_by_col.l_middle, min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "finger_l_index",
    name = "Finger: Left Index",
    group = "fingers",
    description = "Left index columns (" .. layouts.chars_by_col.l_index .. ")",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = layouts.chars_by_col.l_index, min_focus_density = 0.25, min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "finger_r_index",
    name = "Finger: Right Index",
    group = "fingers",
    description = "Right index columns (" .. layouts.chars_by_col.r_index .. ")",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = layouts.chars_by_col.r_index, min_focus_density = 0.25, min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "finger_r_middle",
    name = "Finger: Right Middle",
    group = "fingers",
    description = "Right middle column (" .. layouts.chars_by_col.r_middle .. ")",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = layouts.chars_by_col.r_middle, min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "finger_r_ring",
    name = "Finger: Right Ring",
    group = "fingers",
    description = "Right ring column (" .. layouts.chars_by_col.r_ring .. ")",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = layouts.chars_by_col.r_ring, min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "finger_r_pinky",
    name = "Finger: Right Pinky",
    group = "fingers",
    description = "Right pinky column (" .. layouts.chars_by_col.r_pinky .. ")",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = layouts.chars_by_col.r_pinky, min_focus_density = 0.15, min_words = 10, max_words = 16 },
    exercises = {},
  },
  {
    id = "finger_thumbs",
    name = "Finger: Thumbs",
    group = "fingers",
    description = "Space and Enter rhythm on thumb clusters",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", min_words = 20, max_words = 30 },
    exercises = {
      "a b c d e f g h i j k l m n o p q r s t u v w x y z",
      "I am a go to if do an or is it on up so no we he me be",
      "go. do. be.\nis. am. an.\nif. or. so.\nno. up. on.",
      "a b\nc d\ne f\ng h\ni j\nk l\nm n\no p\nq r\ns t\nu v\nw x\ny z",
      "one two three four five six seven eight nine ten",
      "do it. go on. be ok.\nif so, we go.\nhe is up.\nshe ran on.",
    },
  },
  {
    id = "finger_combo",
    name = "Finger: Combinations",
    group = "fingers",
    description = "Adjacent finger transitions and hand alternation",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", min_words = 12, max_words = 20 },
    exercises = {
      "as we do it; if he can go; so be it; on my way",
      "qa ws ed rf tg yh uj ik ol p; qa ws ed rf tg",
      "az sx dc fv gb hn jm k, l. ;/ az sx dc fv gb",
      "the quick brown fox jumps over the lazy dog again",
      "asdf jkl; fdsa ;lkj asdf jkl; fdsa ;lkj qwer",
      "left right left right both hands alternate now go",
    },
  },
  {
    id = "advanced_prose_fluency",
    name = "Track: Prose Fluency",
    group = "advanced",
    description = "Longer clauses, punctuation, and sentence rhythm without code syntax",
    exercises = {
      "Good prose typing is not only about speed. It is about moving through full sentences without dropping rhythm when commas, quotes, or longer phrases appear in the line.",
      "A useful prose drill keeps the eyes on meaning while the hands handle spacing and punctuation. The hands should not panic every time a sentence changes shape.",
      "Sustained text exposes hidden weakness better than short bursts do. A rough transition, a lazy reach, or a pause before punctuation becomes obvious when the paragraph keeps flowing.",
      "The right pace for fluency work is calm enough to stay clean and fast enough to feel continuous. If the sentence breaks your rhythm, the answer is usually control, not force.",
      "Real transfer appears when the keyboard stops interrupting thought. The line should feel like language first and finger work second, even when the punctuation gets denser.",
    },
  },
  {
    id = "advanced_code_punctuation",
    name = "Track: Code Punctuation",
    group = "advanced",
    description = "Operators, delimiters, and assignment patterns in realistic code snippets",
    exercises = {
      [[const next = items.map((item) => ({ id: item.id, ok: item.score >= 90 }));
if (!next.length) return { ok: false, reason: "empty" };]],
      [[result := map[string]int{"ok": 1, "retry": 3}
if count, exists := result["retry"]; exists && count > 0 { fmt.Println(count) }]],
      [[let value = cache.get(key).and_then(|raw| raw.parse::<i32>().ok()).unwrap_or(0);
if value >= 10 && value % 2 == 0 { println!("ready: {}", value); }]],
      [[payload = {"path": "/tmp/out.log", "args": ["--strict", "--retry=2"], "debug": True}
if payload["debug"] and payload["path"].endswith(".log"): print(payload)]],
      [[type Config = { host: string; port?: number; flags: string[] };
const cfg: Config = { host: "127.0.0.1", port: 8080, flags: ["--watch", "--strict"] };]],
    },
  },
  {
    id = "advanced_shell_cli",
    name = "Track: Shell & CLI",
    group = "advanced",
    description = "Pipelines, flags, paths, redirects, and command-line punctuation in context",
    exercises = {
      [[rg -n "TODO|FIXME" src/ | sort | uniq -c | sort -rn | head -20]],
      [[find . -type f -name "*.log" -mtime +7 -print0 | xargs -0 gzip -9]],
      [[curl -sS http://127.0.0.1:8080/health | jq '.status,.uptime' > /tmp/health.json]],
      [[tar czf backup_$(date +%Y%m%d_%H%M).tar.gz --exclude node_modules --exclude .git .]],
      [[PATH="$HOME/.local/bin:$PATH" APP_ENV=prod ./run --host 0.0.0.0 --port 8080 2>&1 | tee out.log]],
    },
  },
  {
    id = "advanced_delimiters",
    name = "Track: Brackets & Delimiters",
    group = "advanced",
    description = "Nested pairs, quotes, signatures, and data-shape punctuation without raw symbol walls",
    exercises = {
      [[fn render(map: HashMap<String, Vec<(usize, bool)>>) -> Result<(), Error> { Ok(()) }]],
      [[items.push({ key: "theme", value: ["dark", "wide"], meta: { ok: true } });]],
      [[if (user?.profile?.email ?? "").includes("@")) { queue.push(["mail", user.id]); }]],
      [[query = {"select": ["name", "count(*)"], "where": {"status": ["new", "open"]}}]],
      [[set statusline=%f\ %h%m%r%=%-14.(%l,%c%V%)\ %P]],
    },
  },
  {
    id = "advanced_numbers_timestamps",
    name = "Track: Numbers & Timestamps",
    group = "advanced",
    description = "Dates, versions, ports, ratios, and mixed number punctuation in useful formats",
    exercises = {
      "2026-04-19 14:32:08 +0200 | 2026-11-03 08:05:44 +0100 | 2027-01-01 00:00:00 +0000",
      "v1.9.4 -> v2.0.0-rc.3 -> v2.1.12 | api/v3 | build-20260419.7",
      "127.0.0.1:8080 -> 10.0.0.12:443 | 192.168.1.50:22 | [::1]:3000",
      "latency p50=18.4ms p95=42.8ms p99=105.2ms | error_rate=0.07% | cpu=63.5%",
      "1/8 3/16 5/32 12:45 09:07 23:59 00:15 4x 8x 16x 32x",
    },
  },
  {
    id = "advanced_split_reaches",
    name = "Track: Split Reaches",
    group = "advanced",
    description = "Cross-center reaches, inward index work, and symbol entry around the split boundary",
    exercises = {
      "tg yn tg yn  tg->yn  yn=>tg  target syntax  tidy entry  center reach return",
      [[type SyncTarget = { tag: string; key: string };
let next = target_map.get(tag)?.try_into().ok();]],
      [[git tag -a v2.1.0 -m "sync target ready" && git push --tags]],
      [[entry = { "type": "sync", "target": "engine", "ok": true, "retries": 2 }]],
      "inner index reach, center return, split rhythm, steady space, short line, clean repeat",
    },
  },
  {
    id = "advanced_thumb_cluster",
    name = "Track: Thumb Cluster Flow",
    group = "advanced",
    description = "Space, Enter, and line-break rhythm for terminals and multi-line editing",
    exercises = {
      [[git status
git add README.md
git commit -m "tighten shell flow"]],
      [[if state.ok then
  print("ready")
end]],
      [[one line here
next line there
third line stays clean]],
      [[run test
run lint
run build
ship clean]],
      [[path one
path two
path three
done now]],
    },
  },
  {
    id = "custom_words",
    name = "Custom Words",
    group = "custom",
    description = "Drills drawn only from your configured word list",
    gen_config = { source = "custom", min_words = 12, max_words = 20 },
    exercises = {},
  },
}

local function custom_available()
  return require("split-typer.words").has_custom()
end

local function is_custom_category(cat)
  return cat.gen_config and cat.gen_config.source == "custom"
end

function M.get_categories()
  local result = {}
  local custom_ok = custom_available()
  for _, cat in ipairs(M.categories) do
    -- Hide the custom-words category until the user has configured a pool,
    -- so the menu stays clean out of the box.
    if not is_custom_category(cat) or custom_ok then
      result[#result + 1] = cat
    end
  end
  return result
end

function M.get_groups()
  local result = {}
  local custom_ok = custom_available()
  for _, g in ipairs(M.groups) do
    if g.id ~= "custom" or custom_ok then
      result[#result + 1] = g
    end
  end
  return result
end

function M.get_group(id)
  for _, g in ipairs(M.groups) do
    if g.id == id then
      return g
    end
  end
  return nil
end

function M.get_categories_in_group(group_id)
  local result = {}
  local custom_ok = custom_available()
  for _, cat in ipairs(M.categories) do
    if cat.group == group_id and (not is_custom_category(cat) or custom_ok) then
      result[#result + 1] = cat
    end
  end
  return result
end

function M.get_category(id)
  for _, cat in ipairs(M.categories) do
    if cat.id == id then
      return cat
    end
  end
  return nil
end

function M.get_random_exercise(category_id)
  local cat = M.get_category(category_id)
  if not cat then
    return nil
  end

  local words = require("split-typer.words")

  if cat.gen_config and cat.gen_config.source == "custom" then
    return words.generate_custom(cat.gen_config), 0
  end

  local has_curated = cat.exercises and #cat.exercises > 0
  -- When gen_config is available, generate a fresh exercise 70% of the time.
  -- If no curated exercises exist (physical drills on non-QWERTY layouts drop
  -- the QWERTY-flavored string banks), always fall through to the generator.
  if cat.gen_config and (not has_curated or math.random() < 0.7) then
    return words.generate(cat.gen_config), 0
  end

  local idx = math.random(1, #cat.exercises)
  return cat.exercises[idx], idx
end

function M.get_exercise(category_id, index)
  local cat = M.get_category(category_id)
  if not cat then
    return nil
  end
  return cat.exercises[index]
end

-- ============================================================
-- Combo (modifier key) categories
-- ============================================================

local function make_combo_pool(modifier_code, modifier_name, keys)
  local pool = {}
  for i = 1, #keys do
    local key = keys:sub(i, i)
    local display_key = key:match("%d") and key or key:upper()
    pool[#pool + 1] = {
      display = modifier_name .. " + " .. display_key,
      key = "<" .. modifier_code .. "-" .. key .. ">",
    }
  end
  return pool
end

local function merge_pools(...)
  local merged = {}
  for _, pool in ipairs({ ... }) do
    for _, item in ipairs(pool) do
      merged[#merged + 1] = item
    end
  end
  return merged
end

-- Safe Ctrl keys (skip c,h,i,j,m,q,s,z which conflict with terminal/Neovim)
local ctrl_letter_pool = make_combo_pool("C", "Ctrl", "abdefgklnoprtuvwxy")
local alt_letter_pool = make_combo_pool("A", "Alt", "abcdefghijklmnopqrstuvwxyz")
local ctrl_num_pool = make_combo_pool("C", "Ctrl", "0123456789")
local alt_num_pool = make_combo_pool("A", "Alt", "0123456789")

M.combo_categories = {
  {
    id = "combo_ctrl",
    name = "Ctrl + Letter",
    description = "Practice Ctrl modifier with letter keys",
    combo_pool = ctrl_letter_pool,
    combo_count = { 15, 20 },
  },
  {
    id = "combo_alt",
    name = "Alt + Letter",
    description = "Practice Alt modifier with letter keys",
    combo_pool = alt_letter_pool,
    combo_count = { 15, 20 },
  },
  {
    id = "combo_ctrl_num",
    name = "Ctrl + Number",
    description = "Ctrl with number keys (needs kitty/CSI u terminal)",
    combo_pool = ctrl_num_pool,
    combo_count = { 10, 15 },
  },
  {
    id = "combo_alt_num",
    name = "Alt + Number",
    description = "Alt with number keys",
    combo_pool = alt_num_pool,
    combo_count = { 10, 15 },
  },
  {
    id = "combo_mixed",
    name = "Mixed Modifiers",
    description = "Random mix of Ctrl and Alt combinations",
    combo_pool = merge_pools(ctrl_letter_pool, alt_letter_pool, alt_num_pool),
    combo_count = { 20, 30 },
  },
}

function M.get_combo_categories()
  return M.combo_categories
end

function M.get_combo_category(id)
  for _, cat in ipairs(M.combo_categories) do
    if cat.id == id then
      return cat
    end
  end
  return nil
end

function M.generate_combo_exercise(category_id)
  local cat = M.get_combo_category(category_id)
  if not cat then
    return nil
  end

  local pool = cat.combo_pool
  local count = math.random(cat.combo_count[1], cat.combo_count[2])
  local combos = {}
  local last_key = nil

  for i = 1, count do
    local combo
    local attempts = 0
    repeat
      combo = pool[math.random(1, #pool)]
      attempts = attempts + 1
    until combo.key ~= last_key or #pool <= 1 or attempts > 10
    combos[i] = { display = combo.display, key = combo.key }
    last_key = combo.key
  end

  return combos
end

M.reaction_categories = {
  {
    id = "reaction_alnum",
    name = "Letters & Digits",
    description = "Single-key letters and numbers without symbols mixed in",
    prompt_count = 50,
    prompt_pool = {
      "a", "s", "d", "f", "j", "k", "l",
      "q", "w", "e", "r", "u", "i", "o", "p",
      "z", "x", "c", "v", "n", "m",
      "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
    },
  },
  {
    id = "reaction_brackets",
    name = "Brackets Only",
    description = "Single-key bracket recognition: (), [], {}, <>",
    prompt_count = 50,
    prompt_pool = { "(", ")", "[", "]", "{", "}", "<", ">" },
  },
  {
    id = "reaction_symbols",
    name = "Symbols Only",
    description = "Operators and punctuation without letters or digits",
    prompt_count = 50,
    prompt_pool = { "!", "@", "#", "$", "%", "^", "&", "*", "-", "_", "+", "=", "/", "\\", "|", ";", ":", ",", ".", "?" },
  },
  {
    id = "reaction_code",
    name = "Code Punctuation",
    description = "Mixed brackets and operators common in code",
    prompt_count = 50,
    prompt_pool = { "(", ")", "[", "]", "{", "}", "<", ">", "=", "+", "-", "*", "/", "_", "!", "&", "|", ";", ":", ",", "." },
  },
}

function M.get_reaction_categories()
  return M.reaction_categories
end

function M.get_reaction_category(id)
  for _, cat in ipairs(M.reaction_categories) do
    if cat.id == id then
      return cat
    end
  end
  return nil
end

function M.generate_reaction_exercise(category_id)
  local cat = M.get_reaction_category(category_id)
  if not cat then
    return nil
  end

  local prompts = {}
  local last_key = nil
  for i = 1, (cat.prompt_count or 50) do
    local next_key
    local attempts = 0
    repeat
      next_key = cat.prompt_pool[math.random(1, #cat.prompt_pool)]
      attempts = attempts + 1
    until next_key ~= last_key or #cat.prompt_pool <= 1 or attempts > 10

    prompts[i] = { key = next_key, display = next_key }
    last_key = next_key
  end

  return prompts
end

function M.rebuild_for_layout()
  refresh_layout_categories()
end

refresh_layout_categories()

return M
