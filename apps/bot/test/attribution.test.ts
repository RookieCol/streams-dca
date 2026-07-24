import { test } from "node:test";
import assert from "node:assert/strict";
import { appendAttributionSuffix } from "../src/attribution.ts";

// Test vector taken verbatim from ERC-8021 (ethereum/ERCs#1209, ERCS/erc-8021.md),
// "Single entity attribution + canonical registry" test case.
test("matches the official ERC-8021 schema-0 test vector", () => {
  const result = appendAttributionSuffix("0xdddddddd", "baseapp");
  assert.equal(
    result,
    "0xdddddddd62617365617070070080218021802180218021802180218021",
  );
});

test("rejects codes containing a comma", () => {
  assert.throws(() => appendAttributionSuffix("0xdddddddd", "base,app"));
});
