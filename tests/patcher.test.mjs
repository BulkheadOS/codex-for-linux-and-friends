import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { patchCodexForLinux } from "../src/patchers/codex-linux-patcher.mjs";

function writeFile(filePath, source) {
  fs.mkdirSync(path.dirname(filePath), { recursive: true });
  fs.writeFileSync(filePath, source);
}

function fixture() {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "codex-linux-patcher-"));
  writeFile(path.join(root, "package.json"), JSON.stringify({ name: "Codex", version: "1.2.3" }));
  writeFile(
    path.join(root, "node_modules/better-sqlite3/lib/database.js"),
    "let DEFAULT_ADDON;\nfunction load(){\n\t\taddon = DEFAULT_ADDON || (DEFAULT_ADDON = require('bindings')('better_sqlite3.node'));\n}\n",
  );
  writeFile(
    path.join(root, "node_modules/node-pty/lib/utils.js"),
    [
      "Object.defineProperty(exports, \"__esModule\", { value: true });",
      "exports.loadNativeModule = exports.assign = void 0;",
      "function load(dir,name){",
      "                return { dir: dir, module: require(dir + \"/\" + name + \".node\") };",
      "}",
      "",
    ].join("\n"),
  );
  writeFile(path.join(root, ".vite/build/bootstrap.js"), "process._linkedBinding('electron_common_owl_features');\n");
  writeFile(path.join(root, ".vite/build/main.js"), "process.platform===`win32`;D.once(`ready-to-show`,()=>{});\n");
  writeFile(path.join(root, "webview/assets/app-test.png"), "");
  return root;
}

test("patches package metadata and native module loaders", async () => {
  const root = fixture();
  await patchCodexForLinux(root, { isTest: true });

  const packageJson = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8"));
  assert.equal(packageJson.desktopName, "codex-for-linux.desktop");
  assert.equal(packageJson.codexForLinux.unofficialCompatibilityLayer, true);

  const betterSqlite = fs.readFileSync(path.join(root, "node_modules/better-sqlite3/lib/database.js"), "utf8");
  assert.match(betterSqlite, /app\.asar\.unpacked/);
  assert.match(betterSqlite, /codexForLinuxResolveNative/);

  const nodePty = fs.readFileSync(path.join(root, "node_modules/node-pty/lib/utils.js"), "utf8");
  assert.match(nodePty, /app\.asar\.unpacked/);
  assert.match(nodePty, /codexForLinuxResolveNative/);
});

test("patcher is idempotent for marker-based patches", async () => {
  const root = fixture();
  await patchCodexForLinux(root, { isTest: true });
  await patchCodexForLinux(root, { isTest: true });

  const bootstrap = fs.readFileSync(path.join(root, ".vite/build/bootstrap.js"), "utf8");
  const matches = bootstrap.match(/codexForLinuxPatchedOwlFeatures/g) || [];
  assert.equal(matches.length, 1);

  const main = fs.readFileSync(path.join(root, ".vite/build/main.js"), "utf8");
  const markerMatches = main.match(/codexForLinuxPatchedWindowHints/g) || [];
  assert.equal(markerMatches.length, 1);
});
