# ForeverCleanChat executed test report

Generated UTC: 2026-10-08T22:58:33.461806+00:00

Python: `C:\Python314\python.exe` (3.14.4)

The original unmodified v0.1.0 suite was actually run before this change: **194/194 on Lua 5.1 and 194/194 on Lua 5.3**. The adapted regression and new research checks are reported separately below.

| Runtime | Adapted v0.1.0 regression | JSON classifier/profile checks | Mock adapter/profile checks |
|---|---:|---:|---:|
| lupa.lua51 / Lua 5.1 | 194/194 | 1190/1190 | 1190/1190 |
| lupa.lua53 / Lua 5.3 | 194/194 | 1190/1190 | 1190/1190 |

595 JSON classification cases each run in two profiles: 1190 classifier evaluations per runtime, plus 1190 callback evaluations. Fixtures are specifications, not previous pass results.

## Engineering acceptance contracts

| Contract | Lua 5.1 | Lua 5.3 |
|---|---|---|
| contract_api_namespace | passed_mock | passed_mock |
| contract_api_legacy | passed_mock | passed_mock |
| contract_api_missing | passed_mock | passed_mock |
| contract_api_signature | passed_mock | passed_mock |
| contract_api_secret | passed_mock | passed_mock |
| contract_api_bad_type | passed_mock | passed_mock |
| contract_api_invalid_utf8 | passed_mock | passed_mock |
| contract_api_arg_layout | passed_mock | passed_mock |
| contract_multi_frames | passed_mock | passed_mock |
| contract_dedupe_fallback | passed_mock | passed_mock |
| contract_cache_config | passed_mock | passed_mock |
| contract_cache_bound | passed_mock | passed_mock |
| contract_long_input | passed_mock | passed_mock |
| contract_normalization_work | passed_mock | passed_mock |
| contract_hidden_link_payload | passed_mock | passed_mock |
| contract_display_safe | passed_mock | passed_mock |
| contract_no_user_identity_inference | passed_mock | passed_mock |
| contract_no_network | passed_mock | passed_mock |
| contract_regression_existing | passed_lua | passed_lua |
| contract_migration_saved | passed_mock | passed_mock |
| contract_migration_missing | passed_mock | passed_mock |
| contract_migration_invalid | passed_mock | passed_mock |
| contract_compile_deterministic | passed_offline | passed_offline |
| contract_test_parity | passed_lua | passed_lua |
| contract_live_scope | pending_live_client | pending_live_client |
| contract_no_bubbles_claim | documented_scope_limit | documented_scope_limit |

`passed_mock` verifies only the isolated mock contract. `pending_live_client` and `documented_scope_limit` are not runtime compatibility passes.

## Compiler

Status: passed

- `Data.generated.lua`: `e6762438cf4ef60b4a084389532fa7aeb0c496f3b215d7f27b8e25448df7cebb`
- `tests/Fixtures.generated.lua`: `240f6e933d7f8df717fe5638735acc0a3412ab1457cb86306e1597092eaff476`

Compiler validation unit tests: 34 actually executed; exit code 0.

Two compilations must produce identical bytes and match committed generated files. Python does not normalize or classify fixture text; classification is the actual addon Lua implementation.

## Intentional regression expectation changes

- The v0.1.0 regression suite explicitly uses balanced; new installations default to strict.
- Bare character-per-dot/hyphen strings are allowed instead of globally compacted into a domain.
- Bare leet labels and leet TLDs are allowed without separate commercial context.
- Balanced R025/R027 require defined promotion evidence: Book a dungeon carry at example.gg, Buy professions at example.net, and We cover your leveling, dungeons and gearing. Order now. now allow.
- Newline-separated words are not glued into a domain.
- Canonical keys retain dots and hyphens: example.com replaces examplecom.
- Schema 2 user domains and built-in exclusions are separate layers.
- Unreadable author values fail open before identity, cache or logging.
- A conflicting sender GUID takes precedence over an exact self-name match.

## Independent adversarial regressions

These contract-derived audit cases are separate from the original 595 JSON fixtures. Source fixture expectations remain unchanged.

