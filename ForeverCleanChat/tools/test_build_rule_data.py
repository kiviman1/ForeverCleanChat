#!/usr/bin/env python3
"""Negative source-contract checks, deterministic generation, and check-only IO.

These tests validate the compiler; classification is tested by the Lua harness.
Run: python tools/test_build_rule_data.py
"""
import contextlib
import copy
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest import mock

import build_rule_data as build


class CompilerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = build.read_source()

    def setUp(self):
        self.data = copy.deepcopy(self.original)

    def rejected(self, message):
        with self.assertRaisesRegex(build.ValidationError, message):
            build.validate(self.data)

    def test_current_source_validates_all_counts(self):
        counts = build.validate(self.data)
        self.assertEqual(counts["classification_fixtures"], 595)
        self.assertEqual(counts["engineering_acceptance_contracts"], 26)
        self.assertEqual(counts["active_domain_indicators_total"], 37)
        self.assertEqual(counts["actual_user_chat_examples"], 1)

    def test_duplicate_json_key_is_not_silently_overwritten(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "source.json"
            source.write_text('{"mode":"strict","mode":"balanced"}', encoding="utf-8")
            with self.assertRaisesRegex(build.ValidationError, "duplicate JSON key"):
                build.read_source(source)

    def test_nonfinite_json_is_rejected(self):
        for constant in ("NaN", "Infinity", "-Infinity"):
            with self.subTest(constant=constant), tempfile.TemporaryDirectory() as folder:
                source = Path(folder) / "source.json"
                source.write_text('{"value":' + constant + '}', encoding="utf-8")
                with self.assertRaisesRegex(build.ValidationError, "non-finite JSON number"):
                    build.read_source(source)

    def test_wrong_schema_version(self):
        self.data["schema_version"] = "2.0.0"
        self.rejected("unsupported schema")

    def test_missing_section(self):
        del self.data["lexicons"]
        self.rejected("missing section")

    def test_unique_record_and_fixture_ids(self):
        for section in build.TABLES:
            with self.subTest(section=section):
                candidate = copy.deepcopy(self.data)
                candidate[section].append(copy.deepcopy(candidate[section][0]))
                with self.assertRaisesRegex(build.ValidationError, "duplicate id"):
                    build.validate(candidate)
        self.data["test_suite"]["test_cases"].append(copy.deepcopy(self.data["test_suite"]["test_cases"][0]))
        self.rejected("duplicate id")

    def test_counts_are_recomputed(self):
        self.data["counts"]["classification_fixtures"] += 1
        self.rejected("counts mismatch")

    def test_domain_is_lowercase_ascii_root(self):
        for root in ("SKYCOACH.GG", "https://skycoach.gg", "skycoach.gg/path", "bad-.com", "а.com"):
            with self.subTest(root=root):
                candidate = copy.deepcopy(self.data)
                candidate["domain_indicators"][0]["value"] = root
                with self.assertRaisesRegex(build.ValidationError, "invalid lowercase ASCII domain"):
                    build.validate(candidate)

    def test_domains_are_unique(self):
        self.data["domain_indicators"][1]["value"] = self.data["domain_indicators"][0]["value"]
        self.rejected("duplicate domain root")

    def test_unknown_evidence_cannot_activate_domain(self):
        self.data["domain_indicators"][0]["evidence_type"] = "guess_from_brand"
        self.rejected("unsupported active evidence")

    def test_evidence_tier_must_resolve_to_supporting_source(self):
        self.data["domain_indicators"][0]["source_refs"] = ["src_lua_51"]
        self.rejected("evidence tier not supported")

    def test_user_observation_has_no_invented_vendor(self):
        observed = next(row for row in self.data["domain_indicators"] if row["evidence_type"] == "user_observed_chat_ad")
        observed["vendor_id"] = "mythic_store"
        self.rejected("unverified vendor attribution")

    def test_user_observation_requires_campaign(self):
        self.data["observed_chat_campaigns"][0]["observed_domain"] = "other.example"
        self.rejected("missing observed campaign")

    def test_domain_does_not_infer_other_tlds_or_erase_hyphens(self):
        for key, value in (("infer_other_tlds", True), ("infer_typos_as_verified_domains", True),
                           ("preserve_canonical_digits", False), ("preserve_canonical_hyphens", False)):
            with self.subTest(key=key):
                candidate = copy.deepcopy(self.data)
                candidate["domain_indicators"][0][key] = value
                with self.assertRaisesRegex(build.ValidationError, "unsafe domain policy"):
                    build.validate(candidate)

    def test_quarantine_cannot_be_enabled(self):
        self.data["quarantined_candidates"][0]["enabled"] = True
        self.rejected("must be disabled")

    def test_quarantine_cannot_overlap_active(self):
        self.data["quarantined_candidates"][0]["domain"] = self.data["domain_indicators"][0]["value"]
        self.rejected("quarantine overlap")

    def test_unresolved_source_reference(self):
        self.data["normalization"]["source_refs"].append("missing_source")
        self.rejected("unresolved missing_source")

    def test_unresolved_lexicon_reference(self):
        self.data["feature_definitions"][0]["lexicon_refs"].append("missing_lexicon")
        self.rejected("unresolved missing_lexicon")

    def test_unresolved_fixture_indicator(self):
        self.data["test_suite"]["test_cases"][0]["expected_indicator_ids_contains"] = ["missing_indicator"]
        self.rejected("unresolved missing_indicator")

    def test_vendor_domain_relationship_cannot_be_invented(self):
        self.data["vendors"][0]["domain_indicator_ids"] = [self.data["domain_indicators"][1]["id"]]
        self.rejected("contradictory domain attribution")

    def test_ast_only_supports_declared_boolean_nodes(self):
        for ast in ({"regex": ".*"}, {"feature": "known_domain_exact", "code": "return true"},
                    {"all": []}, {"feature": "missing_feature"},
                    {"metric": "missing_metric", "gte": 1},
                    {"metric": "distinct_promotion_families", "gte": -1}):
            with self.subTest(ast=ast):
                candidate = copy.deepcopy(self.data)
                candidate["decision_rules"][0]["when"] = ast
                with self.assertRaises(build.ValidationError):
                    build.validate(candidate)

    def test_ast_has_work_budget(self):
        ast = {"feature": "known_domain_exact"}
        for _ in range(34):
            ast = {"not": ast}
        self.data["decision_rules"][0]["when"] = ast
        self.rejected("AST budget exceeded")

    def test_experimental_rules_remain_disabled_review_only(self):
        self.data["decision_rules"][-1]["enabled"] = True
        self.rejected("experimental rule must stay disabled")

    def test_lexicon_and_numeric_words_do_not_block_alone(self):
        self.data["lexicons"][0]["standalone_block"] = True
        self.rejected("lexicon cannot block alone")
        self.data = copy.deepcopy(self.original)
        self.data["numeric_parsers"]["standalone_block"] = True
        self.rejected("contextual parser required")

    def test_normalization_budgets_and_leet_policy(self):
        self.data["normalization"]["message_max_bytes"] = 5000
        self.rejected("integer in")
        self.data = copy.deepcopy(self.original)
        self.data["normalization"]["domain_transforms"]["leet_applies_to"] = "whole_message"
        self.rejected("unsafe structural/leet policy")

    def test_fullwidth_mapping_must_be_finite_known_range(self):
        self.data["normalization"]["domain_transforms"]["fullwidth_ascii"]["offset_to_subtract"] = 0
        self.rejected("invalid finite fullwidth map")

    def test_fuzzy_cannot_hard_block(self):
        self.data["normalization"]["fuzzy_matching"]["hard_block_allowed"] = True
        self.rejected("fuzzy must be off")

    def test_existing_mode_preservation_is_required(self):
        self.data["profiles"]["preserve_existing_mode_on_upgrade"] = False
        self.rejected("default/migration policy invalid")

    def test_fixture_expectations_are_legal_and_have_both_profiles(self):
        for expected in ({"strict": "block"}, {"strict": "review", "balanced": "allow"}):
            with self.subTest(expected=expected):
                candidate = copy.deepcopy(self.data)
                candidate["test_suite"]["test_cases"][0]["expected"] = expected
                with self.assertRaisesRegex(build.ValidationError, "invalid profile expectations"):
                    build.validate(candidate)

    def test_fixture_byte_budget_is_not_codepoint_count(self):
        self.data["test_suite"]["test_cases"][0]["message"] = "а" * 2049
        self.rejected("exceeds byte budget")

    def test_runtime_excludes_sources_examples_and_quarantine(self):
        runtime = build.runtime_pack(self.data)
        self.assertNotIn("test_suite", runtime)
        self.assertNotIn("source_registry", runtime)
        self.assertNotIn("observed_chat_campaigns", runtime)
        self.assertNotIn("quarantined_candidates", runtime)
        self.assertEqual({row["value"] for row in runtime["domains"]}, {row["value"] for row in self.data["domain_indicators"] if row["enabled"]})
        self.assertFalse({row["domain"] for row in self.data["quarantined_candidates"]} & {row["value"] for row in runtime["domains"]})
        self.assertTrue(all(set(row) == {"id", "name", "generated_text_aliases"} for row in runtime["vendors"]))
        self.assertNotIn("synthetic_display_variants", runtime["domains"][0])
        self.assertNotIn("source_refs", runtime["domains"][0])
        roots = {row["value"]: row for row in runtime["domains"]}
        self.assertNotEqual(roots["mythic-store.com"]["id"], roots["mythicstore.com"]["id"])
        self.assertIsNone(roots["mythicstore.com"]["vendor_id"])

    def test_output_is_deterministic_independent_of_object_key_order(self):
        first = build.outputs(self.data)
        reordered = json.loads(json.dumps(self.data), object_pairs_hook=lambda pairs: dict(reversed(pairs)))
        self.assertEqual(first, build.outputs(reordered))
        self.assertEqual(first, build.outputs(self.data))
        self.assertEqual(first[0], build.RUNTIME.read_bytes())
        self.assertEqual(first[1], build.FIXTURES.read_bytes())

    def test_lua_51_strings_escape_code_and_control_bytes(self):
        self.assertEqual(build.lua_string('"; os.execute("command"); --'), '"\\"; os.execute(\\"command\\"); --"')
        self.assertEqual(build.lua_string("\x0012\n\\"), '"\\00012\\010\\\\"')
        self.assertEqual(build.lua_string("İ русский"), '"İ русский"')

    def test_check_only_detects_stale_output_and_never_writes(self):
        runtime, fixtures = build.outputs(self.data)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            runtime_path = root / "Data.generated.lua"
            fixture_path = root / "Fixtures.generated.lua"
            runtime_path.write_bytes(runtime)
            fixture_path.write_bytes(b"stale fixture")
            with mock.patch.multiple(build, ROOT=root, RUNTIME=runtime_path, FIXTURES=fixture_path):
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(build.main(["--check"]), 1)
                self.assertEqual(fixture_path.read_bytes(), b"stale fixture")
                self.assertEqual(runtime_path.read_bytes(), runtime)
                fixture_path.write_bytes(fixtures)
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(build.main(["--check"]), 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
