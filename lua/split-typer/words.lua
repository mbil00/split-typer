local M = {}

-- Common English and engineering words (~3200 unique), organized by length for variety.
-- Stored as concatenated strings for compactness; parsed once on first use.
local raw = table.concat({
  -- 2-letter
  "ad am an as at be by do go he if in is it me my no of on or so to up us we",

  -- 3-letter
  "ace act add age ago aid aim air all and any arc are ark arm art ash ask ate awe axe",
  "bad bag ban bar bat bay bed bet bid big bin bit bow box boy bud bug bun bus but buy",
  "cab can cap car cat cow cry cub cup cut",
  "dad dam day did dig dim dip dog dot dry dub dud due dug dye",
  "ear eat eel egg elm end era eve ewe eye",
  "fad fan far fat fax fed fee few fig fin fir fit fix fly fog for fox fry fun fur",
  "gag gap gas gel gem get gig gin god got gum gun gut guy",
  "had ham has hat hay hem hen her hew hid him hip his hit hog hop hot how hub hue hug hum hut",
  "ice ill imp ink inn ion ire irk ivy",
  "jab jag jam jar jaw jay jet jig job jog joy jug jut",
  "keg ken key kid kin kit",
  "lab lad lag lap law lay led leg let lid lie lip lit log lot low lug",
  "mad man map mar mat maw may men met mid mix mob mop mow mud mug mum",
  "nab nag nap net new nil nip nit nod nor not now nun nut",
  "oak oar oat odd ode off oft oil old one opt orb ore our out owe owl own",
  "pad pal pan par pat paw pay pea peg pen per pet pie pig pin pit ply pod pop pot pro pry pub pug pun pup put",
  "rag ram ran rap rat raw ray red ref rib rid rig rim rip rob rod rot row rub rug rum run rut rye",
  "sac sad sag sap sat saw say sea set sew she shy sin sip sir sit six ski sky sly sob sod son sow spy sub sue sum sun",
  "tab tad tag tan tap tar tax tea ten the tie tin tip toe ton too top tow toy try tub tug two",
  "urn use van vat vet via vie vim vow",
  "wad wag war was wax way web wed wet who why wig win wit woe wok won woo wow",
  "yak yam yap yaw yea yes yet yew you zag zap zed zen zig zip zoo",

  -- 4-letter
  "able ache acid acre aged aide also arch area army arts auto avid away axle",
  "back bail bait bake bald bale ball band bane bank bare bark barn base bath bead beak beam bean bear beat beef been beer bell belt bend bent best bias bike bill bind bird bite blew blob blow blue blur boar boat body bold bolt bomb bond bone book boom boot bore born boss both bowl bred brew brim bulk bull bump burn bury bush busy buzz",
  "cafe cage cake calf call calm came camp cane cape card care cart case cash cast cave cell chat chef chin chip chop cite city clad clam clan clap claw clay clip clot club clue coal coat code coil coin cold colt come cook cool cope copy cord core cork corn cost cozy crab crew crop crow cube cult curb cure curl cute",
  "dale dame damp dare dark darn dart dash data date dawn deal dear debt deck deed deem deep deer demo dent deny desk dial dice died diet dime dire dirt disc dish disk dock does dome done doom door dose down doze drag draw drew drip drop drum dual duck dude duel dull dumb dump dune dunk dusk dust duty",
  "each earl earn ease east easy edge edit else emit epic even ever evil exam exit eyed eyes",
  "face fact fade fail fair fake fall fame fang fare farm fast fate fawn fear feat feed feel feet fell felt fend fern file fill film find fine fire firm fish fist five flag flat flaw flea fled flew flip flow foam foil fold folk fond font food fool foot ford fore fork form fort foul four fowl free frog from fuel full fund fuse fuss fuzz",
  "gait gale game gang gape garb gate gave gaze gear gene gift gild gill gist give glad glen glow glue glum gnaw goat goes gold golf gone good gore grab gram gray grew grid grim grin grip grit grow grub gulf gull gust guts",
  "hack hail hair hale half hall halt hand hang hard hare harm harp hash hate haul have hawk haze hazy head heal heap hear heat heed heel held helm help herb herd here hero hide high hike hill hilt hind hint hire hold hole home hone hood hook hope horn hose host hour howl huge hull hung hunt hurl hurt hush",
  "icon idea idle inch info into iron isle item",
  "jack jade jail jazz jean jerk jest jobs join joke jolt jump junk jury just",
  "keen keep kept kick kids kill kind king kiss kite knee knew knit knob knot know",
  "lace lack laid lake lamb lame lamp land lane lard lark lash lass last late lawn lazy lead leaf leak lean leap left lend lens less lick lied life lift like limb lime limp line link lion lips list live load loaf loan lock loft logo lone long look loop lord lore lose loss lost loud love luck lump lure lurk lush lust",
  "mace made mail main make male malt mane many mark mask mass mast mate maze meal mean meat meet meld melt memo mend menu mere mesh mess mice mild mile milk mill mind mine mint miss mist moan moat mock mode mold mole monk mood moon moor more moss most moth move much muck mule mull muse mush must mute",
  "nail name nape navy near neat neck need nest news next nice nick nine node none nook noon norm nose note noun nude",
  "obey odds odor oily okay omen omit once ones only onto open oral orca ours oust oven over owed oxen",
  "pace pack pact page paid pail pain pair pale palm pane pant park part pass past path pave pawn peak peal pear peat peck peek peel peer pelt perk pest pick pier pike pile pine pink pipe plan play plea plod plot plow ploy plug plum plus poem poet poke pole poll polo pond pool poor pore pork port pose post pour pout pray prey prod prop pull pulp pump punk pure push",
  "race rack raft rage raid rail rain rake ramp rang rank rant rare rash rate rave rays read real ream rear reed reef reel rein rely rend rent rest rice rich ride rift ring rink riot ripe rise risk road roam roar robe rock rode role roll roof room root rope rose rote rout rude ruin rule rump rung runt ruse rush rust",
  "safe sage said sail sake sale salt same sand sane sang sank sash save seal seam sear seat seed seek seem seen self sell send sent sewn shed shin ship shoe shop shot show shut sick side sift sigh sign silk sill silt sink site size slab slam slap slat sled slew slid slim slip slit slot slow slug slum slur snap snow snub snug soak soap soar sock soda sofa soft soil sold sole some song soon sore sort soul sour span spar sped spin spit spot spur stab star stay stem step stew stir stop stub stud stun such suit sulk sung sunk sure surf swan swap sway swim",
  "tack tail take tale talk tall tame tang tank tape tart task taxi team tear teen tell tend tent term test text than that them then they thin this thus tick tide tidy tied tier tile till tilt time tiny tire toad toil told toll tomb tone took tool tops tore torn toss tour town tram trap tray tree trek trim trio trip trot true tube tuck tuft tuna tune turf turn tusk twin type",
  "ugly undo unit upon urge used user vain vale vane vary vase vast veil vein vent verb very vest vibe vice view vine visa void volt vote vows",
  "wade wage wail wait wake walk wall wand ward warm warn warp wart wary wash wasp wave wavy waxy weak wear weed week weep weld well went wept were west what when whim whip whom wick wide wife wild will wilt wily wind wine wing wink wipe wire wise wish with woke wolf womb wood wool word wore work worm worn wove wrap wren",
  "yard yarn yawn year yell yoga yoke your zeal zero zest zinc zone zoom",

  -- 5-letter
  "about above abuse actor adapt admit adopt adult after again agent agile agree ahead alarm alien align alike alive alley allow alone along alter among ample angel anger angle angry ankle apart apple apply arena argue arise armor array arrow aside asset atlas attic audio audit avoid awake award aware awful",
  "badge badly basic basin basis batch beach beast began begin being below bench berry bible black blade blame bland blank blast blaze bleak bleed blend bless blind blink bliss block bloom blown board boast bonus booth bound brace brain brand brave bread break breed brick bride brief bring broad broke brook brown brush buddy build built bunch burst buyer",
  "cabin cable camel candy cargo carry catch cause cedar chain chair chalk chaos charm chase cheap check cheek cheer chess chest chief child chill chunk claim clash class clean clear clerk cliff climb cling clock clone close cloth cloud clown coach coast color comet comic coral couch could count court cover crack craft crane crash crazy cream creek crest crime crisp cross crowd crown cruel crush curve cycle",
  "daily dance decay decor decoy delay delta demon dense depot depth derby devil diary dirty dodge doing donor doubt dough dozen draft drain drama drank drape drawn dread dream dress dried drift drill drink drive drone drove drown drunk dryer dying",
  "eager eagle early earth eaten eight elder elect elite email ember empty ended enemy enjoy enter entry equal equip erase error essay event every exact exist extra",
  "fable facet faint fairy faith fancy feast fence ferry fetch fewer fiber field fifty fight final first fixed flame flash fleet flesh fling float flock flood floor flora flour fluid flush flute focus force forge forth forum found frame fraud fresh front frost froze fruit fully funny fuzzy",
  "gauge genre ghost giant given glass gleam glide globe gloom glory gloss glove going grace grade grain grand grant grape grasp grass grave great greed green greet grief grind groan groom gross group grove grown guard guess guide guild guilt",
  "habit happy harsh haste haven heart heavy hedge hence honey honor horse hotel house human humor hurry",
  "ideal image imply index inner input irony issue ivory jewel joint joker judge juice juicy jumbo jumpy",
  "kayak knack kneel knife knock known",
  "label labor large laser latch later laugh layer learn lease least leave legal lemon level lever light limit linen liner liver local lodge logic loose lover lower loyal lucky lunar lunch lunge",
  "magic major maker manor maple march match maybe mayor media mercy merge merit metal meter midst might minor minus model money month moral mount mouse mouth movie muddy music",
  "naive nasty naval nerve never newly night noble noise north noted novel nurse",
  "occur ocean offer often olive onset opera orbit order organ other ought outer oxide",
  "paint panel panic paper party paste patch pause peace pearl penny phase phone photo piano piece pilot pinch pitch pixel place plain plane plant plate plaza plead pluck plumb point polar pound power press price pride prime print prior prize probe prone proof proud prove prune pulse punch pupil purse",
  "quake query quest quick quiet quirk quota quote",
  "radar radio raise rally ranch range rapid ratio reach ready realm rebel reign relax relay remit renew repay reply rider ridge rifle right rigid rinse risky rival river robin robot rocky rough round route royal ruler rural",
  "sadly saint salad salon sauce scale scare scene scent scope score scout scrap serve seven shade shaft shake shall shame shape share shark sharp shave sheet shelf shell shift shine shirt shock shore short shout shove shown shrub shrug sight silly since sixth sixty skull slash slate slave sleep slick slide slope small smart smell smile smoke snack snake snare sneak snore solar solid solve sorry sound south space spare spark speak speed spend spice spike spine split spoke spoon sport spray squad stack staff stage stain stair stake stale stall stamp stand stare stark start state stays steak steal steam steel steep steer stern stick stiff still stock stole stone stood stool store storm story stout stove strap straw stray strip stuck study stuff stump stung stunk style sugar suite sunny super surge swamp swarm swear sweep sweet swept swift swing swirl sworn swung",
  "table taken taste teach teeth tempo thick thief thing think third thorn those three threw throw thumb tiger tight timer tired title toast today token tooth topic total touch tough towel tower trace track trade trail train trait trash tread treat trend trial tribe trick troop trout truck truly trunk trust truth tunic twice twist",
  "ultra uncle under union unite unity until upper upset urban usage usual utter",
  "vague valid value valve vapor vault video vigor vinyl viral visit vital vivid vocal voice voter",
  "waist watch water weary weave wedge weird whale wheat wheel where which while white whole whose widen width witch woman world worry worst worth would wound wrath wreck wrist write wrong wrote",
  "yacht yield young youth zebra",

  -- 6+ letter
  "absorb accept access across action active actual adjust admire advice affirm afford afraid agency agenda almost amount anchor animal annual answer anyone anyway appeal appear around artist assume attach attack attend autumn",
  "backup banker barely basket battle beauty become before behind belong beside better beyond bigger bitter blanket border borrow bottle bottom bounce branch breath bridge bright broken bronze broker browse bubble budget bundle burden bureau butter button",
  "cancel candle canvas carbon career castle cattle caught center chance change charge chosen church circle client clinic closed closer closet coffee colony column combat comedy coming common comply corner cotton couple course cousin covers create credit crisis custom",
  "damage dancer danger dealer debate decade decide defend define degree delete demand denial deploy derive desert design desire detail detect device differ dinner direct divide doctor dollar domain double driven driver during",
  "earned easier easily eating editor effect effort eighth either emerge employ enable ending energy engage engine enough ensure entire entity escape estate evolve exceed except excuse expand expect expert export expose extend extent",
  "factor fairly family famous farmer father fellow female figure filter finder finger finish firmly fiscal flavor flight flower flying follow forced forest forget formal format former foster fourth freeze friend frozen future",
  "galaxy garage garden gather gender gentle global golden govern ground growth guilty guitar",
  "handle happen harbor hardly heaven height helped hidden higher holder honest horror hunger hunter",
  "ignore import impose income indeed indoor inform injure injury insert inside insist intact intend invest island issued",
  "jacket jersey junior keeper kernel kidney killer kindle knight",
  "launch lately latter lawyer layout leader league leaves lender length lesser lesson letter lights likely linear linked liquid listen little lively living locate longer lovely",
  "mainly manage manner marble margin marine marked marker market master matter meadow medium member memory mental mentor merely method middle mighty miller minute mirror mobile modern modest moment monkey mostly motion museum mutual",
  "namely narrow nation native nature nearly needed nicely nobody notice notion number",
  "obtain occupy offset online oppose option orange origin outfit output",
  "packet palace parade parent partly patrol patron people pepper period permit person phrase picked pillar planet player plenty plunge pocket poetry poison police policy polish poorly poster potato potent powder prayer prefer pretty prince prison profit proper proven public purple pursue puzzle",
  "rabbit racial random ranger rarely rating reader really reason recall recent record reduce reform refuse regard region regret reject relate relief remain remind remote remove render rental repair repeat report rescue resign resist resort result retail retire return reveal review revolt reward ribbon rising ritual robust roller ruling",
  "saddle safely safety salary sample scheme school screen script search season secret secure seeing select seller senior series server settle severe shadow shield should shrimp signal silent silver simple simply single sister sketch slight smooth social solely sooner sought source speech spirit spread spring square stable status steady stream street stress strict strike string stroke strong studio submit sudden suffer summer supply surely survey switch symbol system",
  "tackle talent target temple tender terror thanks thirty though thread thrill thrive throne thrust ticket timber tissue toggle tongue toward travel treaty triple trophy tunnel twelve twenty typist",
  "unable unfair unfold unique united unless unlike unlock update uphold upward urgent useful",
  "valley varied vendor vessel viewer virgin vision visual volume",
  "wallet wander warmth weekly weight wholly wicked widely window winner winter wisdom wonder wooden worker worthy writer",
  "yellow yearly absolute baseball birthday building business calendar campaign cardinal champion children climbing combined comeback commerce commonly compiler complete computer consider contract convince corridor coverage creative criminal customer cylinder",
  "database deadline december defeated delicate delivery describe designer detailed diagonal dialogue diamond dinosaur directed discover division document dominant domestic download dramatic duration dynamics",
  "economic eighteen election electric eligible emission emphasis employee engineer enormous entirely entrance envelope entirely equipped estimate evaluate eventual everyone evidence exchange exciting exercise expanded expected explicit extended external",
  "facebook facility familiar favorite feedback festival Filipino findings finished flagship flexible floating focusing football forecast formerly formula fourteen fragment friendly frontier fullback function physical producer progress",
  "generate governor graduate graphics guardian guidance hardware headline heritage highland homepage honestly hospital humanity hundreds identify illusion imminent immunity imperial incident included increase indicate indirect industry inferior infinite informed inherent initiate innocent inspired instance integral interact interest internal interval investor isolated judgment keyboard language laughter leverage lifetime likewise literary location lockdown magnetic maintain majority managing marathon material measured mechanic medicine memorial merchant midnight military minimize minister minority moderate molecule momentum monopoly moreover mortgage mountain multiple multiply mushroom mystery national navigate neighbor notebook northern numerous obituary obstacle occasion offering official opponent opposing optional ordinary organize original orthodox outbreak overcome overhead overlook overtime overview painting parallel particle patience personal physical platform pleasure plunging pointing politics populate portable portrait position positive possible possibly powerful practice precious premiere presence pressing pressure previous priority probably producer profound progress properly property proposal prospect protocol province provider province publicly purchase pursuing quantity question reaction recently recorded recovery redesign regional register relation relative reliable religion remember repeated reporter republic required research resident resource response restrict reversal revision romantic rotation scenario schedule seasonal security semester sentence separate sequence sergeant sessions severity shooting shortage shoulder shutdown sideways simplify simulate singular sleeping slightly snapshot software solution somebody somewhat southern speaking specific spending sporting standard standing starting stepping stimulus stopping straight strategy strength striking strongly struggle suddenly suitable superior supposed surprise surround survival sweeping swimming symptom teaching terminal terrible thinking thirteen thorough thousand thriller tracking transfer treasure treating tropical troubled tutorial umbrella uncommon underway unlawful unlikely unlikely unrelated upcoming updating upstream valuable variable vertical victoria violence visiting volatile volatile warranty weakness whenever wherever wildlife wireless withdraw woodland workshop yourself",

  -- Programming verbs and common engineering actions
  "build cache catch check clone close code commit debug deploy fetch index input issue patch parse print probe queue raise retry scope serve spawn split stack start store trace train",
  "apply await bind branch build clear clone close debug defer fetch flush frame grant input merge patch parse probe query queue reset route scope serve spawn stack throw trace train write",
  "abort alias assign batch begin break build cache check clean clone close commit debug defer deploy draft fetch guard index insert issue label limit merge model mount parse patch pivot print query raise refit reply reset route scope search serve setup share shift sort split stage start store style trace train treat trigger update usage validate write",
  "compile connect decode define delete deploy derive encode export extend filter format import insert invoke iterate launch render return review search select submit switch toggle unpack update upload validate",
  "allocate assemble automate calculate configure construct deserialize dispatch document enumerate generate integrate maintain migrate navigate normalize optimize paginate populate reconcile refactor register serialize simplify synchronize transform translate validate visualize",
  "adapter analysis analyst anomaly archive atomic audit backup bitmap buffer builder callback capture checksum cluster collect compare compose compute context current dataset default dynamic element endpoint enhance episode example extract fallback feature gateway handler inspect install instance integer iterate layout lexical library lookup message metrics module monitor outcome package payload pointer profile project promise protocol publish rebuild redirect release request resolve resource restore rollback runtime sandbox scanner schema service session snippet socket staging storage stream syntax system target timeout toolkit trigger upgrade utility validate version virtual watcher wrapper",
}, " ")

