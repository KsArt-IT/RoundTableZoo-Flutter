#!/usr/bin/env python3
"""Канбан-доска RoundTableZoo из чекбоксов specs/*/tasks.md.

Единственный источник правды — сами tasks.md. Скрипт ничего не пишет в них
и ничего не дублирует: он только читает состояние чекбоксов и рисует доску.

Состояния чекбокса:
    [ ]  → Бэклог
    [~]  → В работе (spec-kit уже использует этот знак для «сделано частично»)
    [x]  → Готово

Запуск из корня репозитория:
    python3 tools/kanban.py                    # → project/kanban.html
    python3 tools/kanban.py --open             # ещё и откроет в браузере
    python3 tools/kanban.py --out путь.html
    python3 tools/kanban.py --fragment         # без обвязки <html>, для публикации
"""

from __future__ import annotations

import argparse
import html
import re
import subprocess
import sys
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path

TASK_RE = re.compile(r"^- \[([ xX~\-])\]\s+(T\d+)\s*(.*)$")
MARKER_RE = re.compile(r"^(?:\[(P)\]\s*|\[(US\d+)\]\s*)+")
PHASE_RE = re.compile(r"^##\s+(.*)$")
TITLE_RE = re.compile(r"^#\s+Tasks:\s*(.*)$")

BACKLOG, WIP, DONE = "backlog", "wip", "done"
STATE_BY_MARK = {" ": BACKLOG, "~": WIP, "-": WIP, "x": DONE, "X": DONE}

# Цвета дорожек взяты из палитры персонажей приложения
# (app/assets/characters/characters.json) и продолжены в том же ключе.
LANE_COLORS = ["#8A7CA8", "#D98C4A", "#5C8A5C", "#6E8FAE", "#B0685F", "#7C8AA8"]


@dataclass
class Task:
    tid: str
    text: str
    state: str
    phase: str
    story: str | None
    parallel: bool
    feature: "Feature" = field(repr=False, default=None)  # type: ignore[assignment]


@dataclass
class Feature:
    slug: str
    number: str
    title: str
    color: str
    tasks: list[Task] = field(default_factory=list)

    def count(self, state: str) -> int:
        return sum(1 for t in self.tasks if t.state == state)

    @property
    def percent(self) -> int:
        return round(100 * self.count(DONE) / len(self.tasks)) if self.tasks else 0


def parse_tasks_file(path: Path, color: str) -> Feature:
    slug = path.parent.name
    number = slug.split("-", 1)[0]
    title = slug
    lines = path.read_text(encoding="utf-8").splitlines()

    for line in lines:
        m = TITLE_RE.match(line)
        if m:
            title = m.group(1).strip()
            break

    feature = Feature(slug=slug, number=number, title=title, color=color)
    phase = ""
    current: Task | None = None

    for line in lines:
        phase_m = PHASE_RE.match(line)
        if phase_m:
            phase = re.sub(r"[⚠️🎯]", "", phase_m.group(1)).strip()
            current = None
            continue

        task_m = TASK_RE.match(line)
        if task_m:
            mark, tid, rest = task_m.groups()
            parallel = False
            story = None
            marker = MARKER_RE.match(rest)
            if marker:
                head = rest[: marker.end()]
                parallel = "[P]" in head
                story_m = re.search(r"\[(US\d+)\]", head)
                story = story_m.group(1) if story_m else None
                rest = rest[marker.end():]
            current = Task(
                tid=tid,
                text=rest.strip(),
                state=STATE_BY_MARK[mark],
                phase=phase,
                story=story,
                parallel=parallel,
                feature=feature,
            )
            feature.tasks.append(current)
            continue

        # Продолжение многострочного описания задачи.
        if current is not None and line.startswith(("  ", "\t")) and line.strip():
            current.text += " " + line.strip()
        elif not line.strip():
            current = None

    return feature


