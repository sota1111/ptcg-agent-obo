"""Kaggle Pokémon TCG AI Battle submission entrypoint (SOT-1930).

Current water ("水単") strategy — Mega Abomasnow ex, 60 cards in ``deck.csv``
(README §デッキ戦略). This is a self-contained, dependency-free realisation of
the README's Safety layer: it reads the engine's legal options
(``obs.select.option``) as the single source of truth and picks a legal action
with a greedy option-type priority, degrading to a raw-legal action on any
error. It never invents moves, never returns an illegal action, and never
raises out of ``agent()`` — the Validation Episode Error containment the README
requires.

Kaggle executes this file with ``exec()`` as raw Python, so ``__file__`` is not
defined and the process cwd is not guaranteed. The path handling and
``deck.csv`` lookup below therefore avoid both assumptions.
"""

import os
import sys

# Kaggle places the submission at /kaggle_simulations/agent and runs main.py
# with exec() (no __file__), so the submission dir may not lead sys.path.
# Prefer the bundled directory only under Kaggle exec so a normal import
# (tests, the JSONL runtime server) is never redirected to a stale checkout.
_KAGGLE_AGENT_DIR = "/kaggle_simulations/agent"
_EXECUTED_BY_KAGGLE = "__file__" not in globals()
_SUBMISSION_DIR = (
    _KAGGLE_AGENT_DIR
    if _EXECUTED_BY_KAGGLE and os.path.isdir(_KAGGLE_AGENT_DIR)
    else os.path.abspath(os.getcwd())
)
if _SUBMISSION_DIR and (not sys.path or sys.path[0] != _SUBMISSION_DIR):
    sys.path.insert(0, _SUBMISSION_DIR)


# --- OptionType (cg/api.py:120-187), as plain ints ---
_OT_NUMBER = 0
_OT_YES = 1
_OT_NO = 2
_OT_CARD = 3
_OT_TOOL_CARD = 4
_OT_ENERGY_CARD = 5
_OT_ENERGY = 6
_OT_PLAY = 7
_OT_ATTACH = 8
_OT_EVOLVE = 9
_OT_ABILITY = 10
_OT_DISCARD = 11
_OT_RETREAT = 12
_OT_ATTACK = 13
_OT_END = 14
_OT_SKILL = 15
_OT_SPECIAL_CONDITION = 16

# --- AreaType (cg/api.py:11-23) ---
_AREA_ACTIVE = 4
_AREA_BENCH = 5

# --- SelectContext (cg/api.py:68-118) grouped by selection intent ---
# "Cost" contexts: we are paying our own resources -> select as few as allowed.
_COST_CONTEXTS = frozenset({8, 9, 10, 11, 23, 26, 27, 29, 30, 31, 32})
# Contexts targeting a Pokémon to damage/weaken -> prefer the closest to a KO.
_DAMAGE_TARGET_CONTEXTS = frozenset({13, 14, 15, 20, 36})
# Contexts targeting one of our Pokémon to heal -> prefer the most damaged.
_HEAL_TARGET_CONTEXTS = frozenset({16, 17})
# COUNT contexts where a larger number is beneficial (cg/api.py:107-109).
_COUNT_MAX_CONTEXTS = frozenset({38, 39, 40})
# YES/NO decisions where YES is beneficial; unknown context -> NO.
_YES_CONTEXTS = frozenset({41, 42, 43, 44, 46})
# Special-condition severity (SpecialConditionType cg/api.py:48-53).
_SPECIAL_CONDITION_SEVERITY = {3: 5, 2: 4, 4: 3, 0: 2, 1: 1}


def _is_known_context(context):
    return isinstance(context, int) and 0 <= context <= 48


def _pokemon_at(current, player_index, area, index):
    """Resolve an (area, index) option reference to a Pokémon dict in play."""
    try:
        players = current.get("players") or ()
        side = players[player_index] if 0 <= player_index < len(players) else {}
        pokemons = side.get("active") if area == _AREA_ACTIVE else (
            side.get("bench") if area == _AREA_BENCH else None)
        if not pokemons or index is None or not (0 <= index < len(pokemons)):
            return None
        p = pokemons[index]
        return p if isinstance(p, dict) else None
    except Exception:
        return None


def _card_target_score(current, context, opt):
    """Score a CARD-target option using only board HP (no card data needed)."""
    area = opt.get("area")
    index = opt.get("index")
    player_index = opt.get("playerIndex", 0)
    pokemon = _pokemon_at(current, player_index, area, index)
    if context in _DAMAGE_TARGET_CONTEXTS:
        if pokemon is None:
            return 50.0
        return 200.0 - float(pokemon.get("hp", 0) or 0)  # closest to KO first
    if context in _HEAL_TARGET_CONTEXTS:
        if pokemon is None:
            return 0.0
        return float((pokemon.get("maxHp", 0) or 0) - (pokemon.get("hp", 0) or 0))
    # Neutral / cost target: prefer fewer, so keep it low.
    return -1.0 if context in _COST_CONTEXTS else 1.0


