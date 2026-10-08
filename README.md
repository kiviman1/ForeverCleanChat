# Forever Clean Chat

Version **1.1.2**. An independent World of Warcraft / Forever addon that filters
commercial chat spam locally using an offline rule pack.

The English control panel uses a dark textured fantasy theme with an ornate
gold frame and a chat-shield emblem. Its home screen contains the protection
switch, Balanced/Strict mode, the real session counter and links to hidden
messages and Advanced settings. Open it with `/fcc`.

Advanced settings contains the hidden-message log, personal lists, filtering
preferences and local message testing.

The panel is 28% smaller, with captions fitted to their controls, a scrollable
local-test input, a graphical X close button and a clean save-feedback footer.
The protection light is now a padlock: enabling fades in the open lock, closes
the shackle and briefly flashes green; disabling opens it and fades it out.

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