def load_features(specs_dir: Path) -> list[Feature]:
    files = sorted(specs_dir.glob("*/tasks.md"))
    if not files:
        sys.exit(f"Не нашёл ни одного tasks.md в {specs_dir}")
    return [
        parse_tasks_file(p, LANE_COLORS[i % len(LANE_COLORS)])
        for i, p in enumerate(files)
    ]


def git_branch(repo: Path) -> str:
    try:
        out = subprocess.run(
            ["git", "--no-optional-locks", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=repo, capture_output=True, text=True, timeout=5,
        )
        return out.stdout.strip() or "—"
    except Exception:
        return "—"


# ─────────────────────────────── разметка ───────────────────────────────

def esc(s: str) -> str:
    return html.escape(s, quote=True)


LINK_RE = re.compile(r"\[([^\]]+)\]\((?!http)[^)]*\)")
URL_RE = re.compile(r"\[([^\]]+)\]\((https?://[^)]+)\)")
BOLD_RE = re.compile(r"\*\*(.+?)\*\*")
CODE_RE = re.compile(r"`([^`]+)`")


def clean(text: str) -> str:
    """Убирает markdown-шум, который в карточке только мешает читать."""
    text = URL_RE.sub(r"\1", text)          # ссылки наружу → просто подпись
    text = LINK_RE.sub(r"\1", text)         # ссылки на соседние файлы → подпись
    return re.sub(r"\s+", " ", text).strip()


def inline(text: str) -> str:
    """Экранирует и возвращает оставшийся markdown как разметку."""
    out = esc(text)
    out = BOLD_RE.sub(r"<strong>\1</strong>", out)
    out = CODE_RE.sub(r"<code>\1</code>", out)
    return out


def shorten(text: str, limit: int = 260) -> tuple[str, str | None]:
    """Возвращает (видимая часть, остаток или None)."""
    text = clean(text)
    if len(text) <= limit:
        return text, None
    cut = text.rfind(" ", 0, limit)
    cut = cut if cut > limit * 0.6 else limit
    return text[:cut].rstrip(" ,;—-"), text[cut:].strip()


def card(task: Task) -> str:
    head, tail = shorten(task.text)
    body = f'<p class="card__text">{inline(head)}'
    if tail:
        body += f'<span class="card__more"> {inline(tail)}</span>'
        body += '<button class="card__toggle" type="button">…показать целиком</button>'
    body += "</p>"

    chips = [f'<span class="chip chip--lane">{esc(task.feature.number)}</span>']
    if task.story:
        chips.append(f'<span class="chip">{esc(task.story)}</span>')
    if task.parallel:
        chips.append('<span class="chip" title="можно делать параллельно">∥</span>')

    return (
        f'<article class="card" data-feature="{esc(task.feature.slug)}"'
        f' style="--lane:{task.feature.color}">'
        f'<header class="card__head"><span class="card__id">{esc(task.tid)}</span>'
        f'<span class="card__chips">{"".join(chips)}</span></header>'
        f"{body}"
        f'<footer class="card__phase">{esc(task.phase)}</footer>'
        "</article>"
    )


def done_group(feature: Feature) -> str:
    done = [t for t in feature.tasks if t.state == DONE]
    if not done:
        return ""
    items = "".join(
        f'<li><span class="done__id">{esc(t.tid)}</span>'
        f'<span class="done__text">{inline(shorten(t.text, 150)[0])}</span></li>'
        for t in done
    )
    return (
        f'<details class="done" data-feature="{esc(feature.slug)}"'
        f' style="--lane:{feature.color}">'
        f'<summary class="done__summary">'
        f'<span class="done__num">{esc(feature.number)}</span>'
        f'<span class="done__title">{esc(feature.title)}</span>'
        f'<span class="done__count">{len(done)}</span></summary>'
        f'<ul class="done__list">{items}</ul>'
        "</details>"
    )


def meter(feature: Feature) -> str:
    b, w, d = feature.count(BACKLOG), feature.count(WIP), feature.count(DONE)
    total = len(feature.tasks)
    seg = lambda n, cls: (
        f'<span class="bar__seg bar__seg--{cls}" style="flex:{n}"></span>' if n else ""
    )
    return (
        f'<button class="lane" type="button" data-feature="{esc(feature.slug)}"'
        f' style="--lane:{feature.color}">'
        f'<span class="lane__head"><span class="lane__num">{esc(feature.number)}</span>'
        f'<span class="lane__title">{esc(feature.title)}</span>'
        f'<span class="lane__pct">{feature.percent}%</span></span>'
        f'<span class="bar">{seg(d, "done")}{seg(w, "wip")}{seg(b, "backlog")}</span>'
        f'<span class="lane__foot">{d} из {total} · '
        f'осталось {w + b}</span>'
        "</button>"
    )


CSS = """
:root{
  --ground:#F6F4F8; --panel:#FFFFFF; --panel-2:#F0EDF3;
  --ink:#211E28; --ink-2:#5B5568; --ink-3:#8B8497;
  --line:#E2DCE8; --line-2:#CFC7D8;
  --done:#4E7C52; --wip:#C67B33; --backlog:#6E8FAE;
  --done-bg:#E8F0E7; --wip-bg:#FAEEDF; --backlog-bg:#E9EFF5;
  --shadow:0 1px 2px rgba(33,30,40,.05), 0 8px 24px -16px rgba(33,30,40,.35);
  --radius:10px;
}
@media (prefers-color-scheme: dark){
  :root:not([data-theme="light"]){
    --ground:#15131A; --panel:#1E1B24; --panel-2:#26222E;
    --ink:#EEEAF2; --ink-2:#A9A2B6; --ink-3:#7C748B;
    --line:#302B39; --line-2:#3E3849;
    --done:#8DBE8F; --wip:#E5A75E; --backlog:#93B4D0;
    --done-bg:#253025; --wip-bg:#332A20; --backlog-bg:#232C34;
    --shadow:0 1px 2px rgba(0,0,0,.4), 0 8px 24px -16px rgba(0,0,0,.8);
  }
}
:root[data-theme="dark"]{
  --ground:#15131A; --panel:#1E1B24; --panel-2:#26222E;
  --ink:#EEEAF2; --ink-2:#A9A2B6; --ink-3:#7C748B;
  --line:#302B39; --line-2:#3E3849;
  --done:#8DBE8F; --wip:#E5A75E; --backlog:#93B4D0;
  --done-bg:#253025; --wip-bg:#332A20; --backlog-bg:#232C34;
  --shadow:0 1px 2px rgba(0,0,0,.4), 0 8px 24px -16px rgba(0,0,0,.8);
}

*{box-sizing:border-box}
body{
  margin:0; background:var(--ground); color:var(--ink);
  font-family:"IBM Plex Sans","Helvetica Neue",Arial,sans-serif;
  font-size:15px; line-height:1.5;
  -webkit-font-smoothing:antialiased;
}
.wrap{max-width:1280px; margin:0 auto; padding:32px 20px 72px}

/* ── шапка ───────────────────────────────────────────── */
.top{display:flex; flex-wrap:wrap; align-items:flex-end; gap:20px 32px; margin-bottom:28px}
h1{
  font-family:"Bricolage Grotesque","IBM Plex Sans",sans-serif;
  font-weight:700; font-size:clamp(26px,4vw,38px); letter-spacing:-.02em;
  margin:0; text-wrap:balance;
}
.top__sub{margin:6px 0 0; color:var(--ink-2); font-size:14px}
.total{margin-left:auto; text-align:right}
.total__num{
  font-family:"Bricolage Grotesque",sans-serif; font-weight:700;
  font-size:clamp(34px,6vw,52px); line-height:1; letter-spacing:-.03em;
  font-variant-numeric:tabular-nums;
}
.total__num span{font-size:.5em; color:var(--ink-3); font-weight:600}
.total__cap{font-size:12px; letter-spacing:.1em; text-transform:uppercase; color:var(--ink-3); margin-top:6px}

/* ── дорожки-прогресс ────────────────────────────────── */
.lanes{
  display:grid; gap:10px; margin-bottom:28px;
  grid-template-columns:repeat(auto-fill,minmax(230px,1fr));
}
.lane{
  display:flex; flex-direction:column; gap:8px; text-align:left; cursor:pointer;
  background:var(--panel); border:1px solid var(--line); border-left:3px solid var(--lane);
  border-radius:var(--radius); padding:12px 14px; font:inherit; color:inherit;
  transition:border-color .15s, transform .15s;
}
.lane:hover{border-color:var(--line-2)}
.lane[aria-pressed="true"]{outline:2px solid var(--lane); outline-offset:-1px}
.lane__head{display:flex; align-items:baseline; gap:8px}
.lane__num{
  font-family:"IBM Plex Mono",ui-monospace,monospace; font-size:12px;
  color:var(--lane); font-weight:600;
}
.lane__title{
  flex:1; font-weight:600; font-size:14px; line-height:1.3;
  display:-webkit-box; -webkit-line-clamp:2; -webkit-box-orient:vertical; overflow:hidden;
}
.lane__pct{font-variant-numeric:tabular-nums; font-size:13px; color:var(--ink-2); font-weight:600}
.lane__foot{font-size:12px; color:var(--ink-3); font-variant-numeric:tabular-nums}
.bar{display:flex; height:6px; border-radius:99px; overflow:hidden; background:var(--panel-2)}
.bar__seg--done{background:var(--done)}
.bar__seg--wip{background:var(--wip)}
.bar__seg--backlog{background:var(--line-2)}

/* ── доска ───────────────────────────────────────────── */
.board{display:grid; gap:16px; grid-template-columns:repeat(3,1fr); align-items:start}
@media (max-width:900px){ .board{grid-template-columns:1fr} }
.col{background:var(--panel-2); border:1px solid var(--line); border-radius:14px; padding:12px}
.col__head{display:flex; align-items:center; gap:8px; padding:2px 4px 12px}
.col__dot{width:8px; height:8px; border-radius:99px; background:var(--c)}
.col__name{
  font-family:"Bricolage Grotesque",sans-serif; font-weight:600; font-size:14px;
  letter-spacing:.02em;
}
.col__count{
  margin-left:auto; font-variant-numeric:tabular-nums; font-size:12px; font-weight:600;
  color:var(--c); background:var(--cbg); border-radius:99px; padding:2px 9px;
}
.col--backlog{--c:var(--backlog); --cbg:var(--backlog-bg)}
.col--wip{--c:var(--wip); --cbg:var(--wip-bg)}
.col--done{--c:var(--done); --cbg:var(--done-bg)}
.col__body{display:flex; flex-direction:column; gap:10px}

.card{
  background:var(--panel); border:1px solid var(--line); border-left:3px solid var(--lane);
  border-radius:var(--radius); padding:11px 13px; box-shadow:var(--shadow);
}
.card__head{display:flex; align-items:center; gap:8px; margin-bottom:6px}
.card__id{
  font-family:"IBM Plex Mono",ui-monospace,monospace; font-weight:600; font-size:12px;
  letter-spacing:.02em;
}
.card__chips{margin-left:auto; display:flex; gap:5px}
.chip{
  font-family:"IBM Plex Mono",ui-monospace,monospace; font-size:10px; font-weight:600;
  padding:1px 6px; border-radius:99px; background:var(--panel-2); color:var(--ink-3);
}
.chip--lane{background:color-mix(in srgb, var(--lane) 16%, transparent); color:var(--lane)}
.card__text{margin:0; font-size:13.5px; line-height:1.5; color:var(--ink-2)}
.card__text code,.done__text code{
  font-family:"IBM Plex Mono",ui-monospace,monospace; font-size:.88em;
  background:var(--panel-2); border-radius:4px; padding:0 4px; color:var(--ink-2);
}
.card__text strong{color:var(--ink); font-weight:600}
.card__more{display:none}
.card.is-open .card__more{display:inline}
.card.is-open .card__toggle{display:none}
.card__toggle{
  display:inline; background:none; border:0; padding:0 0 0 4px; cursor:pointer;
  font:inherit; font-size:12.5px; color:var(--backlog); text-decoration:underline;
}
.card__phase{
  margin-top:8px; font-size:11px; color:var(--ink-3);
  overflow:hidden; text-overflow:ellipsis; white-space:nowrap;
}

/* ── свёрнутая колонка «Готово» ──────────────────────── */
.done{
  background:var(--panel); border:1px solid var(--line); border-left:3px solid var(--lane);
  border-radius:var(--radius);
}
.done__summary{
  display:flex; align-items:center; gap:9px; padding:10px 13px; cursor:pointer;
  list-style:none; font-size:13.5px;
}
.done__summary::-webkit-details-marker{display:none}
.done__num{font-family:"IBM Plex Mono",monospace; font-size:12px; font-weight:600; color:var(--lane)}
.done__title{flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; color:var(--ink-2)}
.done__count{
  font-variant-numeric:tabular-nums; font-size:12px; font-weight:600;
  color:var(--done); background:var(--done-bg); border-radius:99px; padding:1px 8px;
}
.done__list{margin:0; padding:0 13px 12px; list-style:none; display:flex; flex-direction:column; gap:7px}
.done__list li{display:flex; gap:8px; font-size:12.5px; color:var(--ink-3); line-height:1.45}
.done__id{font-family:"IBM Plex Mono",monospace; font-weight:600; flex:none}
.done__text{overflow:hidden}

.empty{padding:14px 4px; font-size:13px; color:var(--ink-3)}
.foot{margin-top:32px; font-size:12px; color:var(--ink-3); line-height:1.7}
.foot code{
  font-family:"IBM Plex Mono",monospace; background:var(--panel-2);
  padding:1px 5px; border-radius:4px; font-size:11.5px;
}
.is-hidden{display:none !important}
:focus-visible{outline:2px solid var(--backlog); outline-offset:2px; border-radius:4px}
@media (prefers-reduced-motion:reduce){*{transition:none !important}}
"""

JS = """
document.addEventListener('click', function (e) {
  var more = e.target.closest('.card__toggle');
  if (more) { more.closest('.card').classList.add('is-open'); return; }

  var lane = e.target.closest('.lane');
  if (!lane) return;
  var slug = lane.dataset.feature;
  var on = lane.getAttribute('aria-pressed') !== 'true';
  document.querySelectorAll('.lane').forEach(function (l) {
    l.setAttribute('aria-pressed', l === lane && on ? 'true' : 'false');
  });
  document.querySelectorAll('[data-feature].card, [data-feature].done').forEach(function (n) {
    n.classList.toggle('is-hidden', on && n.dataset.feature !== slug);
  });
  document.querySelectorAll('.col').forEach(function (col) {
    var vis = col.querySelectorAll('.card:not(.is-hidden), .done:not(.is-hidden)').length;
    var badge = col.querySelector('.col__count');
    if (badge) badge.textContent = badge.dataset.exact
      ? (on ? countTasks(col) : badge.dataset.exact) : vis;
  });
});
function countTasks(col) {
  var n = 0;
  col.querySelectorAll('.done:not(.is-hidden) .done__count').forEach(function (c) {
    n += parseInt(c.textContent, 10) || 0;
  });
  return n || col.querySelectorAll('.card:not(.is-hidden)').length;
}
"""


def build(features: list[Feature], branch: str, fragment: bool) -> str:
    all_tasks = [t for f in features for t in f.tasks]
    total = len(all_tasks)
    n = {s: sum(1 for t in all_tasks if t.state == s) for s in (BACKLOG, WIP, DONE)}
    pct = round(100 * n[DONE] / total) if total else 0

    def column(title: str, cls: str, count: int, body: str, exact: str = "") -> str:
        badge = f' data-exact="{exact}"' if exact else ""
        inner = body or '<p class="empty">Пусто — и это хорошая новость.</p>'
        return (
            f'<section class="col col--{cls}">'
            f'<header class="col__head"><span class="col__dot"></span>'
            f'<h2 class="col__name">{esc(title)}</h2>'
            f'<span class="col__count"{badge}>{count}</span></header>'
            f'<div class="col__body">{inner}</div></section>'
        )

    backlog = "".join(card(t) for t in all_tasks if t.state == BACKLOG)
    wip = "".join(card(t) for t in all_tasks if t.state == WIP)
    done = "".join(done_group(f) for f in features)

    body = f"""
<div class="wrap">
  <div class="top">
    <div>
      <h1>RoundTableZoo — доска задач</h1>
      <p class="top__sub">Собрана из чекбоксов <code>specs/*/tasks.md</code> ·
        ветка <strong>{esc(branch)}</strong> ·
        {datetime.now().strftime('%d.%m.%Y, %H:%M')}</p>
    </div>
    <div class="total">
      <div class="total__num">{pct}<span>%</span></div>
      <div class="total__cap">{n[DONE]} из {total} задач</div>
    </div>
  </div>

  <div class="lanes">{''.join(meter(f) for f in features)}</div>

  <div class="board">
    {column('Бэклог', 'backlog', n[BACKLOG], backlog)}
    {column('В работе', 'wip', n[WIP], wip)}
    {column('Готово', 'done', n[DONE], done, exact=str(n[DONE]))}
  </div>

  <p class="foot">
    Доска только читает файлы — статус меняется правкой чекбокса в <code>tasks.md</code>:
    <code>[ ]</code> бэклог · <code>[~]</code> в работе · <code>[x]</code> готово.<br>
    Клик по дорожке наверху фильтрует доску по спеке; повторный клик снимает фильтр.
    Пересобрать: <code>python3 tools/kanban.py</code>
  </p>
</div>
"""

    fonts = ('<link rel="preconnect" href="https://fonts.googleapis.com">'
             '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
             '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
             'family=Bricolage+Grotesque:opsz,wght@12..96,600;12..96,700&'
             'family=IBM+Plex+Mono:wght@500;600&'
             'family=IBM+Plex+Sans:wght@400;600&display=swap">')
    head = f'<title>RoundTableZoo — доска задач</title>{fonts}<style>{CSS}</style>'
    tail = f"<script>{JS}</script>"

    if fragment:
        return head + body + tail
    return (
        '<!doctype html>\n<html lang="ru">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"{head}\n</head>\n<body>{body}{tail}</body>\n</html>\n"
    )


def main() -> None:
    ap = argparse.ArgumentParser(description="Канбан-доска из specs/*/tasks.md")
    ap.add_argument("--repo", type=Path, default=Path.cwd(), help="корень репозитория")
    ap.add_argument("--out", type=Path, default=None, help="куда писать HTML")
    ap.add_argument("--fragment", action="store_true", help="без обвязки <html>")
    ap.add_argument("--open", action="store_true", help="открыть в браузере")
    args = ap.parse_args()

    repo = args.repo.resolve()
    specs = repo / "specs"
    if not specs.is_dir():
        sys.exit(f"Нет каталога {specs} — запусти из корня репозитория или укажи --repo")

    features = load_features(specs)
    out = args.out or repo / "project" / "kanban.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(build(features, git_branch(repo), args.fragment), encoding="utf-8")

    total = sum(len(f.tasks) for f in features)
    done = sum(f.count(DONE) for f in features)
    wip = sum(f.count(WIP) for f in features)
    print(f"{out}: {done} готово, {wip} в работе, {total - done - wip} в бэклоге "
          f"(всего {total} в {len(features)} спеках)")

    if args.open:
        import webbrowser
        webbrowser.open(out.as_uri())


if __name__ == "__main__":
    main()
