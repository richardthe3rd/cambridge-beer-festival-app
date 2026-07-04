#!/usr/bin/env node
// Decode minified Flutter-web stack frames (main.dart.js:LINE:COLUMN) back to
// original Dart source positions using a main.dart.js.map source map.
//
// Requires the `source-map` npm package, which is NOT a project dependency —
// install it temporarily, run this script, then uninstall:
//
//   npm install source-map
//   node .claude/skills/diagnostics-and-tooling/scripts/decode-stack.mjs \
//     build/web/main.dart.js.map 89998:16 89533:25
//   npm uninstall source-map
//
// Produce the map with (mise-tasks/build/web.sh / build:web:prod do NOT pass
// --source-maps — you must run this directly):
//
//   ./bin/mise exec -- flutter build web --release --base-href "/" --source-maps
//   # -> build/web/main.dart.js + build/web/main.dart.js.map
//
// To match CI's exact line numbering (CI inlines 5 --dart-define values that
// a plain local build doesn't have, shifting minified line numbers by
// roughly 4 lines — see SKILL.md "CI vs local offset"), rebuild with:
//
//   ./bin/mise exec -- flutter build web --release --base-href "/" --source-maps \
//     --dart-define=GIT_TAG=local --dart-define=GIT_COMMIT=local \
//     --dart-define=GIT_BRANCH=local --dart-define=BUILD_VERSION=local \
//     --dart-define=BUILD_TIME=local
//
// Or skip rebuilding entirely and pull CI's own map — see SKILL.md "Fetching
// the CI source map" for the `gh run download -n source-maps` command.
//
// Usage:
//   node decode-stack.mjs <map-file> <line:column>[:label] [<line:column>[:label] ...]
//   node decode-stack.mjs <map-file> --offset 4 <line:column>[:label] ...
//
// With --offset N, each position is also tried at line+N, in case you're
// decoding a CI stack trace against a locally-built (non-dart-define) map —
// SourceMapConsumer returns a null source on a miss, so trying both is safe.
//
// Examples:
//   node decode-stack.mjs build/web/main.dart.js.map 89998:16
//   node decode-stack.mjs build/web/main.dart.js.map 89998:16:"crash point" 89533:25:"caller"
//   node decode-stack.mjs build/web/main.dart.js.map --offset 4 89998:16

import { readFileSync } from "node:fs";
import { SourceMapConsumer } from "source-map";

function usageAndExit(message) {
  if (message) console.error(`error: ${message}\n`);
  console.error(
    "Usage: node decode-stack.mjs <map-file> [--offset N] <line:column>[:label] ...",
  );
  process.exit(message ? 1 : 0);
}

const args = process.argv.slice(2);
if (args.length === 0 || args.includes("-h") || args.includes("--help")) {
  usageAndExit();
}

const mapFile = args.shift();
let offset = 0;
if (args[0] === "--offset") {
  args.shift();
  offset = parseInt(args.shift(), 10);
  if (Number.isNaN(offset)) usageAndExit("--offset requires a number");
}

if (args.length === 0) {
  usageAndExit("provide at least one line:column frame to decode");
}

const frames = args.map((arg) => {
  const parts = arg.split(":");
  if (parts.length < 2) {
    usageAndExit(`bad frame "${arg}" — expected line:column[:label]`);
  }
  const line = parseInt(parts[0], 10);
  const column = parseInt(parts[1], 10);
  const label = parts.slice(2).join(":") || arg;
  if (Number.isNaN(line) || Number.isNaN(column)) {
    usageAndExit(`bad frame "${arg}" — line/column must be numbers`);
  }
  return { line, column, label };
});

let rawMap;
try {
  rawMap = JSON.parse(readFileSync(mapFile, "utf8"));
} catch (err) {
  console.error(
    `error: could not read/parse map file "${mapFile}": ${err.message}`,
  );
  process.exit(1);
}

function formatPosition(pos) {
  if (!pos || !pos.source) return null;
  const src = pos.source.replace(/.*?packages\//, "");
  return `${src}:${pos.line}${pos.name ? ` (${pos.name})` : ""}`;
}

SourceMapConsumer.with(rawMap, null, (consumer) => {
  for (const frame of frames) {
    const direct = consumer.originalPositionFor({
      line: frame.line,
      column: frame.column,
    });
    const directStr = formatPosition(direct);

    if (directStr) {
      console.log(`${frame.label} -> ${directStr}`);
      continue;
    }

    if (offset !== 0) {
      const shifted = consumer.originalPositionFor({
        line: frame.line + offset,
        column: frame.column,
      });
      const shiftedStr = formatPosition(shifted);
      if (shiftedStr) {
        console.log(
          `${frame.label} -> ${shiftedStr}  (matched at line+${offset}, not exact line)`,
        );
        continue;
      }
    }

    console.log(
      `${frame.label} -> NO MATCH at line ${frame.line}` +
        (offset !== 0
          ? ` (also tried line+${offset}=${frame.line + offset})`
          : "") +
        " — wrong map file, or line is inside generated runtime glue, not app code",
    );
  }
}).catch((err) => {
  console.error(`error: failed to load source map: ${err.message}`);
  process.exit(1);
});
