#!/usr/bin/env python3
"""Validate research data and emit inert Lua 5.1 tables, without network access.

Run from any directory: python tools/build_rule_data.py [--check].
The runtime pack excludes sources, campaign examples, quarantine, and fixtures.
Research text is data: it is never evaluated as Python or Lua code.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "research" / "forever-clean-chat-research.json"
RUNTIME = ROOT / "Data.generated.lua"
FIXTURES = ROOT / "tests" / "Fixtures.generated.lua"
SCHEMA_VERSION = "1.0.0"
PROFILES = {"balanced", "strict"}
EVIDENCE_TYPES = {
    "retrieved_primary_content", "indexed_primary_excerpt", "user_observed_chat_ad",
}
TABLES = (
    "source_registry", "vendors", "domain_indicators", "observed_chat_campaigns",
    "lexicons", "marketing_hooks", "feature_definitions", "metrics",
    "decision_rules", "lexical_templates",
)
HOST = re.compile(r"(?=.{1,253}\Z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}\Z")


class ValidationError(ValueError):
    pass


def require(condition, message):
    if not condition:
        raise ValidationError(message)


def text(value, path):
    require(isinstance(value, str) and bool(value), f"{path}: nonempty string required")
    try:
        value.encode("utf-8")
    except UnicodeEncodeError as exc:
        raise ValidationError(f"{path}: invalid Unicode scalar") from exc
    return value


def strings(value, path, *, empty=True):
    require(isinstance(value, list) and (empty or value), f"{path}: string array required")
    for index, entry in enumerate(value):
        text(entry, f"{path}[{index}]")
    return value


def integer(value, path, minimum=0, maximum=1_000_000):
    require(type(value) is int and minimum <= value <= maximum,
            f"{path}: integer in [{minimum}, {maximum}] required")
    return value


def boolean(value, path):
    require(type(value) is bool, f"{path}: boolean required")


def no_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, f"duplicate JSON key: {key}")
        result[key] = value
    return result


def read_source(path=SOURCE):
    # Do not accept JavaScript NaN/Infinity extensions or silently overwritten keys.
    def bad_constant(value):
        raise ValidationError(f"non-finite JSON number: {value}")
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"),
                          object_pairs_hook=no_duplicate_keys,
                          parse_constant=bad_constant)
    except (UnicodeError, json.JSONDecodeError) as exc:
        raise ValidationError(f"invalid UTF-8 JSON: {exc}") from exc


def index_records(records, path):
    require(isinstance(records, list), f"{path}: record array required")
    result = {}
    for record in records:
        require(isinstance(record, dict), f"{path}: object record required")
        identity = text(record.get("id"), f"{path}.id")
        require(identity not in result, f"{path}: duplicate id {identity}")
        result[identity] = record
    return result


def validate_ast(node, features, metrics, path, depth=0, budget=None):
    if budget is None:
        budget = [0]
    budget[0] += 1
    require(depth <= 32 and budget[0] <= 256, f"{path}: AST budget exceeded")
    require(isinstance(node, dict), f"{path}: AST node must be an object")
    keys = set(node)
    if keys == {"feature"}:
        require(isinstance(node["feature"], str) and node["feature"] in features, f"{path}: unknown feature {node['feature']}")
    elif keys == {"metric", "gte"}:
        require(isinstance(node["metric"], str) and node["metric"] in metrics, f"{path}: unknown metric {node['metric']}")
        integer(node["gte"], f"{path}.gte")
    elif keys in ({"all"}, {"any"}):
        operator = next(iter(keys))
        children = node[operator]
        require(isinstance(children, list) and children, f"{path}: nonempty {operator} required")
        for index, child in enumerate(children):
            validate_ast(child, features, metrics, f"{path}.{operator}[{index}]", depth + 1, budget)
    elif keys == {"not"}:
        validate_ast(node["not"], features, metrics, f"{path}.not", depth + 1, budget)
    else:
        raise ValidationError(f"{path}: unsupported AST node keys {sorted(keys)}")


def validate_references(value, indices, path="root"):
    arrays = {
        "source_refs": "source_registry", "lexicon_refs": "lexicons",
        "object_lexicon_refs": "lexicons", "domain_indicator_ids": "domain_indicators",
        "expected_indicator_ids_contains": "domain_indicators",
        "expected_indicator_ids_excludes": "domain_indicators",
    }
    singles = {"vendor_id": "vendors", "lexicon_id": "lexicons"}
    if isinstance(value, dict):
        for key, item in value.items():
            location = f"{path}.{key}"
            if key in arrays:
                for reference in strings(item, location):
                    require(reference in indices[arrays[key]], f"{location}: unresolved {reference}")
            elif key in singles and item is not None:
                require(isinstance(item, str) and item in indices[singles[key]],
                        f"{location}: unresolved {item}")
            elif key == "produces":
                require(isinstance(item, str) and item in indices["feature_definitions"], f"{location}: unresolved feature {item}")
            validate_references(item, indices, location)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            validate_references(item, indices, f"{path}[{index}]")
    elif isinstance(value, str):
        # Includes strings not otherwise validated (research/source annotations).
        try:
            value.encode("utf-8")
        except UnicodeEncodeError as exc:
            raise ValidationError(f"{path}: invalid Unicode scalar") from exc
    elif isinstance(value, float):
        require(math.isfinite(value), f"{path}: non-finite number")


def compute_counts(data):
    vendors = data["vendors"]
    domains = data["domain_indicators"]
    cases = data["test_suite"]["test_cases"]
    classification = [row for row in cases if row["kind"] == "classification"]
    return {
        "vendor_brands": len(vendors),
        "brands_with_retrieved_primary_page_content": sum(row["website_evidence_tier"] == "retrieved_primary_content" for row in vendors),
        "brands_with_indexed_primary_excerpt_only": sum(row["website_evidence_tier"] == "indexed_primary_excerpt" for row in vendors),
        "source_supported_vendor_domains": sum(row["enabled"] and row["evidence_type"] in {"retrieved_primary_content", "indexed_primary_excerpt"} for row in domains),
        "user_observed_domain_without_web_confirmation": sum(row["enabled"] and row["evidence_type"] == "user_observed_chat_ad" for row in domains),
        "active_domain_indicators_total": sum(row["enabled"] for row in domains),
        "quarantined_domains": len(data["quarantined_candidates"]),
        "vendors_with_forever_label_observed": sum(row["forever_specific_listing_observed"] for row in vendors),
        "source_records": len(data["source_registry"]),
        "generated_domain_display_variants": sum(len(row["synthetic_display_variants"]) for row in domains),
        "lexicon_families": len(data["lexicons"]),
        "lexicon_phrases_including_language_duplicates": sum(len(terms) for row in data["lexicons"] for terms in row["terms_by_language"].values()),
        "marketing_hook_families": len(data["marketing_hooks"]),
        "decision_rules_total": len(data["decision_rules"]),
        "decision_rules_enabled": sum(row["enabled"] for row in data["decision_rules"]),
        "classification_fixtures": len(classification),
        "engineering_acceptance_contracts": sum(row["kind"] == "engineering_acceptance" for row in cases),
        "all_test_cases": len(cases),
        "actual_user_chat_examples": sum(row["provenance"] == "user_observed_transcription_readable_text" for row in classification),
        "synthetic_classification_fixtures": sum(row["provenance"] == "synthetic" for row in classification),
    }


def validate(data):
    require(isinstance(data, dict), "root: object required")
    require(data.get("schema_version") == SCHEMA_VERSION, "unsupported schema_version")
    text(data.get("dataset_id"), "dataset_id")
    text(data.get("dataset_version"), "dataset_version")
    require(isinstance(data.get("implementation_plan_for_codex"), dict),
            "implementation_plan_for_codex: object required")
    for key in (*TABLES, "counts", "quarantined_candidates", "normalization", "profiles",
                "external_destination_policy", "numeric_parsers", "test_suite"):
        require(key in data, f"missing section: {key}")
    indices = {key: index_records(data[key], key) for key in TABLES}
    sources = indices["source_registry"]
    for row in data["vendors"]:
        text(row.get("name"), "vendor.name")
        strings(row.get("generated_text_aliases"), "vendor.generated_text_aliases", empty=False)
        strings(row.get("source_refs"), "vendor.source_refs", empty=False)
        require(row.get("website_evidence_tier") in {"retrieved_primary_content", "indexed_primary_excerpt"},
                f"vendor {row['id']}: invalid evidence tier")
        boolean(row.get("forever_specific_listing_observed"), "vendor.forever_specific_listing_observed")
    roots = set()
    active_roots = set()
    for row in data["domain_indicators"]:
        identity = row["id"]
        root = row.get("value")
        require(isinstance(root, str) and HOST.fullmatch(root) is not None,
                f"{identity}: invalid lowercase ASCII domain root")
        require(root not in roots, f"duplicate domain root: {root}")
        roots.add(root)
        boolean(row.get("enabled"), f"{identity}.enabled")
        require(row.get("type") == "domain", f"{identity}: unsupported indicator type")
        require(row.get("match_policy") == "exact_host_or_bounded_text_obfuscation", f"{identity}: unsafe match policy")
        for key, want in (("preserve_canonical_digits", True), ("preserve_canonical_hyphens", True),
                          ("infer_other_tlds", False), ("infer_typos_as_verified_domains", False)):
            require(row.get(key) is want, f"{identity}.{key}: unsafe domain policy")
        boolean(row.get("include_subdomains"), f"{identity}.include_subdomains")
        strings(row.get("source_refs"), f"{identity}.source_refs", empty=False)
        variants = row.get("synthetic_display_variants")
        require(isinstance(variants, list), f"{identity}: display variant array required")
        transforms = set()
        for variant in variants:
            require(isinstance(variant, dict), f"{identity}: invalid display variant")
            transform = text(variant.get("transform"), f"{identity}.variant.transform")
            require(transform not in transforms, f"{identity}: duplicate transform {transform}")
            transforms.add(transform)
            text(variant.get("text"), f"{identity}.variant.text")
            require(variant.get("status") == "generated_not_observed", f"{identity}: synthetic variant presented as observation")
        if row["enabled"]:
            active_roots.add(root)
            evidence = row.get("evidence_type")
            require(evidence in EVIDENCE_TYPES, f"{identity}: unsupported active evidence")
            referenced = [sources.get(ref, {}) for ref in row["source_refs"]]
            if evidence == "user_observed_chat_ad":
                require(row.get("vendor_id") is None, f"{identity}: user observation has unverified vendor attribution")
                require(any(ref.get("source_type") == "user_provided_image" and ref.get("retrieval_status") == "user_supplied_image_read" for ref in referenced), f"{identity}: missing user observation evidence")
                require(any(campaign.get("observed_domain") == root for campaign in data["observed_chat_campaigns"]), f"{identity}: missing observed campaign")
            else:
                require(row.get("vendor_id") in indices["vendors"], f"{identity}: source-supported domain needs vendor")
                status = {"retrieved_primary_content": "page_content_retrieved", "indexed_primary_excerpt": "search_index_excerpt_only"}[evidence]
                require(any(ref.get("source_type") == "vendor_primary" and ref.get("retrieval_status") == status for ref in referenced), f"{identity}: evidence tier not supported by referenced source")
    for row in data["vendors"]:
        for indicator in strings(row.get("domain_indicator_ids"), f"{row['id']}.domain_indicator_ids"):
            require(indicator in indices["domain_indicators"], f"{row['id']}: unknown domain {indicator}")
            require(indices["domain_indicators"][indicator].get("vendor_id") == row["id"], f"{row['id']}: contradictory domain attribution")
    quarantine = data["quarantined_candidates"]
    require(isinstance(quarantine, list), "quarantined_candidates: array required")
    quarantined_roots = set()
    for row in quarantine:
        require(isinstance(row, dict) and row.get("enabled") is False, "quarantine: must be disabled")
        root = row.get("domain")
        require(isinstance(root, str) and HOST.fullmatch(root) is not None, "quarantine: invalid domain")
        require(root not in quarantined_roots and root not in active_roots, f"quarantine overlap/duplicate: {root}")
        quarantined_roots.add(root)
    for row in data["lexicons"]:
        require(row.get("standalone_block") is False, f"{row['id']}: lexicon cannot block alone")
        require(row.get("match_unit") == "bounded_phrase_or_token", f"{row['id']}: invalid match unit")
        terms = row.get("terms_by_language")
        require(isinstance(terms, dict) and terms, f"{row['id']}: language terms required")
        for language, values in terms.items():
            text(language, "lexicon.language")
            strings(values, f"{row['id']}.{language}", empty=False)
    for row in data["marketing_hooks"]:
        require(row.get("standalone_block") is False and row.get("claims_are_verified_truth") is False,
                f"{row['id']}: marketing claim must be contextual unverified data")
    features, metrics = indices["feature_definitions"], indices["metrics"]
    for row in data["decision_rules"]:
        identity = row["id"]
        integer(row.get("priority"), f"{identity}.priority")
        boolean(row.get("enabled"), f"{identity}.enabled")
        profiles = strings(row.get("profiles"), f"{identity}.profiles", empty=False)
        require(set(profiles) <= PROFILES and len(set(profiles)) == len(profiles), f"{identity}: invalid profiles")
        require(row.get("action") in {"block", "review_only"}, f"{identity}: invalid action")
        text(row.get("reason_code"), f"{identity}.reason_code")
        validate_ast(row.get("when"), features, metrics, identity)
        if identity in {"R190_COMMERCIAL_REPEAT_REVIEW", "R191_FUZZY_REVIEW"}:
            require(row["enabled"] is False and row["action"] == "review_only", f"{identity}: experimental rule must stay disabled/review only")
    normalization = data["normalization"]
    require(isinstance(normalization, dict), "normalization: object required")
    for key, limit in (("message_max_bytes", 4096), ("max_domain_candidates", 32),
                       ("max_candidate_visible_codepoints", 128),
                       ("max_separator_codepoints_between_signature_characters", 3)):
        integer(normalization.get(key), f"normalization.{key}", 1, limit)
    transforms = normalization.get("domain_transforms", {})
    require(isinstance(transforms, dict), "normalization.domain_transforms: object required")
    require(transforms.get("canonical_digits_never_replaced") is True and
            transforms.get("preserve_structural_hyphens") is True and
            transforms.get("leet_requires_commercial_context") is True and
            transforms.get("leet_applies_to") == "registrable_label_only_not_tld",
            "normalization: unsafe structural/leet policy")
    integer(transforms.get("leet_max_substitutions"), "normalization.leet_max_substitutions", 0, 2)
    boolean(transforms.get("casefold_ascii"), "normalization.casefold_ascii")
    fullwidth = transforms.get("fullwidth_ascii")
    require(isinstance(fullwidth, dict) and fullwidth.get("from_codepoint_range") == ["U+FF01", "U+FF5E"] and fullwidth.get("offset_to_subtract") == 65248,
            "normalization: invalid finite fullwidth map")
    for key in ("dot_characters", "dot_words", "format_characters_to_ignore_in_domain_candidate"):
        strings(transforms.get(key), f"normalization.{key}", empty=False)
    for character in transforms["dot_characters"]:
        require(len(character) == 1, "normalization: single dot scalar required")
    for codepoint in transforms["format_characters_to_ignore_in_domain_candidate"]:
        require(re.fullmatch(r"U\+[0-9A-F]{4,6}", codepoint) is not None and
                int(codepoint[2:], 16) <= 0x10FFFF and not 0xD800 <= int(codepoint[2:], 16) <= 0xDFFF,
                "normalization: invalid ignored scalar")
    for key in ("selected_confusables", "leet_alternatives_for_canonical_ascii_letters"):
        mapping = transforms.get(key)
        require(isinstance(mapping, dict), f"normalization.{key}: map required")
        for canonical, alternatives in mapping.items():
            require(len(canonical) == 1 and "a" <= canonical <= "z", f"normalization.{key}: ASCII letter key required")
            for alternative in strings(alternatives, f"normalization.{key}.{canonical}", empty=False):
                require(len(alternative) == 1, f"normalization.{key}: single Unicode scalar required")
    fuzzy = normalization.get("fuzzy_matching", {})
    require(isinstance(fuzzy, dict) and fuzzy.get("enabled_by_default") is False and fuzzy.get("hard_block_allowed") is False,
            "normalization: fuzzy must be off and review only")
    integer(fuzzy.get("minimum_label_length"), "normalization.fuzzy.minimum_label_length", 8, 128)
    integer(fuzzy.get("max_edit_distance"), "normalization.fuzzy.max_edit_distance", 0, 1)
    boolean(fuzzy.get("requires_merchant_context"), "normalization.fuzzy.requires_merchant_context")
    boundary = normalization.get("domain_boundary_contract")
    require(isinstance(boundary, dict), "normalization.domain_boundary_contract: object required")
    for key, expected in (("include_paths_queries_as_domain_mentions", False),
                          ("include_url_userinfo_as_host", False), ("do_not_expand_tlds", True),
                          ("do_not_remove_hyphens_from_valid_unknown_ascii_hosts", True),
                          ("do_not_match_prefix_substrings", True)):
        require(boundary.get(key) is expected, f"normalization.boundary.{key}: unsafe policy")
    semantic = normalization.get("semantic_rules")
    require(isinstance(semantic, dict), "normalization.semantic_rules: object required")
    integer(semantic.get("clause_scope_max_content_tokens"), "normalization.semantic.clause_scope_max_content_tokens", 1, 24)
    integer(semantic.get("offer_object_max_token_distance"), "normalization.semantic.offer_object_max_token_distance", 1, 12)
    require(semantic.get("global_leet_folding") is False, "normalization: global leet forbidden")
    languages = strings(semantic.get("language_support"), "normalization.language_support", empty=False)
    linking = semantic.get("ad_segment_linking")
    require(isinstance(linking, dict), "normalization.semantic.ad_segment_linking: object required")
    integer(linking.get("max_adjacent_clauses"), "normalization.semantic.max_adjacent_clauses", 1, 3)
    integer(linking.get("max_total_content_tokens"), "normalization.semantic.max_total_content_tokens", 1, 64)
    for row in data["lexicons"]:
        require(set(row["terms_by_language"]) <= set(languages), f"{row['id']}: unsupported lexicon language")
    profiles = data["profiles"]
    require(isinstance(profiles, dict) and profiles.get("default_new_install") == "strict" and
            profiles.get("preserve_existing_mode_on_upgrade") is True,
            "profiles: default/migration policy invalid")
    for name in PROFILES:
        require(isinstance(profiles.get(name), dict), f"profiles.{name}: object required")
        require(profiles[name].get("known_domain_mention_policy") in {"hide_all", "contextual"}, f"profiles.{name}: invalid domain policy")
        for key in ("block_gold_paid_boosts", "block_buyer_requests"):
            boolean(profiles[name].get(key), f"profiles.{name}.{key}")
    options = profiles.get("known_domain_policy_options")
    require(isinstance(options, dict), "profiles.known_domain_policy_options: object required")
    validate_ast(options.get("contextual_gate"), features, metrics, "profiles.contextual_gate")
    external = data["external_destination_policy"]
    require(isinstance(external, dict), "external_destination_policy: object required")
    shared = strings(external.get("shared_platforms_not_blacklisted"), "external.shared_platforms_not_blacklisted")
    require(not set(shared) & active_roots, "shared platform is blacklisted as seller domain")
    require(external.get("exact_commercial_invite_ids_verified") == [], "unverified external invite IDs must not be synthesized")
    for row in data["lexical_templates"]:
        require(row.get("language") in languages, f"{row['id']}: unsupported template language")
        if "max_intervening_tokens" in row:
            integer(row["max_intervening_tokens"], f"{row['id']}.max_intervening_tokens", 0, 4)
            strings(row.get("verb_tokens"), f"{row['id']}.verb_tokens", empty=False)
            strings(row.get("allowed_intervening_tokens"), f"{row['id']}.allowed_intervening_tokens")
        if "shape" in row:
            text(row["shape"], f"{row['id']}.shape")
    numeric = data["numeric_parsers"]
    require(isinstance(numeric, dict) and numeric.get("standalone_block") is False,
            "numeric_parsers: contextual parser required")
    symbols = numeric.get("real_money_symbols")
    require(isinstance(symbols, dict) and symbols, "numeric_parsers.real_money_symbols: map required")
    for key, value in symbols.items():
        text(key, "numeric.symbol")
        text(value, "numeric.symbol_currency")
    for key in ("real_money_units", "ingame_amount_units", "service_rate_shapes", "rate_unit_aliases"):
        strings(numeric.get(key), f"numeric_parsers.{key}", empty=False)
    suite = data["test_suite"]
    require(isinstance(suite, dict), "test_suite: object required")
    cases = index_records(suite.get("test_cases"), "test_suite.test_cases")
    for identity, row in cases.items():
        if row.get("kind") == "classification":
            message = text(row.get("message"), f"{identity}.message")
            require(len(message.encode("utf-8")) <= normalization["message_max_bytes"], f"{identity}: fixture message exceeds byte budget")
            event = text(row.get("event"), f"{identity}.event")
            require(re.fullmatch(r"CHAT_MSG_[A-Z_]+", event) is not None, f"{identity}: invalid event")
            expected = row.get("expected")
            require(isinstance(expected, dict) and set(expected) == PROFILES and all(value in {"allow", "block"} for value in expected.values()), f"{identity}: invalid profile expectations")
            require(row.get("provenance") in {"synthetic", "user_observed_transcription_readable_text"}, f"{identity}: invalid fixture provenance")
            if "context" in row:
                require(isinstance(row["context"], dict), f"{identity}.context: object required")
                for key, value in row["context"].items():
                    require(key in {"sender_on_manual_allowlist", "sender_on_manual_blocklist", "verified_gm_flag", "is_self_guid"}, f"{identity}: unknown context field")
                    boolean(value, f"{identity}.context.{key}")
            if "config_overrides" in row:
                overrides = row["config_overrides"]
                require(isinstance(overrides, dict) and set(overrides) <= {"enabled", "known_domain_mention_policy"}, f"{identity}: unsupported config override")
                if "enabled" in overrides:
                    boolean(overrides["enabled"], f"{identity}.enabled")
                if "known_domain_mention_policy" in overrides:
                    require(overrides["known_domain_mention_policy"] in {"hide_all", "contextual"}, f"{identity}: invalid domain policy override")
        elif row.get("kind") == "engineering_acceptance":
            text(row.get("setup_tr"), f"{identity}.setup_tr")
            text(row.get("expected_behavior_tr"), f"{identity}.expected_behavior_tr")
            require(row.get("status") == "not_executed", f"{identity}: source contract must not claim execution")
        else:
            raise ValidationError(f"{identity}: unsupported fixture kind")
    validate_references(data, indices)
    actual = compute_counts(data)
    require(data["counts"] == actual, f"counts mismatch: declared={data['counts']}, computed={actual}")
    return actual


def select(record, keys):
    return {key: record[key] for key in keys if key in record}


def runtime_pack(data):
    # Explicit selection prevents provenance, source URL prose, hypothetical domain
    # variants, quarantine records, and test examples from becoming runtime inputs.
    normal = data["normalization"]
    normalization = select(normal, (
        "message_max_bytes", "max_domain_candidates", "max_candidate_visible_codepoints",
        "max_separator_codepoints_between_signature_characters",
    ))
    normalization["domain_transforms"] = select(normal["domain_transforms"], (
        "casefold_ascii", "fullwidth_ascii", "dot_characters", "dot_words",
        "format_characters_to_ignore_in_domain_candidate", "selected_confusables",
        "leet_alternatives_for_canonical_ascii_letters", "leet_max_substitutions",
        "leet_requires_commercial_context", "canonical_digits_never_replaced",
        "preserve_structural_hyphens", "leet_applies_to",
    ))
    normalization["domain_boundary_contract"] = {
        key: value for key, value in normal["domain_boundary_contract"].items()
        if isinstance(value, bool)
    }
    normalization["fuzzy_matching"] = select(normal["fuzzy_matching"], (
        "enabled_by_default", "hard_block_allowed", "minimum_label_length",
        "max_edit_distance", "requires_merchant_context",
    ))
    normalization["semantic_rules"] = select(normal["semantic_rules"], (
        "clause_scope_max_content_tokens", "offer_object_max_token_distance",
        "language_support", "global_leet_folding",
    ))
    normalization["semantic_rules"]["ad_segment_linking"] = select(normal["semantic_rules"]["ad_segment_linking"], (
        "max_adjacent_clauses", "max_total_content_tokens",
    ))
    profiles = select(data["profiles"], ("recommended_for_this_user", "default_new_install", "preserve_existing_mode_on_upgrade"))
    for name in sorted(PROFILES):
        profiles[name] = select(data["profiles"][name], ("known_domain_mention_policy", "block_gold_paid_boosts", "block_buyer_requests"))
    profiles["known_domain_policy_options"] = {
        "contextual_gate": data["profiles"]["known_domain_policy_options"]["contextual_gate"],
    }
    return {
        **select(data, ("dataset_id", "dataset_version", "schema_version")),
        "normalization": normalization,
        "profiles": profiles,
        "external_destination_policy": select(data["external_destination_policy"], ("shared_platforms_not_blacklisted", "exact_commercial_invite_ids_verified")),
        "feature_definitions": [select(row, ("id", "lexicon_refs")) for row in data["feature_definitions"]],
        "metrics": [select(row, ("id",)) for row in data["metrics"]],
        "decision_rules": [select(row, ("id", "priority", "profiles", "enabled", "when", "action", "reason_code")) for row in sorted(data["decision_rules"], key=lambda row: (row["priority"], row["id"]))],
        "lexicons": [select(row, ("id", "standalone_block", "match_unit", "terms_by_language")) for row in data["lexicons"]],
        "marketing_hooks": [select(row, ("id", "lexicon_id", "standalone_block")) for row in data["marketing_hooks"]],
        "lexical_templates": [select(row, ("id", "language", "verb_tokens", "allowed_intervening_tokens", "max_intervening_tokens", "object_lexicon_refs", "produces", "shape")) for row in data["lexical_templates"]],
        "numeric_parsers": select(data["numeric_parsers"], ("real_money_symbols", "real_money_units", "ingame_amount_units", "service_rate_shapes", "rate_unit_aliases", "standalone_block")),
        "domains": [select(row, ("id", "type", "value", "vendor_id", "enabled", "evidence_type", "match_policy", "include_subdomains", "preserve_canonical_digits", "preserve_canonical_hyphens", "infer_other_tlds", "infer_typos_as_verified_domains")) for row in data["domain_indicators"] if row["enabled"]],
        "vendors": [select(row, ("id", "name", "generated_text_aliases")) for row in data["vendors"]],
    }


def lua_string(value):
    # Three-digit decimal byte escapes are unambiguous in Lua 5.1, including
    # a control byte followed by digits. Unicode stays UTF-8; never emit \u.
    escaped = []
    for character in value:
        if character == '"':
            escaped.append('\\"')
        elif character == "\\":
            escaped.append("\\\\")
        elif ord(character) < 32 or ord(character) == 127:
            escaped.append(f"\\{ord(character):03d}")
        else:
            escaped.append(character)
    return '"' + "".join(escaped) + '"'


def lua_table(value, depth=0):
    if value is None:
        return "nil"
    if value is True:
        return "true"
    if value is False:
        return "false"
    if isinstance(value, str):
        return lua_string(value)
    if type(value) is int:
        return str(value)
    if isinstance(value, float):
        require(math.isfinite(value), "cannot serialize non-finite Lua number")
        return repr(value)
    indent = "    " * depth
    next_indent = indent + "    "
    if isinstance(value, list):
        entries = [lua_table(item, depth + 1) for item in value]
    elif isinstance(value, dict):
        # Sorted UTF-8 string keys; array ordering is retained from the source.
        entries = [f"[{lua_string(key)}] = {lua_table(value[key], depth + 1)}" for key in sorted(value)]
    else:
        raise ValidationError(f"unsupported Lua table value {type(value).__name__}")
    if not entries:
        return "{}"
    return "{\n" + "\n".join(next_indent + entry + "," for entry in entries) + "\n" + indent + "}"


def outputs(data):
    validate(data)
    header = "-- Generated by tools/build_rule_data.py; edit the research JSON and rebuild.\n"
    runtime = header + "-- Offline, inert Lua 5.1 data. Sources and fixtures are excluded.\nlocal _, NS = ...\nNS.Data = " + lua_table(runtime_pack(data)) + "\n"
    fixtures = header + "-- Test specifications only; source statuses do not claim test execution.\nreturn " + lua_table(data["test_suite"]) + "\n"
    return runtime.encode("utf-8"), fixtures.encode("utf-8")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate and fail if generated files differ; writes nothing")
    parser.add_argument("--source", type=Path, default=SOURCE, help="source JSON (default: bundled research copy)")
    args = parser.parse_args(argv)
    try:
        data = read_source(args.source)
        generated = outputs(data)
        stale = []
        for path, content in zip((RUNTIME, FIXTURES), generated):
            if args.check:
                if not path.exists() or path.read_bytes() != content:
                    stale.append(str(path.relative_to(ROOT)))
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(content)
        if stale:
            print("Generated files are stale: " + ", ".join(stale), file=sys.stderr)
            return 1
        counts = data["counts"]
        print(f"Validated {counts['active_domain_indicators_total']} active domains, {counts['quarantined_domains']} quarantined domains, {counts['classification_fixtures']} classification fixtures, {counts['engineering_acceptance_contracts']} engineering contracts.")
        for path, content in zip((RUNTIME, FIXTURES), generated):
            print(f"{path.name}: sha256={hashlib.sha256(content).hexdigest()} bytes={len(content)}")
        print("Generated files match." if args.check else "Generated files written.")
        return 0
    except (OSError, ValidationError, KeyError, TypeError) as exc:
        print(f"Validation failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
