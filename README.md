# Forever Clean Chat

Version **1.0.0**. An independent World of Warcraft / Forever addon that filters
commercial chat spam locally using an offline rule pack.

The English control panel includes a minimap button, hidden-message log,
personal lists, settings and local message testing. Open it with `/fcc`.

## Installation

Copy the `ForeverCleanChat` folder into your client's `Interface/AddOns`
directory, restart the game and enable the addon. The resulting path should be
`Interface/AddOns/ForeverCleanChat/ForeverCleanChat.toc`.

Existing user settings are preserved. Forever Mini Reminder is independent of
this addon and is not required.

## Documentation and development

- [English addon guide](ForeverCleanChat/README.md)
- [Türkçe kullanım rehberi](ForeverCleanChat/README_TR.md)
- [Changelog](ForeverCleanChat/CHANGELOG.md)
- [Executed test results](ForeverCleanChat/tests/results/latest.md)
- [Testing guide](ForeverCleanChat/tests/README.md)

Run the actual Lua 5.1 and Lua 5.3 checks using Python with the `lupa` package:

```sh
python ForeverCleanChat/tests/run_all.py
```

The tests exercise addon code with mocked game APIs. Actual target-client
rendering and live Forever integration remain unverified.
