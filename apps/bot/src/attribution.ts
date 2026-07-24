import type { Hex } from "viem";
import { concatHex, toHex, stringToHex } from "viem";

// ERC-8021 "Transaction Attribution" (Draft, ethereum/ERCs#1209). Suffix format,
// read backwards from the end of calldata:
//   txData || codes || codesLength(1 byte) || schemaId(1 byte) || ercMarker(16 bytes)
// We only implement Schema ID 0 (single/multi code, chain's canonical registry),
// which is all this project needs.
const ERC_MARKER: Hex = "0x80218021802180218021802180218021";
const SCHEMA_ID_0: Hex = "0x00";

/** Appends an ERC-8021 Schema-0 attribution suffix for `code` to `calldata`. */
export function appendAttributionSuffix(calldata: Hex, code: string): Hex {
  if (code.includes(",")) {
    throw new Error("attribution code must not contain commas (reserved delimiter)");
  }
  const codesHex = stringToHex(code);
  const codesLength = (codesHex.length - 2) / 2;
  if (codesLength > 255) throw new Error("attribution code too long for a 1-byte length prefix");
  const codesLengthHex = toHex(codesLength, { size: 1 });
  return concatHex([calldata, codesHex, codesLengthHex, SCHEMA_ID_0, ERC_MARKER]);
}