-- Parsed word list (lazy init)
local _words = nil
local _filter_cache = {}
local _custom_words = {}

local function get_all_words()
  if _words then
    return _words
  end
  _words = {}
  local seen = {}
  for w in raw:gmatch("%S+") do
    if not seen[w] then
      _words[#_words + 1] = w
      seen[w] = true
    end
  end
  for _, w in ipairs(_custom_words) do
    if not seen[w] then
      _words[#_words + 1] = w
      seen[w] = true
    end
  end
  return _words
end

--- Replace the user's custom word pool. Accepts an array of strings; each
--- entry is split on whitespace so callers can pass either clean words or
--- raw chunks read from a file. Invalidates cached lookups.
--- @param list string[]|nil
function M.set_extra_words(list)
  _custom_words = {}
  local seen = {}
  if list then
    for _, entry in ipairs(list) do
      if type(entry) == "string" then
        for w in entry:gmatch("%S+") do
          if not seen[w] then
            _custom_words[#_custom_words + 1] = w
            seen[w] = true
          end
        end
      end
    end
  end
  _words = nil
  _filter_cache = {}
end

--- Whether a non-empty custom word pool has been configured.
--- @return boolean
function M.has_custom()
  return #_custom_words > 0
end

--- Get a copy of the current custom word pool.
--- @return string[]
function M.get_custom_words()
  local out = {}
  for i, w in ipairs(_custom_words) do
    out[i] = w
  end
  return out
end

-- Convert a chars string to a fast lookup table
local function make_set(chars)
  local set = {}
  for i = 1, #chars do
    set[chars:sub(i, i)] = true
  end
  return set
end

-- Check if a word uses only characters from the set
local function word_fits(word, set)
  for i = 1, #word do
    if not set[word:sub(i, i)] then
      return false
    end
  end
  return true
end

--- Filter words that only use the given characters.
--- @param chars string Allowed characters (e.g. "asdfjkl")
--- @return string[] Matching words
function M.filter(chars)
  local cached = _filter_cache[chars]
  if cached then
    return cached
  end

  local set = make_set(chars)
  local result = {}
  for _, w in ipairs(get_all_words()) do
    if word_fits(w, set) then
      result[#result + 1] = w
    end
  end
  _filter_cache[chars] = result
  return result
end

--- Generate a random character combination from the allowed set.
--- @param chars string Allowed characters
--- @param length number Combo length
--- @return string
function M.combo(chars, length)
  local result = {}
  for i = 1, length do
    local idx = math.random(1, #chars)
    result[i] = chars:sub(idx, idx)
  end
  return table.concat(result)
end

local function count_focus_chars(text, focus_set)
  local count = 0
  for i = 1, #text do
    if focus_set[text:sub(i, i)] then
      count = count + 1
    end
  end
  return count
end

local function word_length_bucket(word)
  local len = #word
  if len <= 4 then
    return "short"
  elseif len <= 6 then
    return "medium"
  end
  return "long"
end

local function build_selector(pool)
  local selector = {
    all = pool,
    short = {},
    medium = {},
    long = {},
  }

  for _, word in ipairs(pool) do
    selector[word_length_bucket(word)][#selector[word_length_bucket(word)] + 1] = word
  end

  return selector
end

local function make_length_targets(num_words)
  local short = math.max(1, math.floor(num_words * 0.32 + 0.5))
  local medium = math.max(1, math.floor(num_words * 0.43 + 0.5))
  local long = math.max(1, num_words - short - medium)
  return {
    short = short,
    medium = medium,
    long = long,
  }
end

local function remember_recent(recent, token, limit)
  recent[#recent + 1] = token
  if #recent > limit then
    table.remove(recent, 1)
  end
end

local function recently_used(recent, token)
  for i = 1, #recent do
    if recent[i] == token then
      return true
    end
  end
  return false
end

local function pick_best_candidate(pool, used_counts, recent, desired_bucket, bucket_counts, bucket_targets)
  if #pool == 0 then
    return nil
  end

  local best
  local best_score = -math.huge
  local samples = math.min(12, #pool)

  for _ = 1, samples do
    local candidate = pool[math.random(1, #pool)]
    local score = 0
    local used = used_counts[candidate] or 0
    local bucket = word_length_bucket(candidate)

    if used == 0 then
      score = score + 14
    else
      score = score - (used * 9)
    end

    if not recently_used(recent, candidate) then
      score = score + 6
    else
      score = score - 12
    end

    if desired_bucket and bucket == desired_bucket then
      score = score + 10
    elseif desired_bucket then
      score = score - 2
    end

    if bucket_counts and bucket_targets and bucket_counts[bucket] < bucket_targets[bucket] then
      score = score + 5
    end

    if score > best_score then
      best = candidate
      best_score = score
    end
  end

  return best or pool[math.random(1, #pool)]
end

local function choose_bucket(selector, bucket_counts, bucket_targets)
  local order = { "medium", "short", "long" }
  local best_bucket
  local best_gap = -math.huge

  for _, bucket in ipairs(order) do
    if #selector[bucket] > 0 then
      local gap = (bucket_targets[bucket] or 0) - (bucket_counts[bucket] or 0)
      if gap > best_gap then
        best_gap = gap
        best_bucket = bucket
      end
    end
  end

  return best_bucket
end

local function pick_word(selector, used_counts, recent, bucket_counts, bucket_targets)
  local desired_bucket = choose_bucket(selector, bucket_counts, bucket_targets)
  local primary_pool = desired_bucket and selector[desired_bucket] or selector.all
  local candidate = pick_best_candidate(primary_pool, used_counts, recent, desired_bucket, bucket_counts, bucket_targets)
  if not candidate then
    candidate = pick_best_candidate(selector.all, used_counts, recent, nil, bucket_counts, bucket_targets)
  end
  if candidate then
    used_counts[candidate] = (used_counts[candidate] or 0) + 1
    bucket_counts[word_length_bucket(candidate)] = (bucket_counts[word_length_bucket(candidate)] or 0) + 1
    remember_recent(recent, candidate, 4)
  end
  return candidate
end

local function preview_word(selector, used_counts, recent, bucket_counts, bucket_targets)
  local desired_bucket = choose_bucket(selector, bucket_counts, bucket_targets)
  local primary_pool = desired_bucket and selector[desired_bucket] or selector.all
  local candidate = pick_best_candidate(primary_pool, used_counts, recent, desired_bucket, bucket_counts, bucket_targets)
  if candidate then
    return candidate
  end
  return pick_best_candidate(selector.all, used_counts, recent, nil, bucket_counts, bucket_targets)
end

local function commit_word(token, used_counts, recent, bucket_counts)
  if not token then
    return nil
  end
  used_counts[token] = (used_counts[token] or 0) + 1
  bucket_counts[word_length_bucket(token)] = (bucket_counts[word_length_bucket(token)] or 0) + 1
  remember_recent(recent, token, 4)
  return token
end

local function build_focus_combo(chars, focus, length)
  return M.combo(focus .. focus .. chars, length)
end

local function word_has_transition(word, transition)
  return word:find(transition, 1, true) ~= nil
end

local function count_transition_hits(text, transitions)
  local hits = 0
  for _, transition in ipairs(transitions) do
    local start = 1
    while true do
      local s = text:find(transition, start, true)
      if not s then
        break
      end
      hits = hits + 1
      start = s + 1
    end
  end
  return hits
end

local function build_transition_combo(transitions)
  local transition = transitions[math.random(1, #transitions)]
  local fragments = {
    transition,
    transition .. transition,
    transition:sub(2, 2) .. transition,
    transition .. transition:sub(1, 1),
  }
  return fragments[math.random(1, #fragments)]
end

local function make_token_with_transition(transition, style)
  style = style or "default"
  local a = transition:sub(1, 1)
  local b = transition:sub(2, 2)

  if style == "same_finger" then
    local fragments = {
      transition,
      transition .. transition,
      a .. transition .. a,
      b .. transition .. b,
      a .. b .. a .. b,
    }
    return fragments[math.random(1, #fragments)]
  elseif style == "cross_center" then
    local fragments = {
      transition,
      transition .. transition,
      "t" .. transition,
      transition .. "y",
      a .. transition .. b,
    }
    return fragments[math.random(1, #fragments)]
  elseif style == "thumb_cluster" then
    local fragments = {
      transition,
      transition .. " ",
      " " .. transition,
      transition .. "\n" .. transition,
      a .. " " .. b,
    }
    return fragments[math.random(1, #fragments)]
  elseif style == "symbol_jump" then
    local fragments = {
      transition,
      transition .. transition,
      "(" .. transition .. ")",
      "[" .. transition .. "]",
      transition .. ";",
    }
    return fragments[math.random(1, #fragments)]
  elseif style == "number_row" then
    local fragments = {
      transition,
      transition .. transition,
      transition .. "0",
      "1" .. transition,
      a .. b .. "42",
    }
    return fragments[math.random(1, #fragments)]
  elseif style == "cross_hand" then
    local fragments = {
      transition,
      transition .. transition,
      a .. transition,
      transition .. b,
      a .. b .. a .. b,
    }
    return fragments[math.random(1, #fragments)]
  elseif style == "same_hand" then
    local fragments = {
      transition,
      transition .. transition,
      a .. transition,
      b .. transition,
      a .. a .. b,
    }
    return fragments[math.random(1, #fragments)]
  end

  return build_transition_combo({ transition })
end

local function token_has_allowed_chars(token, allowed_set)
  if not allowed_set then
    return true
  end
  for i = 1, #token do
    local ch = token:sub(i, i)
    if not allowed_set[ch] then
      return false
    end
  end
  return true
end

local function transition_in_token(token, transitions)
  for _, transition in ipairs(transitions) do
    if token:find(transition, 1, true) then
      return true
    end
  end
  return false
end

local function build_curated_token(transitions, curated_templates, style)
  if not curated_templates or #curated_templates == 0 then
    return nil
  end

  local template = curated_templates[math.random(1, #curated_templates)]
  local transition = transitions[math.random(1, #transitions)]
  local a = transition:sub(1, 1)
  local b = transition:sub(2, 2)
  template = template:gsub("{transition}", transition)
  template = template:gsub("{a}", a)
  template = template:gsub("{b}", b)

  if transition_in_token(template, transitions) then
    return template
  end
  return make_token_with_transition(transition, style)
end

--- Generate a complete random exercise.
--- @param opts { chars: string, focus_chars?: string, min_focus_density?: number, min_focus_occurrences?: number, min_words?: number, max_words?: number }
--- @return string
function M.generate(opts)
  local chars = opts.chars or "abcdefghijklmnopqrstuvwxyz"
  local focus = opts.focus_chars
  local min_density = opts.min_focus_density
  local min_focus_occurrences = opts.min_focus_occurrences or 0
  local min_words = opts.min_words or 10
  local max_words = opts.max_words or 20

  local pool = M.filter(chars)

  -- When min_focus_density is set, narrow pool to words where at least
  -- that fraction of characters come from focus_chars. This gives words
  -- that heavily exercise the target keys while using the full alphabet.
  if min_density and focus and #focus > 0 then
    local fset = make_set(focus)
    local dense = {}
    for _, w in ipairs(pool) do
      local count = 0
      for i = 1, #w do
        if fset[w:sub(i, i)] then
          count = count + 1
        end
      end
      if count / #w >= min_density then
        dense[#dense + 1] = w
      end
    end
    pool = dense
  end

  local num_words = math.random(min_words, max_words)

  -- Adaptive combo ratio based on available word pool
  local combo_ratio
  if #pool < 8 then
    combo_ratio = 0.7
  elseif #pool < 25 then
    combo_ratio = 0.4
  elseif #pool < 80 then
    combo_ratio = 0.2
  else
    combo_ratio = 0.08
  end

  -- Build focus word pool (words containing at least one focus char)
  local focus_pool = {}
  local dense_focus_pool = {}
  if focus and #focus > 0 then
    local focus_set = make_set(focus)
    for _, w in ipairs(pool) do
      local focus_count = 0
      for i = 1, #w do
        if focus_set[w:sub(i, i)] then
          focus_count = focus_count + 1
        end
      end
      if focus_count > 0 then
        focus_pool[#focus_pool + 1] = w
      end
      if focus_count >= math.max(2, math.ceil(#w * 0.34)) then
        dense_focus_pool[#dense_focus_pool + 1] = w
      end
    end
  end

  local result = {}
  local focus_set = focus and #focus > 0 and make_set(focus) or nil
  local focus_hits = 0
  local used_counts = {}
  local recent = {}
  local bucket_targets = make_length_targets(num_words)
  local bucket_counts = { short = 0, medium = 0, long = 0 }
  local selector = build_selector(pool)
  local focus_selector = build_selector(focus_pool)
  local dense_focus_selector = build_selector(dense_focus_pool)
  for i = 1, num_words do
    local token
    local force_focus = focus_set and (
      i <= math.min(3, num_words)
      or focus_hits < min_focus_occurrences
      or (i % 4 == 0 and math.random() < 0.7)
    )

    if (math.random() < combo_ratio or #pool == 0) and (not force_focus or not focus_set) then
      token = M.combo(chars, math.random(2, 5))
    else
      if force_focus and focus_set then
        if #dense_focus_pool > 0 and math.random() < 0.72 then
          token = pick_word(dense_focus_selector, used_counts, recent, bucket_counts, bucket_targets)
        elseif #focus_pool > 0 and math.random() < 0.9 then
          token = pick_word(focus_selector, used_counts, recent, bucket_counts, bucket_targets)
        else
          token = build_focus_combo(chars, focus, math.random(2, 5))
        end
      elseif #focus_pool > 0 and math.random() < 0.55 then
        token = pick_word(focus_selector, used_counts, recent, bucket_counts, bucket_targets)
      else
        token = pick_word(selector, used_counts, recent, bucket_counts, bucket_targets)
      end
    end

    result[i] = token
    if focus_set then
      focus_hits = focus_hits + count_focus_chars(token, focus_set)
    end
  end

  return table.concat(result, " ")
end

--- Generate an exercise drawing only from the user's custom word pool.
--- Uses the same diversity/bucketing pass as generate() but bypasses
--- character-set filtering and combo tokens — the user's words are the spec.
--- @param opts { min_words?: number, max_words?: number }|nil
--- @return string|nil
function M.generate_custom(opts)
  opts = opts or {}
  if #_custom_words == 0 then
    return nil
  end

  local min_words = opts.min_words or 12
  local max_words = opts.max_words or 20
  if max_words < min_words then
    max_words = min_words
  end

  local num_words = math.random(min_words, max_words)
  local used_counts = {}
  local recent = {}
  local bucket_targets = make_length_targets(num_words)
  local bucket_counts = { short = 0, medium = 0, long = 0 }
  local selector = build_selector(_custom_words)

  local result = {}
  for i = 1, num_words do
    local token = pick_word(selector, used_counts, recent, bucket_counts, bucket_targets)
    result[i] = token or _custom_words[math.random(1, #_custom_words)]
  end

  return table.concat(result, " ")
end

--- Generate text biased toward specific transitions.
--- @param opts { transitions: string[], min_words?: number, max_words?: number, min_transition_hits?: number, combo_ratio?: number, style?: string, allowed_chars?: string, plain_ratio?: number, newline_ratio?: number, curated_templates?: string[], curated_ratio?: number }
--- @return string
function M.generate_transition_drill(opts)
  opts = opts or {}
  local transitions = opts.transitions or {}
  if #transitions == 0 then
    return M.generate({
      chars = "abcdefghijklmnopqrstuvwxyz",
      min_words = opts.min_words or 10,
      max_words = opts.max_words or 16,
    })
  end

  local min_words = opts.min_words or 12
  local max_words = opts.max_words or 20
  local min_hits = opts.min_transition_hits or math.max(8, #transitions * 3)
  local combo_ratio = opts.combo_ratio or 0.22
  local style = opts.style or "default"
  local plain_ratio = opts.plain_ratio or 0.35
  local newline_ratio = opts.newline_ratio or 0
  local curated_templates = opts.curated_templates or {}
  local curated_ratio = opts.curated_ratio or 0
  local allowed_set = opts.allowed_chars and make_set(opts.allowed_chars) or nil
  local all_words = get_all_words()
  local plain_word_pool = {}
  local transition_pool = {}

  for _, w in ipairs(all_words) do
    if not allowed_set or token_has_allowed_chars(w, allowed_set) then
      plain_word_pool[#plain_word_pool + 1] = w
    end
    if allowed_set and not token_has_allowed_chars(w, allowed_set) then
      goto continue_word
    end
    for _, transition in ipairs(transitions) do
      if word_has_transition(w, transition) then
        transition_pool[#transition_pool + 1] = w
        break
      end
    end
    ::continue_word::
  end

  local result = {}
  local num_words = math.random(min_words, max_words)
  local transition_hits = 0
  local used_counts = {}
  local recent = {}
  local bucket_targets = make_length_targets(num_words)
  local bucket_counts = { short = 0, medium = 0, long = 0 }
  local transition_selector = build_selector(transition_pool)
  local all_word_selector = build_selector(#plain_word_pool > 0 and plain_word_pool or all_words)

  for i = 1, num_words do
    local force_transition = i <= math.min(4, num_words)
      or transition_hits < min_hits
      or (i % 4 == 0 and math.random() < 0.7)

    local token
    if force_transition then
      if #curated_templates > 0 and math.random() < curated_ratio then
        token = build_curated_token(transitions, curated_templates, style)
      elseif #transition_pool > 0 and math.random() < (1 - combo_ratio) then
        token = pick_word(transition_selector, used_counts, recent, bucket_counts, bucket_targets)
      else
        token = make_token_with_transition(transitions[math.random(1, #transitions)], style)
      end
    else
      if #curated_templates > 0 and math.random() < math.max(0.12, curated_ratio * 0.7) then
        token = build_curated_token(transitions, curated_templates, style)
      elseif #transition_pool > 0 and math.random() < plain_ratio then
        token = pick_word(transition_selector, used_counts, recent, bucket_counts, bucket_targets)
      else
        local attempts = 0
        repeat
          token = preview_word(all_word_selector, used_counts, recent, bucket_counts, bucket_targets)
          attempts = attempts + 1
        until (not allowed_set or token_has_allowed_chars(token, allowed_set)) or attempts > 40
        if allowed_set and not token_has_allowed_chars(token, allowed_set) then
          token = make_token_with_transition(transitions[math.random(1, #transitions)], style)
        else
          token = commit_word(token, used_counts, recent, bucket_counts)
        end
      end
    end

    result[#result + 1] = token
    if newline_ratio > 0 and i < num_words and math.random() < newline_ratio then
      result[#result] = result[#result] .. "\n"
    end
    transition_hits = transition_hits + count_transition_hits(token, transitions)
  end

  return table.concat(result, " ")
end

--- Get the total word count in the database.
--- @return number
function M.count()
  return #get_all_words()
end

return M
