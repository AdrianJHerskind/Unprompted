#!/bin/bash
# Measures how much CPU each character costs while it stands, walks, talks and sleeps, so a change
# can be compared with main before it goes into a pull request (see "Checking CPU use" in the README).
#
#   tools/cpu-benchmark.sh [options]
#     --compare <git ref>    also measure where your work started from <ref> (e.g. main), side by side
#     -c, --characters a,b   characters to measure (default: all; --list shows them)
#     -m, --modes a,b        any of idle, walk, talk, sleep (default: all four)
#     -a, --accessories      wear a party hat and a coffee
#     -s, --seconds n        length of each measurement (default: 8)
#     -r, --rounds n         repeat everything n times and take the median (default: 1)
#     --screen n             screen to run on, 0 = the main screen (default: 0)
#     --list                 list the character ids and exit
#     -h, --help             show this
set -euo pipefail
unset CDPATH
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
BENCH="$ROOT/tools/cpu-benchmark/main.swift"

REF="" CHARS="" MODES="idle walk talk sleep" ACCESSORIES="" SECS=8 ROUNDS=1 SCREEN=0 LIST=0
usage() { sed -n '5,14p' "$0" | sed 's/^# \{0,1\}//'; }
die() { echo "$1" >&2; exit "${2:-64}"; }
need() { # <option> <value>: an option's value must be there and not be another option
    case "${2-}" in ''|-*) die "$1 needs a value (see --help)" ;; esac
}
count() { # <option> <value>: a whole number of at least 1
    case "$2" in ''|*[!0-9]*|0*) die "$1 needs a whole number of at least 1" ;; esac
}
while [ $# -gt 0 ]; do
    case "$1" in
        --compare) need "$1" "${2-}"; REF="$2"; shift ;;
        -c|--characters) need "$1" "${2-}"; CHARS="$(echo $(echo "$2" | tr ',' ' '))"; [ -n "$CHARS" ] || die "$1 needs a value (see --help)"; shift ;;
        -m|--modes) need "$1" "${2-}"; MODES="$(echo "$2" | tr ',' ' ')"; shift ;;
        -a|--accessories) ACCESSORIES=accessories ;;
        -s|--seconds) need "$1" "${2-}"; count "$1" "$2"; SECS="$2"; shift ;;
        -r|--rounds) need "$1" "${2-}"; count "$1" "$2"; ROUNDS="$2"; shift ;;
        --screen) need "$1" "${2-}"; SCREEN="$2"; shift ;;
        --list) LIST=1 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown option $1" >&2; usage >&2; exit 64 ;;
    esac
    shift
done
case "$SCREEN" in ''|*[!0-9]*) die "--screen needs a screen number (0 is the main screen)" ;; esac
[ -n "$(echo $MODES)" ] || die "-m needs at least one mode"
for m in $MODES; do
    case "$m" in idle|walk|talk|sleep) ;; *) die "Unknown mode $m (idle, walk, talk or sleep)" ;; esac
done

# The base to compare with: where this checkout's history meets <ref>, so commits that arrived on
# <ref> since you started aren't counted as yours.
if [ -n "$REF" ]; then
    git -C "$ROOT" rev-parse --verify --quiet "$REF^{commit}" > /dev/null || die "Unknown git ref $REF"
    BASE="$(git -C "$ROOT" merge-base "$REF" HEAD)" || die "$REF and this checkout have no history in common"
    if [ "$BASE" = "$(git -C "$ROOT" rev-parse HEAD)" ] && git -C "$ROOT" diff --quiet HEAD -- Sources Resources \
        && [ -z "$(git -C "$ROOT" ls-files --others --exclude-standard -- Sources Resources)" ]; then
        die "Nothing to compare: this checkout has no changes of its own against $REF. If your work is committed on $REF, compare with where you started, e.g. --compare origin/main (or upstream/main in a fork)."
    fi
    BASE_NAME="$(git -C "$ROOT" rev-parse --short "$BASE")"
    # "main (1a2b3c4)", or the commit alone when that's what was asked for.
    BASE_LABEL="$REF ($BASE_NAME)"
    [ "$(git -C "$ROOT" rev-parse "$REF^{commit}")" = "$BASE" ] || BASE_LABEL="$BASE_NAME, where you started from $REF"
    case "$BASE" in "$REF"*) BASE_LABEL="$BASE_NAME" ;; esac
fi

WORK="$(mktemp -d -t unprompted-cpu)"
trap 'rm -rf "$WORK"' EXIT
# Ten minutes alone is long enough for the display to go to sleep, which would stop the drawing.
caffeinate -d -i -w $$ &

# Builds the benchmark against the app's sources in <tree>, like the app but with our main.swift.
build() { # <tree> <output>
    (cd "$1" && swiftc -O -suppress-warnings $(find Sources -name '*.swift' ! -name main.swift) "$BENCH" -o "$2") \
        > "$WORK/build.log" 2>&1
}