def _score_option(current, select, opt):
    """Greedy option-type priority (mirrors the README Safety layer ladder).

    Development (ability/evolve/play/attach) ranks above attacking because an
    attack ends the turn; retreat and end rank lowest. Card-value tie-breaks
    from the full agent are dropped here (this repo ships no card data), so the
    ordering degrades to the robust type-level priority.
    """
    t = opt.get("type", -1)
    context = select.get("context", -1)
    if t == _OT_EVOLVE:
        return 70.0
    if t == _OT_ABILITY:
        return 60.0
    if t == _OT_ATTACH:
        return 55.0 if opt.get("inPlayArea") == _AREA_ACTIVE else 45.0
    if t == _OT_PLAY:
        return 40.0
    if t == _OT_ATTACK:
        return 20.0
    if t == _OT_SKILL:
        return 10.0
    if t == _OT_SPECIAL_CONDITION:
        return float(_SPECIAL_CONDITION_SEVERITY.get(
            opt.get("specialConditionType"), 0))
    if t == _OT_RETREAT:
        return 4.0
    if t == _OT_END:
        return 0.0
    if t == _OT_YES:
        return 1.0 if context in _YES_CONTEXTS else -1.0
    if t == _OT_NO:
        return -1.0 if context in _YES_CONTEXTS else 1.0
    if t == _OT_NUMBER:
        number = opt.get("number") or 0
        return float(number if context in _COUNT_MAX_CONTEXTS else -number)
    if t == _OT_CARD:
        return _card_target_score(current, context, opt)
    if t in (_OT_TOOL_CARD, _OT_ENERGY_CARD, _OT_ENERGY):
        value = float(opt.get("count") or 1)
        return -value if context in _COST_CONTEXTS else value
    return 10.0  # unknown option type: between END and real development actions


def _count_bounds(select, n):
    hi = min(max(int(select.get("maxCount", 0) or 0), 0), n)
    lo = min(max(int(select.get("minCount", 0) or 0), 0), hi)
    return lo, hi


def _choose(current, select):
    """Pick a legal list of option indices for one decision."""
    options = select.get("option") or []
    n = len(options)
    lo, hi = _count_bounds(select, n)
    if hi == 0:
        return []
    context = select.get("context", -1)
    scores = [_score_option(current, select, o if isinstance(o, dict) else {})
              for o in options]
    if lo == hi:
        k = lo
    elif context in _COST_CONTEXTS:
        k = lo
    elif context in _COUNT_MAX_CONTEXTS or _is_known_context(context):
        k = hi
    else:
        k = lo
    k = max(k, 1)  # a decision always commits to at least one option
    k = min(k, hi)
    ranked = sorted(range(n), key=lambda i: (-scores[i], i))
    return sorted(ranked[:k])


def _last_resort(select):
    """Legal action from the raw select dict alone (no scoring in the path)."""
    options = select.get("option") or []
    n = len(options)
    lo, _ = _count_bounds(select, n)
    lo = max(lo, 1) if n else 0
    return list(range(min(lo, n)))


def read_deck_csv():
    """Read the 60-card deck as a list of card IDs (one per line)."""
    file_path = "deck.csv"
    if not os.path.exists(file_path):
        file_path = os.path.join(_KAGGLE_AGENT_DIR, "deck.csv")
    with open(file_path, "r", encoding="utf-8") as handle:
        rows = handle.read().splitlines()
    return [int(rows[i]) for i in range(60)]


_deck = None


def agent(obs_dict):
    """Pokémon TCG AI Battle agent — current 水単 strategy (SOT-1930).

    Returns a list of option indices, each ``>= 0`` and ``< len(select.option)``,
    of length in ``[select.minCount, select.maxCount]`` with no duplicates. On
    the initial call ``select`` is ``None`` and the 60-card deck is returned.
    """
    global _deck
    if _deck is None:
        _deck = read_deck_csv()
    obs = obs_dict if isinstance(obs_dict, dict) else {}
    select = obs.get("select")
    if not isinstance(select, dict):
        return list(_deck)  # initial deck selection
    current = obs.get("current")
    current = current if isinstance(current, dict) else {}
    try:
        return _choose(current, select)
    except Exception:
        try:
            return _last_resort(select)
        except Exception:
            return [0]
