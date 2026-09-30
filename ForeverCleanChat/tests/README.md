# Executed Lua regression and research tests

Run `python tests/run_all.py` from the addon directory (or pass its full path from another directory). The runner requires `lupa.lua51` and `lupa.lua53`; it fails if either actual runtime is unavailable. `python tests/run_all.py --suite research`, `--suite adversarial`, or `--suite ui` can select an individual suite. Results are written separately for regression, pure classifier, mock adapter, engineering acceptance contracts, independent adversarial checks, and UI interactions in `tests/results/latest.json` and `tests/results/latest.md`.

The original v0.1.0 suite was executed before editing: 194/194 assertions passed in **both Lua 5.1 and Lua 5.3** through installed `C:\Python314\python.exe`. The updated regression suite keeps the original scenarios and uses an explicit balanced profile. Fixture statuses in the source JSON do not supply results; every one of the 595 classification fixtures executes in each profile through the actual addon classifier and callback. Python only loads Lua and records results; it does not implement a regex or Unicode classifier oracle.

## Explicit changes to v0.1.0 expectations

- Clean installations now use strict. The old regression scenarios explicitly select balanced, preserving their intended profile.
- Bare `m.y.t.h.i.c.s.t.o.r.e.c.o.m` and `M-Y-T-H-I-C-S-T-O-R-E COM` allow: structural dots and hyphens are preserved, and arbitrary text is not compacted into a host.
- Bare `Myth1cSt0re.c0m`, `mythic5tore.com`, and `mythicstor3.com` allow. Leet substitutions require commercial context, affect only a canonical host label, and never rewrite a TLD.
- Balanced R025/R027 require a defined promotion family alongside the other commercial evidence. The old samples `Book a dungeon carry at example.gg`, `Buy professions at example.net`, and `We cover your leveling, dungeons and gearing. Order now.` therefore now allow. These are explicit differences from the old broad rules, reviewed against the supplied rule AST; none is silently removed from the regression suite.
- `mythic\nstore.com` allows; separate words across a line break do not create a host.
- `Normalize.Domain('HTTPS://WWW.Example.COM/path')` returns structural key `example.com`, replacing legacy compact `examplecom`. Reload checks use dotted keys.
- An unreadable/secret author fails open before sender exceptions, cache-key creation, or logging.
- A readable sender GUID that differs from the player's GUID prevents a name-only self exemption.

No original scenario is silently removed. Additional collision tests independently verify that `a-b.com`, `ab.com`, and `a.b.com` survive additions/removals separately; domain boundaries, URL userinfo/path isolation and the Copper Bar false-positive regression are also exercised.

## Independent adversarial suite

`run_adversarial.lua` contains 38 additional audit reproductions, each executed through the classifier and callback in both profiles. They cover local buyer/free/payment guards, the distinction between gold as a service price and a commodity, bounded real-money/rate parsing, weak leet evidence limited to its own offer segment, unrelated guide sentences, and the declared brand-offers-object template. These cases are independent additions; the original JSON fixtures are unchanged.

Separate engineering groups verify local `why`/`pack` counters, domain-only exceptions, modern registry throw/false/partial fallback to legacy without duplicate registrations, schema 2 migration backups/exclusions/review records after reload, structural Unicode offsets and URL boundaries, and generated work/leet controls. Their results and elapsed times are reported separately. Any failed adversarial check or extra engineering group makes the Python runner exit with failure.

## Control panel and minimap interaction suite

`run_ui.lua` loads all production modules in their TOC order, including `Settings.lua`, `UI.lua`, and `Minimap.lua`. `harness_ui.lua` supplies explicit, stateful native-frame doubles for visibility, text, scripts, event delivery, edit input, click handlers, window points, native drag state, tooltip lines and scroll positions. The suite executes actual addon callbacks; it does not provide another UI or classifier implementation as its expected result. Invalid or missing handlers and clicks on invisible controls fail the harness.

The 616 interaction assertions per Lua runtime cover slash and minimap access, all five tabs, overview controls and shortcuts, close/Escape including focused edits, profile and policy changes, every supported chat scope toggle, validated list editing, structural host collisions, built-in overrides, player conflict resolution, list search/paging/selection, bounded hidden-message logs and their actions, log search, scroll arrows and mouse-wheel limits for long messages, local tests without outgoing chat or counter changes, saved preferences and window positions after reload, minimap drag quadrants and scaled cursor coordinates, square minimap geometry and mask fallback, tooltip behavior, and disabled optional APIs. A full personal domain list cannot prevent re-enabling a built-in domain. Lifetime counters at their valid maximum survive another blocked message and reload. Native children have nonnegative dimensions and the panel scales to a smaller viewport.

UI creation and listener failures are exercised separately from chat classification: they cannot disable valid filtering or hide ordinary chat. No module installs idle `OnUpdate` polling. The earlier regression/research harness intentionally keeps its small original API surface and only adds `Settings.lua` before `Commands.lua`; this preserves the independent classifier and adapter tests.

These are **mock interaction passes**. No test renders WoW fonts or textures, captures a native game screenshot, launches the target Forever client, or sends a message to a live chat channel. Browser illustrations or static previews are not evidence of native layout compatibility. Check the actual control panel, minimap icon, event callback layout and saved preferences in the target client before treating native UI compatibility as verified.

## Engineering contracts and scope

Each of the 26 source contracts receives a separate reported status. Mock API, cache, normalization, identity and migration behaviors are actual Lua assertions. Compilation determinism and compiler validation use the offline build tool. Regression and Lua fixture parity receive their own executed evidence.

The target Forever client is unavailable to this harness. The live-scope contract stays **pending_live_client**. Chat bubbles, mailbox, group finder and external custom chat panels are outside this addon's verified scope; **documented_scope_limit** is not a passed runtime integration test. Real API availability, callback vararg layout and event dispatch still require a local client check. No test sends spam or any other chat message to a real channel.