| Runtime | Cases | Classifier/profile checks | Mock callback/profile checks | Engineering assertions |
|---|---:|---:|---:|---:|
| Lua 5.1 | 41 | 82/82 | 82/82 | 111 |
| Lua 5.3 | 41 | 82/82 | 82/82 | 111 |

| Adversarial engineering group | Lua 5.1 | Lua 5.3 |
|---|---|---|
| local_why_pack_do_not_change_counters | passed_mock | passed_mock |
| domain_allow_keeps_independent_cash_rule | passed_mock | passed_mock |
| modern_throw_legacy_fallback | passed_mock | passed_mock |
| modern_false_legacy_fallback | passed_mock | passed_mock |
| modern_partial_legacy_fallback | passed_mock | passed_mock |
| false_registry_without_fallback_is_unsupported | passed_mock | passed_mock |
| schema2_reload_preserves_exclusions_backup_review | passed_mock | passed_mock |
| legacy_removed_builtin_survives_pack_reload | passed_mock | passed_mock |
| normalization_structural_offsets_and_scope | passed_mock | passed_mock |
| normalization_uses_generated_work_and_leet_limits | passed_mock | passed_mock |

## Control panel and minimap interactions

These checks execute the actual addon callbacks on stateful native-frame doubles. No browser drawing or live WoW screenshot is used as evidence of UI compatibility.

| Runtime | Interaction assertions | Native UI rendering | Target Forever client |
|---|---:|---|---|
| Lua 5.1 | 1466/1466 | not_run | not_run |
| Lua 5.3 | 1466/1466 | not_run | not_run |

| UI interaction group | Lua 5.1 | Lua 5.3 |
|---|---|---|
| startup_and_panel_navigation | passed_mock | passed_mock |
| minimap_click_tooltip_and_visibility | passed_mock | passed_mock |
| overview_controls_and_shortcuts | passed_mock | passed_mock |
| home_live_protection_state_and_count | passed_mock | passed_mock |
| padlock_on_off_stage_order_and_idle_cleanup | passed_mock | passed_mock |
| padlock_rapid_reversal_preserves_current_visual_state | passed_mock | passed_mock |
| padlock_hidden_tabs_slash_minimap_and_close_settle_state | passed_mock | passed_mock |
| padlock_finite_overshoot_idempotence_and_native_fallback | passed_mock | passed_mock |
| settings_immediately_change_filtering | passed_mock | passed_mock |
| lists_validate_edit_and_preserve_builtin_pack | passed_mock | passed_mock |
| lists_search_paging_and_row_selection | passed_mock | passed_mock |
| builtin_domain_toggle_works_with_full_personal_list | passed_mock | passed_mock |
| hidden_log_bounded_paging_selection_and_actions | passed_mock | passed_mock |
| maximum_lifetime_counter_remains_valid_after_reload | passed_mock | passed_mock |
| long_message_detail_native_scroll_handlers | passed_mock | passed_mock |
| local_test_tab_and_slash_never_send_or_count | passed_mock | passed_mock |
| window_and_preferences_survive_reload | passed_mock | passed_mock |
| minimap_native_drag_angles_and_scaled_geometry | passed_mock | passed_mock |
| settings_validation_caps_and_malformed_saved_ui | passed_mock | passed_mock |
| missing_optional_apis_and_ui_errors_do_not_disable_filter | passed_mock | passed_mock |
| native_regions_have_nonnegative_geometry | passed_mock | passed_mock |
| explicit_fonts_and_button_glyphs_fit_under_global_font_changes | passed_mock | passed_mock |
| advanced_controls_stay_inside_content_and_clear_gold_frame | passed_mock | passed_mock |
| compact_scale_close_glyph_and_clean_footer | passed_mock | passed_mock |
| long_row_labels_elide_but_full_values_and_actions_survive | passed_mock | passed_mock |
| multiline_native_editor_keeps_a_fixed_scrollable_viewport | passed_mock | passed_mock |
| footer_feedback_readable_without_covering_content | passed_mock | passed_mock |
| reference_theme_local_textures_and_typography | passed_mock | passed_mock |

## Failures

None in executed local checks.

Live Forever integration was **not run**. No spam was sent to a real chat channel. Actual event support, target vararg positions, secret-value behavior and third-party chat panels still require local target-client validation.