echo "Building this checkout..." >&2
build "$ROOT" "$WORK/this" || { cat "$WORK/build.log" >&2; exit 1; }
ALL="$(cd "$ROOT" && "$WORK/this" --list)"
if [ "$LIST" = 1 ]; then echo "$ALL"; exit 0; fi
SCREENS="$("$WORK/this" --screens)"
if [ "$SCREEN" -ge "$SCREENS" ]; then
    [ "$SCREENS" = 1 ] && die "There's no screen $SCREEN: there's only the main screen, 0."
    die "There's no screen $SCREEN: they're numbered 0 to $(( SCREENS - 1 )), and 0 is the main screen."
fi
[ -n "$CHARS" ] || CHARS="$ALL"
for c in $CHARS; do
    case " $ALL " in *" $c "*) ;; *) die "Unknown character $c (there are: $ALL)" ;; esac
done

if [ -n "$REF" ]; then
    echo "Building $BASE_LABEL..." >&2
    mkdir "$WORK/base"
    git -C "$ROOT" archive "$BASE" | tar -x -C "$WORK/base"
    # Characters kept only on this Mac (git ignores them) take part on both sides if they still build there.
    LOCAL=Sources/Unprompted/Characters/Local
    if [ -d "$ROOT/$LOCAL" ]; then cp -R "$ROOT/$LOCAL" "$WORK/base/$LOCAL"; fi
    if ! build "$WORK/base" "$WORK/base-bench" && [ -d "$WORK/base/$LOCAL" ]; then
        echo "Your local characters don't build with $BASE_NAME, so they're left out there." >&2
        rm -rf "$WORK/base/$LOCAL"
        build "$WORK/base" "$WORK/base-bench" || true
    fi
    [ -x "$WORK/base-bench" ] || { cat "$WORK/build.log" >&2; die "The benchmark doesn't build against $BASE_NAME (it needs a version from October 2026 or later)." 1; }
    # Characters your change adds have nothing to be compared with.
    BASE_ALL="$(cd "$WORK/base" && "$WORK/base-bench" --list)"
    for c in $CHARS; do
        case " $BASE_ALL " in *" $c "*) ;; *) NEW="${NEW-} $c" ;; esac
    done
fi

if pgrep -xq Unprompted; then echo "Note: Unprompted is running. Quit it first for steadier numbers." >&2; fi
LOAD="$(sysctl -n vm.loadavg | awk '{ print int($2) }')"
if [ "$LOAD" -ge $(( $(sysctl -n hw.ncpu) * 3 / 4 )) ]; then
    echo "Note: the Mac looks busy (load $LOAD). Close what you can: the numbers will be noisy." >&2
fi

BUILDS="this"; [ -n "$REF" ] && BUILDS="base this"
set -- $CHARS; NCHARS=$#
set -- $MODES; NMODES=$#
set -- ${NEW-}; NNEW=$#
PAIRS=$(( NCHARS * NMODES ))
[ -n "$REF" ] && PAIRS=$(( 2 * NCHARS * NMODES - NNEW * NMODES ))
TOTAL=$(( ROUNDS * (1 + PAIRS) ))
MINUTES=$(( (TOTAL * (SECS + 3) + 59) / 60 ))
plural() { [ "$1" = 1 ] && echo "$1 $2" || echo "$1 ${2}s"; }
echo "$(plural $TOTAL run) of $SECS s, about $(plural $MINUTES minute). Leave the Mac alone until it's done," >&2
echo "and don't lock or cover the screen: a creature nobody can see stops drawing." >&2

DONE=0
run() { # <build> <character> <mode>
    local binary="$WORK/this" tree="$ROOT" name=this
    if [ "$1" = base ]; then
        case " ${NEW-} " in *" $2 "*) return ;; esac
        binary="$WORK/base-bench" tree="$WORK/base" name="$BASE_NAME"
    fi
    DONE=$(( DONE + 1 ))
    printf '\r[%d/%d] %-8s %-14s %-6s' "$DONE" "$TOTAL" "$name" "$2" "$3" >&2
    if (cd "$tree" && "$binary" "$2" "$3" "$SECS" "$SCREEN" $ACCESSORIES) > "$WORK/run.out" 2> "$WORK/run.err"; then :; fi
    if grep -q '^RESULT ' "$WORK/run.out"; then
        sed -n "s/^RESULT /$1 $round /p" "$WORK/run.out" >> "$WORK/results"
    else
        echo "$name $2 $3: $(head -c 300 "$WORK/run.err" | tr '\n' ' ')" >> "$WORK/failed"
    fi
}

