#!/usr/bin/env bash
# Ручное зеркало контрактных тестов — quickstart.md §2 (задача T061).
#
# Требует запущенного в соседнем терминале `npm run dev` (wrangler dev --env dev)
# и заполненного GEMINI_API_KEY в proxy/.dev.vars.
#
#   ./tools/quickstart-s2.sh            # все секции
#   ./tools/quickstart-s2.sh codes      # только коды отказа (без обращений к Gemini там, где можно)
#   ./tools/quickstart-s2.sh text       # выборка реплик глазами: 20 штук, attempt 0..5, mood 1 vs 5
#   ./tools/quickstart-s2.sh thinking   # прямая проверка usageMetadata у Gemini
#
# Скрипт правит config:app в локальном KV и чистит счётчики в локальной D1.
# Исходный config:app восстанавливается на выходе.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

BASE=${BASE:-http://localhost:8787}
DEFAULT_APP='{"aiEnabled":true,"models":["gemini-3.5-flash-lite","gemini-3.1-flash-lite"],"dailyCapOverride":400,"perDeviceCapOverride":15}'
PASS=0
FAIL=0

command -v jq >/dev/null || { echo "нужен jq: brew install jq"; exit 1; }

kv_app() {
  printf '%s' "$1" > /tmp/rtz-app.json
  npx wrangler kv key put --binding CONFIG --env dev --local config:app --path=/tmp/rtz-app.json >/dev/null 2>&1
}

reset_counters() {
  npx wrangler d1 execute roundtablezoo-ai-dev --env dev --local \
    --command "DELETE FROM rate_limits; DELETE FROM global_limits;" >/dev/null 2>&1
}

post() { # $1 = тело; печатает код, тело кладёт в /tmp/rtz-body.json
  curl -s -o /tmp/rtz-body.json -w '%{http_code}' "$BASE/react" \
    -H 'content-type: application/json' -d "$1"
}

# check <название> <ожидаемый код> <тело запроса> [jq-фильтр -> ожидаемое значение]
check() {
  local name=$1 want=$2 body=$3 filter=${4:-} want_val=${5:-}
  local got; got=$(post "$body")
  local ok=1
  [ "$got" = "$want" ] || ok=0
  if [ -n "$filter" ] && [ "$ok" = 1 ]; then
    local val; val=$(jq -r "$filter" < /tmp/rtz-body.json 2>/dev/null)
    [ "$val" = "$want_val" ] || { ok=0; got="$got ($filter=$val)"; }
  fi
  if [ "$ok" = 1 ]; then
    PASS=$((PASS+1)); printf '  \033[32mok\033[0m   %-58s %s\n' "$name" "$want"
  else
    FAIL=$((FAIL+1)); printf '  \033[31mFAIL\033[0m %-58s ждали %s, получили %s\n' "$name" "$want" "$got"
    head -c 300 /tmp/rtz-body.json | sed 's/^/       /'; echo
  fi
}

body() { # body <installId> <characterId> <moodScore> <dayText> <attempt>
  jq -nc --arg i "$1" --arg c "$2" --argjson m "$3" --arg t "$4" --argjson a "$5" \
    '{installId:$i, characterId:$c, moodScore:$m, dayText:$t, attempt:$a}'
}

new_id() { openssl rand -hex 16; }

restore() { echo; echo "восстанавливаю config:app по умолчанию"; kv_app "$DEFAULT_APP"; }
trap restore EXIT

curl -s -o /dev/null --max-time 3 "$BASE/react" || { echo "служба не отвечает на $BASE — запущен ли npm run dev?"; exit 1; }

ID=$(new_id)
TEXT='Сегодня был длинный день, но я справился.'
LONG=$(python3 -c 'print("а"*2001)')

section_codes() {
  echo; echo "── коды отказа (react-api.md §4) ──"
  kv_app "$DEFAULT_APP"; reset_counters

  check 'characterId: "unicorn"'          400 "$(body "$ID" unicorn 2 "$TEXT" 0)"  .error bad_request
  check 'dayText: ""'                     400 "$(body "$ID" hippo   2 ""      0)"  .error bad_request
  check 'dayText длиной 2001'             400 "$(body "$ID" hippo   2 "$LONG" 0)"  .error bad_request
  check 'moodScore: 7'                    400 "$(body "$ID" hippo   7 "$TEXT" 0)"  .error bad_request
  check 'без moodScore'                   400 "$(jq -nc --arg i "$ID" --arg t "$TEXT" '{installId:$i,characterId:"hippo",dayText:$t,attempt:0}')" .error bad_request
  check 'attempt: -1'                     400 "$(body "$ID" hippo   2 "$TEXT" -1)" .error bad_request
  check 'installId не 32 hex'             400 "$(body "abc" hippo   2 "$TEXT" 0)"  .error bad_request

  echo; echo "  kill switch"
  kv_app '{"aiEnabled":false,"models":["gemini-3.5-flash-lite"],"dailyCapOverride":400,"perDeviceCapOverride":15}'
  check 'aiEnabled: false'                503 "$(body "$ID" hippo 2 "$TEXT" 0)"    .error ai_disabled

  echo; echo "  персональный предел (perDeviceCapOverride: 2)"
  kv_app '{"aiEnabled":true,"models":["gemini-3.5-flash-lite","gemini-3.1-flash-lite"],"dailyCapOverride":400,"perDeviceCapOverride":2}'
  reset_counters
  local d; d=$(new_id)
  check '1-й запрос того же устройства'   200 "$(body "$d" hippo 2 "$TEXT" 0)"
  check '2-й запрос'                      200 "$(body "$d" hippo 2 "$TEXT" 1)"
  check '3-й запрос → device'             429 "$(body "$d" hippo 2 "$TEXT" 2)"     .scope device

  echo; echo "  общий предел, обе модели в списке (SC-006a)"
  kv_app '{"aiEnabled":true,"models":["gemini-3.5-flash-lite","gemini-3.1-flash-lite"],"dailyCapOverride":2,"perDeviceCapOverride":15}'
  reset_counters
  check '1-й (основная модель)'           200 "$(body "$(new_id)" hippo 2 "$TEXT" 0)"
  check '2-й (основная модель)'           200 "$(body "$(new_id)" hippo 2 "$TEXT" 0)"
  check '3-й — переходит на резервную'    200 "$(body "$(new_id)" hippo 2 "$TEXT" 0)"

  echo; echo "  общий предел, только основная модель"
  kv_app '{"aiEnabled":true,"models":["gemini-3.5-flash-lite"],"dailyCapOverride":2,"perDeviceCapOverride":15}'
  reset_counters
  check '1-й'                             200 "$(body "$(new_id)" hippo 2 "$TEXT" 0)"
  check '2-й'                             200 "$(body "$(new_id)" hippo 2 "$TEXT" 0)"
  check '3-й → global'                    429 "$(body "$(new_id)" hippo 2 "$TEXT" 0)" .scope global

  echo; echo "  непригодный ответ модели (несуществующая модель = мусор от провайдера)"
  kv_app '{"aiEnabled":true,"models":["gemini-нет-такой-модели"],"dailyCapOverride":400,"perDeviceCapOverride":15}'
  reset_counters
  check 'мусор от Gemini → после повтора' 422 "$(body "$(new_id)" hippo 2 "$TEXT" 0)" .error invalid_ai_response

  echo; echo "  счётчики (SC-009): ни одной строки с текстом дня"
  npx wrangler d1 execute roundtablezoo-ai-dev --env dev --local \
    --command "SELECT * FROM rate_limits; SELECT * FROM global_limits;" 2>/dev/null | sed 's/^/  /'
}

section_text() {
  echo; echo "── текст реплик глазами (SC-003a, SC-003b, FR-001a) ──"
  kv_app "$DEFAULT_APP"; reset_counters

  echo; echo "  один installId + hippo, attempt 0..5 — образы обязаны быть РАЗНЫМИ:"
  local a; a=$(new_id)
  for n in 0 1 2 3 4 5; do
    post "$(body "$a" hippo 2 "$TEXT" "$n")" >/dev/null
    printf '   attempt=%s  ' "$n"; jq -r '.reply // .error' < /tmp/rtz-body.json
  done

  echo; echo "  один текст, moodScore 1 против 5 — реплики обязаны заметно различаться:"
  for m in 1 5; do
    post "$(body "$(new_id)" hippo "$m" "$TEXT" 0)" >/dev/null
    printf '   mood=%s  ' "$m"; jq -r '.reply // .error' < /tmp/rtz-body.json
  done

  echo; echo "  выборка 20 реплик (SC-003b): ни одна не начинается с обращения к пользователю,"
  echo "  не содержит вопроса и не обещает, что завтра будет лучше."
  reset_counters
  for n in $(seq 1 20); do
    post "$(body "$(new_id)" hippo $(( (n % 5) + 1 )) "$TEXT" $(( n % 6 )))" >/dev/null
    printf '   %2s. ' "$n"; jq -r '.reply // .error' < /tmp/rtz-body.json
  done
}

section_mood() {
  echo; echo "── температура реплики по moodScore (FR-001a, ручная строка §2) ──"
  kv_app "$DEFAULT_APP"; reset_counters
  echo "  один и тот же текст, оценка 1..5, по два прогона — тон обязан теплеть со шкалой:"
  for pass in 1 2; do
    echo "   ── прогон $pass ──"
    for m in 1 2 3 4 5; do
      post "$(body "$(new_id)" hippo "$m" "$TEXT" 0)" >/dev/null
      printf '   score=%s  ' "$m"
      jq -rc '"[\(.mood // .error) \(.intensity // "-")] \(.reply // "")"' < /tmp/rtz-body.json
    done
  done
}

section_thinking() {
  echo; echo "── usageMetadata: thoughtsTokenCount не должно быть (research.md R6) ──"
  local key; key=$(grep '^GEMINI_API_KEY=' .dev.vars | cut -d= -f2-)
  [ -n "$key" ] || { echo "  GEMINI_API_KEY не найден в .dev.vars"; return; }
  curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent" \
    -H 'content-type: application/json' -H "x-goog-api-key: $key" \
    -d '{"contents":[{"parts":[{"text":"Скажи одно слово."}]}],
         "generationConfig":{"thinkingConfig":{"thinkingLevel":"minimal"}}}' \
    | jq '.usageMetadata'
  echo "  ↑ поля thoughtsTokenCount быть не должно"
}

case "${1:-all}" in
  codes)    section_codes ;;
  text)     section_text ;;
  mood)     section_mood ;;
  thinking) section_thinking ;;
  all)      section_codes; section_text; section_mood; section_thinking ;;
  *)        echo "использование: $0 [all|codes|text|mood|thinking]"; exit 1 ;;
esac

echo
echo "──────────────────────────────────────────"
printf 'прошло: %s   упало: %s\n' "$PASS" "$FAIL"
[ "$FAIL" = 0 ]
