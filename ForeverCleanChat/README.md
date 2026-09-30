# Forever Clean Chat 1.0.0

Independent, offline local chat filter. Full Turkish installation, upgrade and
policy documentation: **README_TR.md**. Forever Mini Reminder is untouched.

Target `.toc` metadata remains **16001**. Live Forever integration has **not**
been validated; registration success is not proof of actual event support.

Install `ForeverCleanChat` under the correct client's `Interface/AddOns`.
Restart, enable the addon, then click the shield beside the minimap or run `/fcc`.
The English control panel has five sections:

- **Overview:** protection switch, session and lifetime totals, profile, pack and API status.
- **Hidden messages:** the last 50 hidden messages, rule details, search, player actions and log clearing.
- **Your lists:** manage custom domains, phrases, allowed/blocked players and domain exceptions.
- **Settings:** choose Balanced/Strict, domain policy, chat channels and minimap visibility.
- **Local test:** classify a sample and run built-in checks without sending chat or increasing counters.

Left-click the minimap shield to toggle the panel; right-click for Settings.
Drag the shield to move it. Drag the panel header to move the window. Positions
are saved; Escape closes the panel. `/fcc minimap reset` restores a hidden icon.
Run `/fcc test`, `/fcc status`, `/fcc pack` for text diagnostics.
New installs use **strict**; existing enabled/mode/lists/counters are preserved.
The built-in pack and user domain additions, removals and exceptions are separate.
Invalid legacy compact keys are preserved for review, never invented as domains.

`balanced` targets known domains and strong commercial/RMT offers. `strict`
also hides sold boost/carry, gold and account offers. Both default to
`hide_all`: a known domain in a guide or warning may also be hidden.
`/fcc domainpolicy contextual` requires related positive commercial context.

Existing text commands remain; `/fcc` now opens the panel. Common commands:

```text
/fcc why <local sample>
/fcc pack
/fcc domainpolicy hide_all
/fcc domainpolicy contextual
/fcc domain allow example.com
/fcc domain unallow example.com
/fcc settings
/fcc close
/fcc minimap show
/fcc minimap hide
/fcc minimap reset
```

Local samples send no chat and change no counters. Domain exceptions skip only
domain-derived rules; independent cash/service rules can still hide a message.
Use `/fcc log`, `/fcc list` and player allow/block commands for local control.

Data source: `research/forever-clean-chat-research.json`, compiled deterministically
by stdlib Python into inert `Data.generated.lua`. JSON is not loaded by the game;
there is no eval, network, remote update, report, ignore or reply automation.
Pack 2026-09-30.1 contains 37 active indicators and 26 lexicon families.
Quarantine, sources, campaigns and fixtures stay outside the runtime table.
The screenshot domain and the similarly named hyphenated website remain distinct
indicators with no ownership inference.

UTF-8/markup/host parsing and semantic offer rules use bounded streams. Host
structure, digits, hyphens, URL path/query/userinfo boundaries and item-link
labels are preserved. Finite domain transformations are not full Unicode/IDNA
support. Invalid, unreadable, oversized or over-budget inputs fail open.
Ordinary item/crafting/group/buyer/free-help contexts receive local protection;
false positives and evasion remain possible.

Only channel/say/yell/incoming character whisper/player emote standard chat
filters are registered. Each can be turned off in Settings. Bubbles, old history, mail, invitations, group finder,
guild/party/raid/system/BN and custom third-party panels are outside this scope.
Caches and dedupe buffers are bounded at 256, session log at 50. No polling.
Settings and UI preferences persist account-wide; raw session logs do not.
Clearing the session log leaves session/lifetime counters unchanged.

Development:

```text
python tools/build_rule_data.py --check
python tools/test_build_rule_data.py
python tests/run_all.py
```

Tests run the actual addon under Lua 5.1 and Lua 5.3 via the installed `lupa`
backends, with mocked game APIs. The runner fails if a runtime is unavailable.
Separate executed results: `TEST_REPORT.txt`, `tests/results/latest.md` and
`latest.json`. Changed v0.1.0 expectations are explained in `tests/README.md`.
Descriptions of fixtures are not pass results. Actual target-client API layout,
secure data semantics, addon interaction, rendering and FPS/memory remain unverified.
