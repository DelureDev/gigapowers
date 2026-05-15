#!/usr/bin/env node
// Single source of truth for bumping the gigapowers version.
// Usage: node scripts/bump-version.mjs <major.minor.patch>
// Rewrites every hand-maintained copy of the version: plugin.json (.version)
// and marketplace.json (.metadata.version + .plugins[0].version). Uses a
// targeted string replace so the manifests' hand-authored formatting is kept.
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const version = process.argv[2];
if (!version || !/^\d+\.\d+\.\d+$/.test(version)) {
  console.error("Usage: node scripts/bump-version.mjs <major.minor.patch>");
  process.exit(1);
}

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const targets = [
  join(repoRoot, "plugins", "gigapowers", ".claude-plugin", "plugin.json"),
  join(repoRoot, ".claude-plugin", "marketplace.json"),
];

for (const file of targets) {
  const before = readFileSync(file, "utf8");
  const after = before.replace(
    /("version"\s*:\s*)"[^"]*"/g,
    `$1"${version}"`
  );
  if (after === before) {
    console.error(`No "version" key found in ${file}`);
    process.exit(1);
  }
  writeFileSync(file, after);
  console.log(`Updated ${file}`);
}

console.log(`Bumped gigapowers to ${version}.`);