# The first run after a build can come out several times too high, so each build gets one that
# doesn't count.
set -- $CHARS
for b in $BUILDS; do
    binary="$WORK/this" tree="$ROOT"
    [ "$b" = base ] && binary="$WORK/base-bench" tree="$WORK/base"
    (cd "$tree" && "$binary" "$1" idle 1 "$SCREEN") > /dev/null 2>&1 || true
done

for (( round = 1; round <= ROUNDS; round++ )); do
    run this none none
    # Without a background run (a wrong --screen, say), nothing else can work either.
    if [ $round = 1 ] && [ -s "$WORK/failed" ]; then printf '\n' >&2; cat "$WORK/failed" >&2; exit 1; fi
    for c in $CHARS; do
        for m in $MODES; do
            # Alternating which build goes first evens out drift over a long run.
            if [ -n "$REF" ] && [ $(( round % 2 )) = 1 ]; then run base "$c" "$m"; run this "$c" "$m"
            elif [ -n "$REF" ]; then run this "$c" "$m"; run base "$c" "$m"
            else run this "$c" "$m"; fi
        done
    done
done
printf '\r%60s\r' '' >&2

awk -v ref="$REF" -v base="${BASE_LABEL-}" -v chars="$CHARS" -v modes="$MODES" -v new="${NEW-}" -v screen="$SCREEN" -v extras="$ACCESSORIES" '
    # Fields: build round character mode scale app-cpu app-instructions windowserver windowmanager.
    # Each round starts with a run without a creature, the background for that round.
    function add(name, k, v) { if (v != "-") { vals[name, k, ++cnt[name, k]] = v } }
    # The median, which a single odd run doesn'"'"'t pull around.
    function median(name, k,    n, i, j, t, a) {
        n = cnt[name, k]; if (!n) return ""
        for (i = 1; i <= n; i++) a[i] = vals[name, k, i]
        for (i = 2; i <= n; i++) for (j = i; j > 1 && a[j - 1] > a[j]; j--) { t = a[j]; a[j] = a[j - 1]; a[j - 1] = t }
        return n % 2 ? a[(n + 1) / 2] : (a[n / 2] + a[n / 2 + 1]) / 2
    }
    $4 == "none" { bgws[$2] = $8; bgwm[$2] = $9; add("ws", "bg", $8); scale = $5; next }
    function above(v, bg) { return v == "-" || bg == "" || bg == "-" ? "-" : v - bg }
    {
        k = $1 SUBSEP $3 SUBSEP $4; seen[k] = 1
        add("app", k, $6); add("ins", k, $7); add("ws", k, above($8, bgws[$2])); add("wm", k, above($9, bgwm[$2]))
    }
    function cell(build, c, m, what,    k, v) {
        k = build SUBSEP c SUBSEP m
        if (!seen[k]) return build == "base" && index(" " new " ", " " c " ") ? "new" : "-"
        v = median(what, k); if (v == "") return "-"
        if (what == "app") return sprintf("%.1f%%", v)
        if (what == "ins") return sprintf("%.0f", v)
        return sprintf("%+.1f%%", v)
    }
    function pair(c, m, what) { return ref == "" ? cell("this", c, m, what) : cell("base", c, m, what) " -> " cell("this", c, m, what) }
    END {
        w = ref == "" ? 15 : 21
        printf "\n%-14s %-6s %" w "s %" w "s %" w "s %" w "s\n", "", "", "App CPU", "App instr. M/s", "WindowManager", "WindowServer"
        nc = split(chars, cs, " "); nm = split(modes, ms, " ")
        for (i = 1; i <= nc; i++) for (j = 1; j <= nm; j++)
            printf "%-14s %-6s %" w "s %" w "s %" w "s %" w "s\n", cs[i], ms[j], pair(cs[i], ms[j], "app"), pair(cs[i], ms[j], "ins"), pair(cs[i], ms[j], "wm"), pair(cs[i], ms[j], "ws")
        who = ref == "" ? "This checkout" : base " -> this checkout"
        printf "\n%s on screen %d (%sx)%s.\n", who, screen, scale, (extras != "" ? ", with hat and coffee" : "")
        print "App CPU: the creature itself, in % of one core. App instr.: the instructions it ran, in millions"
        print "a second; they don'"'"'t depend on which cores macOS picked, so compare builds by them first."
        idle = median("ws", "bg")
        print "WindowManager and WindowServer: macOS'"'"'s work for our windows, which Activity Monitor doesn'"'"'t count"
        print "as Unprompted'"'"'s, shown above their idle level (WindowServer idles at " (idle == "" ? "?" : sprintf("%.0f%%", idle)) "). Anything else on"
        print "the screen moves them too, so only trust big differences there."
        print "Differences under about 20% can be noise: check them with -r 3."
    }
' "$WORK/results"

if [ -s "$WORK/failed" ]; then
    echo >&2
    echo "These runs failed, so their cells show -:" >&2
    cat "$WORK/failed" >&2
    exit 1
fi
