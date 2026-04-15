local M = {}

M.categories = {
  {
    id = "home_row",
    name = "Home Row",
    description = "Build columnar home row muscle memory",
    gen_config = { chars = "asdfghjkl;", min_words = 10, max_words = 16 },
    exercises = {
      "asdf jkl; asdf jkl; asdf jkl; asdf jkl;",
      "fall lads salad flask dash glad shall glass",
      "a glad lad had a flask; all salads fall fast",
      "ask a lass; add half a flask; a fall gala",
      "alfalfa salad; glass flask; glad lads ask dad",
      "fall shall dash flash glass lads gall salad ads",
    },
  },
  {
    id = "left_hand",
    name = "Left Hand",
    description = "Strengthen left hand on columnar layout",
    gen_config = { chars = "qwertasdfgzxcvb", min_words = 8, max_words = 14 },
    exercises = {
      "we were west better sweet create tree",
      "abstract extract database target greet",
      "greatest weather scatter breadth sweat",
      "excavate exaggerate devastating defeat",
      "qwert asdfg zxcvb qwert asdfg zxcvb",
      "secret severe deserve reverse clever brewer",
    },
  },
  {
    id = "right_hand",
    name = "Right Hand",
    description = "Strengthen right hand on columnar layout",
    gen_config = { chars = "yuiophjklnm,./", min_words = 8, max_words = 14 },
    exercises = {
      "you look upon only pink hill jump milk",
      "monopoly opinion polyphonic million hook",
      "unhook million opinion junior onion pull",
      "plum pool loop polo hippo joy pupil noun",
      "yuiop hjkl; nm,./ yuiop hjkl; nm,./",
      "minimum opinion million illumination",
    },
  },
  {
    id = "center_column",
    name = "Center Column (TGB/YHN)",
    description = "The split boundary keys - must use correct hands",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = "tgbyhn", min_focus_density = 0.25, min_words = 10, max_words = 16 },
    exercises = {
      "the young boy then got hungry tonight",
      "tight night bright thought through that",
      "buying nothing beyond anything everything",
      "they hung by the bygone highway north",
      "both young boys thought about hunting then",
      "gather rhythm growth beneath lengthy python",
    },
  },
  {
    id = "numbers",
    name = "Numbers & Digits",
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
    id = "brackets_intro",
    name = "Brackets: Intro",
    description = "Only bracket shapes and spacing, no letters yet",
    exercises = {
      "() () () [] [] [] {} {} {} <> <> <>",
      "( ) ( ) [ ] [ ] { } { } < > < >",
      "() [] {} <> () [] {} <> () [] {} <>",
      "(()) [[]] {{}} <<>> (()) [[]] {{}} <<>>",
      "()() [] [] {}{} <><> ()() [] [] {}{} <><>",
      "( [ { < > } ] ) ( [ { < > } ] )",
    },
  },
  {
    id = "brackets_nested",
    name = "Brackets: Nested",
    description = "Nested bracket transitions without words or numbers",
    exercises = {
      "([]) {<>} [()] <{}> ([]) {<>} [()] <{}>",
      "({[]}) <{()}> ([{}]) <([])> ({[]}) <{()}>",
      "(([])) {{<>}} [[{}]] <<()>> (([])) {{<>}}",
      "()[{}] <>() {}[]() <>{}[] ()[{}] <>()",
      "({}) [<>] (() ) {{}} [()] <{}> ({}) [<>]",
      "[({<>})] <[{()}]> [({<>})] <[{()}]>",
    },
  },
  {
    id = "symbols_intro",
    name = "Symbols: Intro",
    description = "Core punctuation and operators only, no letters or digits",
    exercises = {
      "! ? . , ; : ! ? . , ; : ! ? . , ; :",
      "+ - * / = + - * / = + - * / =",
      "_ - + = _ - + = _ - + =",
      "| | || || & & && && ! ! !! !!",
      ". , . , ; : ; : / / \\ \\",
      "@ # $ % ^ & * @ # $ % ^ & *",
    },
  },
  {
    id = "symbols_shifted",
    name = "Symbols: Shifted Row",
    description = "Shifted punctuation only, isolated from text",
    exercises = {
      "!@#$%^&*() !@#$%^&*() !@#$%^&*()",
      "! ! @ @ # # $ $ % % ^ ^ & & * * ( ( ) )",
      "~ _ + | : \" < > ? ~ _ + | : \" < > ?",
      "~~ __ ++ || :: \"\" << >> ?? ~~ __ ++ ||",
      "!@# $%^ &*() !@# $%^ &*() !@# $%^ &*()",
      "<><> ???? |||| ++++ ____ :::: \"\"\"\"",
    },
  },
  {
    id = "symbols_pairs",
    name = "Symbols: Pairs & Runs",
    description = "Common symbol pairs and repeated transitions without words",
    exercises = {
      "-> -> => => == == != != <= <= >= >=",
      "++ ++ -- -- ** ** // // || || && &&",
      ":: :: .. .. ?? ?? !! !! ## ## @@ @@",
      "-> => == != <= >= ++ -- ** // || &&",
      "... ::: ;;; ,,, !!! ??? --- === +++",
      "|-| |_| /-/ \\-/ <-> <=> |-| |_| /-/",
    },
  },
  {
    id = "symbols",
    name = "Symbols & Punctuation",
    description = "Mixed punctuation in context with text and numbers",
    exercises = {
      "!@#$%^&*() !@#$%^&*() !@#$%^&*()",
      "a + b = c; x - y * z / w % 2;",
      "user@email.com http://example.com/path?q=1&r=2",
      "price: $99.99; tax: 8.5%; total: $108.49",
      "yes/no; true|false; on&&off; 1||0; !done",
      "#include <stdio.h> /* comment */ // note",
    },
  },
  {
    id = "brackets",
    name = "Brackets & Pairs",
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
    id = "common_words",
    name = "Common Words",
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
  -- Finger isolation exercises (Ergodox EZ default QWERTY columnar)
  {
    id = "finger_l_pinky",
    name = "Finger: Left Pinky",
    description = "Q A Z 1 - vertical column drill",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = "qaz", min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {
      "aaa qqq zzz aqa aza qaz zaq aqa aza qaz zaq",
      "aqua plaza quartz jazz pizza hazard bazaar",
      "a quail gazed at a plaza; a lazy jackal froze",
      "aq za qa az aq za qa az 1a a1 q1 1q z1 1z",
      "amazing plaza quake haze amazon gaze raze maze",
      "zap quiz jazz aqua haze quartz plaza gazette",
    },
  },
  {
    id = "finger_l_ring",
    name = "Finger: Left Ring",
    description = "W S X 2 - vertical column drill",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = "wsx", min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {
      "sss www xxx sws sxs wsx xsw sws sxs wsx xsw",
      "swam wax sax wasp west wrist six hex flex",
      "the swiss saw six foxes swim westward",
      "sw ws xs sx wx xw 2s s2 w2 2w x2 2x",
      "swiftness witness whisper wisdom wistful sway",
      "excess wax sox hex axis exist wasp swap swirl",
    },
  },
  {
    id = "finger_l_middle",
    name = "Finger: Left Middle",
    description = "E D C 3 - vertical column drill",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = "edc", min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {
      "ddd eee ccc ded dcd edc cde ded dcd edc cde",
      "deed cede iced dice edged decked exceed ceded",
      "he decided to cede the deed; she iced the cake",
      "ed de cd dc ec ce 3d d3 e3 3e c3 3c",
      "exceeded recededdeclared decreased decency",
      "decline educate decided electrode decent cedar",
    },
  },
  {
    id = "finger_l_index",
    name = "Finger: Left Index",
    description = "R F V T G B 4 5 - two column reach drill",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = "rfvtgb", min_focus_density = 0.25, min_words = 10, max_words = 16 },
    exercises = {
      "fff rrr vvv ttt ggg bbb frf ftf fgf fbf fvf",
      "frog raft gift verb brgt graft brave butter",
      "the brave frog brought five great gifts to bert",
      "rf fr tf ft gf fg bf fb vf fv 4r r4 5t t5",
      "tr rt bg gb vt tv rb br tg gt fr rf bt tb",
      "forgotten turbo gravity butterfly drifting raft",
    },
  },
  {
    id = "finger_r_index",
    name = "Finger: Right Index",
    description = "Y H N U J M 6 7 - two column reach drill",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = "yuhjnm", min_focus_density = 0.25, min_words = 10, max_words = 16 },
    exercises = {
      "jjj uuu mmm yyy hhh nnn juj jyj jhj jnj jmj",
      "hymn jump numb yummy human jaunty thumby muny",
      "many humans hummed jaunty hymns under the yum",
      "uj ju yj jy hj jh nj jn mj jm 6u u6 7y y7",
      "hy yh mn nm uj ju yh hy nu un mh hm jn nj",
      "youthful journey humanity jumping unmy rhythm",
    },
  },
  {
    id = "finger_r_middle",
    name = "Finger: Right Middle",
    description = "I K , 8 - vertical column drill",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = "ik", min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {
      "kkk iii ,,, kik k,k ik, ,ki kik k,k ik, ,ki",
      "kick kink ink kin ilk bikini skiing hiking",
      "i kick, i ski, i hike, i think, i pick, i knit",
      "ik ki ,k k, i, ,i 8k k8 i8 8i ,8 8,",
      "kindling knitting picking kicking inking skiing",
      "wiki, risk, brisk, trick, wick, kick, flick,",
    },
  },
  {
    id = "finger_r_ring",
    name = "Finger: Right Ring",
    description = "O L . 9 - vertical column drill",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = "ol", min_focus_density = 0.2, min_words = 10, max_words = 16 },
    exercises = {
      "lll ooo ... lol l.l ol. .lo lol l.l ol. .lo",
      "pool tool loop fool cool drool lollipop wool",
      "look. loop. loll. fool. cool. tool. spool.",
      "ol lo .l l. o. .o 9l l9 o9 9o .9 9.",
      "hollow follow blossom balloon foolproof Apollo",
      "slowly. boldly. coolly. loosely. wholly. solo.",
    },
  },
  {
    id = "finger_r_pinky",
    name = "Finger: Right Pinky",
    description = "P ; / 0 - = [ ] ' - outer reach drill",
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", focus_chars = "p", min_focus_density = 0.15, min_words = 10, max_words = 16 },
    exercises = {
      "ppp ;;; /// p;p p/p ;/; /;/ p;p p/p ;/; /;/",
      "pop pep pip pap; prep prop pulp pump; pal pan",
      "type; press; tap; pop; pep; /path/to/file;",
      "p; ;p /p p/ 0p p0 -p p- =p p= [p p] 'p p'",
      "['property']; {path: '/api/v0'}; a-p; p=0;",
      "pipeline; parallel; pepper; /opt/bin/app -p 0;",
    },
  },
  {
    id = "finger_thumbs",
    name = "Finger: Thumbs",
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

  -- Precision exercises: no backspace allowed
  {
    id = "precision_short",
    name = "Precision: Short Bursts",
    description = "No backspace - tiny exercises, aim for 100%",
    no_backspace = true,
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", min_words = 4, max_words = 6 },
    exercises = {
      "ask fall dad",
      "life like side",
      "dark rule true",
      "just held firm",
      "kept gold ring",
      "blue fish swam",
    },
  },
  {
    id = "precision_home",
    name = "Precision: Home Row",
    description = "No backspace - home row only, lock in the basics",
    no_backspace = true,
    gen_config = { chars = "asdfghjkl;", min_words = 8, max_words = 14 },
    exercises = {
      "add fall salad flask glad dash lass ask",
      "a lad shall fall; ask a glad lass; add a salad",
      "dad had a flask; half a salad; all lads ask",
      "shall fall lass gall flash; add a dash; sad lad",
    },
  },
  {
    id = "precision_words",
    name = "Precision: Words",
    description = "No backspace - common words, think before you type",
    no_backspace = true,
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", min_words = 10, max_words = 16 },
    exercises = {
      "the world does not reward speed without accuracy",
      "slow is smooth and smooth is fast remember that",
      "every single keystroke matters on a split keyboard",
      "think about the next key before your finger moves",
      "precision builds the muscle memory that speed needs",
      "trust the process and the speed will follow later",
    },
  },
  {
    id = "precision_full",
    name = "Precision: Extended",
    description = "No backspace - longer exercises, sustained focus",
    no_backspace = true,
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", min_words = 16, max_words = 24 },
    exercises = {
      "the quick brown fox jumps over the lazy dog and then runs back again across the field to rest",
      "a split keyboard forces each hand to do its own work with no cheating or crossing over to help",
      "your fingers need to learn exactly where each key lives on the columnar grid without guessing",
    },
  },
  {
    id = "precision_code",
    name = "Precision: Code",
    description = "No backspace - code snippets, every symbol counts",
    no_backspace = true,
    exercises = {
      [[if (x > 0) {
  return x * 2;
}]],
      [[for i in range(10):
    print(i)]],
      [[let mut v: Vec<i32> = vec![1, 2, 3];]],
      [[const fn = (a, b) => a + b;]],
      [[def add(x: int, y: int) -> int:
    return x + y]],
      [[func main() {
    fmt.Println("hello")
}]],
    },
  },
  {
    id = "precision_symbols",
    name = "Precision: Symbols",
    description = "No backspace - brackets and symbols, zero margin",
    no_backspace = true,
    exercises = {
      "() {} [] <> () {} [] <>",
      "{a: 1, b: 2, c: 3}",
      "fn(x) -> { [a, b, c] }",
      "(a + b) * (c - d) / (e % f)",
      "user@host:~/path/to/file.txt",
      "arr[0] = obj.key || 'default';",
    },
  },
  {
    id = "accuracy_burst",
    name = "Accuracy: One-Strike Bursts",
    description = "Fail on first error - short words, pure precision",
    no_backspace = true,
    error_limit = 0,
    repeat_until_clean = true,
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", min_words = 5, max_words = 8 },
    exercises = {
      "slow calm exact clean",
      "press each key with care",
      "think first type once",
      "small drills reveal mistakes",
      "accuracy before speed always",
    },
  },
  {
    id = "accuracy_home",
    name = "Accuracy: Home Row Gate",
    description = "Fail on first error - home row discipline only",
    no_backspace = true,
    error_limit = 0,
    repeat_until_clean = true,
    gen_config = { chars = "asdfghjkl;", min_words = 8, max_words = 12 },
    exercises = {
      "add dash flask glad shall glass",
      "sad lads ask half glass",
      "a glad lad shall add salad",
      "flash glass lads shall dash",
    },
  },
  {
    id = "accuracy_words",
    name = "Accuracy: Two-Strike Words",
    description = "Two strikes only - longer word drills with real pressure",
    no_backspace = true,
    error_limit = 1,
    repeat_until_clean = true,
    gen_config = { chars = "abcdefghijklmnopqrstuvwxyz", min_words = 14, max_words = 20 },
    exercises = {
      "accuracy grows when every keystroke is deliberate and intentional",
      "slow down enough to stay precise and the speed will return later",
      "you cannot build reliable muscle memory on top of repeated mistakes",
      "careful repetitions matter more than rushing through another exercise",
    },
  },
  {
    id = "accuracy_symbols",
    name = "Accuracy: Symbols Gate",
    description = "Fail on first error - symbols and brackets under pressure",
    no_backspace = true,
    error_limit = 0,
    repeat_until_clean = true,
    exercises = {
      "() {} [] <> () {} [] <>",
      "arr[0] = obj.key || 'default';",
      "fn(x) -> { [a, b, c] }",
      "(a + b) * (c - d) / (e % f)",
    },
  },

  -- Focused special character drilling
  {
    id = "special_shifted_nums",
    name = "Shifted: Number Row",
    description = "Drill ! @ # $ % ^ & * ( ) one by one",
    exercises = {
      "! ! ! @ @ @ # # # $ $ $ % % % ^ ^ ^ & & & * * * ( ( ( ) ) )",
      "!@#$%^&*() )(*&^%$#@! !@#$% ^&*() !@#$%^&*()",
      "$99 100% #tag @user &ref *ptr (ok) 2^8 !done",
      "fn(*args, **kwargs); x = a ^ b & c | !d;",
      "#[derive(Debug)] !important @media $HOME %d",
      "(a + b) * (c - d) ^ 2 != $0 & !false % 100",
    },
  },
  {
    id = "special_shifted_punct",
    name = "Shifted: Punctuation",
    description = [[Drill ~ _ + { } | : " < > ? in context]],
    exercises = {
      [[~ ~ _ _ + + { { } } | | : : " " < < > > ? ?]],
      "~/.config ~/bin ~/.local/share ~root",
      [[{ "name": "test", "value": 42 } | { "ok": true }]],
      [[a + b > c ? "yes" : "no" | "default"]],
      "type Config = { host: string; port?: number };",
      [[cmd | grep "TODO" | sort > out.txt 2>&1]],
    },
  },
}

function M.get_categories()
  return M.categories
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

  -- When gen_config is available, generate a fresh exercise 70% of the time
  if cat.gen_config and math.random() < 0.7 then
    local words = require("split-typer.words")
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

return M
