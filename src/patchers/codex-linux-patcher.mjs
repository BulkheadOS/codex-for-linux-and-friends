#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const marker = "codexForLinuxPatched";

function exists(filePath) {
  return fs.existsSync(filePath);
}

function read(filePath) {
  return fs.readFileSync(filePath, "utf8");
}

function write(filePath, source) {
  fs.writeFileSync(filePath, source, "utf8");
}

function warn(message) {
  console.warn(`WARN: ${message}`);
}

function replaceOnce(source, search, replacement, label) {
  if (!source.includes(search)) {
    warn(`Could not find ${label}; leaving this patch out.`);
    return source;
  }
  return source.replace(search, replacement);
}

function patchPackageJson(root) {
  const packageJsonPath = path.join(root, "package.json");
  if (!exists(packageJsonPath)) {
    warn("package.json not found.");
    return;
  }

  const packageJson = JSON.parse(read(packageJsonPath));
  let changed = false;

  if (packageJson.desktopName !== "codex-for-linux.desktop") {
    packageJson.desktopName = "codex-for-linux.desktop";
    changed = true;
  }

  packageJson.codexForLinux = {
    ...(packageJson.codexForLinux || {}),
    unofficialCompatibilityLayer: true,
  };
  changed = true;

  if (changed) {
    write(packageJsonPath, `${JSON.stringify(packageJson, null, 2)}\n`);
  }
}

function patchBetterSqlite(root) {
  const filePath = path.join(root, "node_modules", "better-sqlite3", "lib", "database.js");
  if (!exists(filePath)) {
    warn(`better-sqlite3 loader not found: ${filePath}`);
    return;
  }

  let source = read(filePath);
  if (source.includes("codexForLinuxResolveNative")) {
    return;
  }

  source = replaceOnce(
    source,
    "let DEFAULT_ADDON;\n",
    [
      "let DEFAULT_ADDON;",
      "const codexForLinuxResolveNative = (inputPath) => inputPath.includes(`${require('path').sep}app.asar${require('path').sep}`)",
      "\t? inputPath.replace(`${require('path').sep}app.asar${require('path').sep}`, `${require('path').sep}app.asar.unpacked${require('path').sep}`)",
      "\t: inputPath;",
      "",
    ].join("\n"),
    "better-sqlite3 insertion point",
  );

  source = replaceOnce(
    source,
    "addon = DEFAULT_ADDON || (DEFAULT_ADDON = require('bindings')('better_sqlite3.node'));",
    [
      "const requireFunc = typeof __non_webpack_require__ === 'function' ? __non_webpack_require__ : require;",
      "\t\tconst nativeModulePath = codexForLinuxResolveNative(require('path').join(__dirname, '..', 'build', 'Release', 'better_sqlite3.node'));",
      "\t\ttry {",
      "\t\t\taddon = DEFAULT_ADDON || (DEFAULT_ADDON = requireFunc(nativeModulePath));",
      "\t\t} catch (directRequireError) {",
      "\t\t\taddon = DEFAULT_ADDON || (DEFAULT_ADDON = require('bindings')('better_sqlite3.node'));",
      "\t\t}",
    ].join("\n"),
    "better-sqlite3 native binding require",
  );

  write(filePath, source);
}

function patchNodePty(root) {
  const filePath = path.join(root, "node_modules", "node-pty", "lib", "utils.js");
  if (!exists(filePath)) {
    warn(`node-pty loader not found: ${filePath}`);
    return;
  }

  let source = read(filePath);
  if (source.includes("codexForLinuxResolveNative")) {
    return;
  }

  source = replaceOnce(
    source,
    "Object.defineProperty(exports, \"__esModule\", { value: true });\nexports.loadNativeModule = exports.assign = void 0;\n",
    [
      "Object.defineProperty(exports, \"__esModule\", { value: true });",
      "exports.loadNativeModule = exports.assign = void 0;",
      "var path = require(\"path\");",
      "var codexForLinuxResolveNative = function (inputPath) {",
      "  return inputPath.includes(\"/app.asar/\") ? inputPath.replace(\"/app.asar/\", \"/app.asar.unpacked/\") : inputPath;",
      "};",
      "",
    ].join("\n"),
    "node-pty insertion point",
  );

  source = replaceOnce(
    source,
    "                return { dir: dir, module: require(dir + \"/\" + name + \".node\") };",
    [
      "                var nativeModulePath = codexForLinuxResolveNative(path.join(__dirname, dir, name + \".node\"));",
      "                return { dir: dir, module: require(nativeModulePath) };",
    ].join("\n"),
    "node-pty native binding require",
  );

  write(filePath, source);
}

function jsFiles(directory) {
  if (!exists(directory)) {
    return [];
  }

  const result = [];
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      result.push(...jsFiles(entryPath));
    } else if (entry.isFile() && entry.name.endsWith(".js")) {
      result.push(entryPath);
    }
  }
  return result;
}

function patchOwlFeatureFallback(root) {
  const buildDir = path.join(root, ".vite", "build");
  const bootstrapPath = path.join(buildDir, "bootstrap.js");

  if (!exists(bootstrapPath)) {
    warn("bootstrap.js not found for OWL feature fallback.");
    return;
  }

  const usesOwl = jsFiles(buildDir).some((filePath) => read(filePath).includes("electron_common_owl_features"));
  if (!usesOwl) {
    return;
  }

  let source = read(bootstrapPath);
  const fallbackMarker = `${marker}OwlFeatures`;
  if (source.includes(fallbackMarker)) {
    return;
  }

  const fallback = `(() => {
  const fallbackMarker = "${fallbackMarker}";
  if (process[fallbackMarker]) return;
  process[fallbackMarker] = true;
  const originalLinkedBinding = process._linkedBinding;
  const disabledState = { enabledFeatureNames: [], disabledFeatureNames: [] };
  const disabledFeatures = new Proxy({
    getState: () => disabledState,
    isEnabled: () => false,
    isOwlFeatureEnabled: () => false,
    setFeatureNames: () => disabledState,
  }, { get: (target, property) => property in target ? target[property] : () => false });
  process._linkedBinding = function codexForLinuxLinkedBinding(name) {
    if (name === "electron_common_owl_features") return disabledFeatures;
    return originalLinkedBinding.call(process, name);
  };
})();

`;

  write(bootstrapPath, `${fallback}${source}`);
}

function patchWindowHints(root) {
  const buildDir = path.join(root, ".vite", "build");
  const webviewAssets = path.join(root, "webview", "assets");
  const mainBundle = exists(buildDir)
    ? fs.readdirSync(buildDir).find((name) => /^main(?:-[^.]+)?\.js$/.test(name))
    : null;
  const iconAsset = exists(webviewAssets)
    ? fs.readdirSync(webviewAssets).find((name) => /^app-.*\.png$/.test(name))
    : null;

  if (!mainBundle || !iconAsset) {
    warn("Main bundle or icon asset not found for Linux window hints.");
    return;
  }

  const filePath = path.join(buildDir, mainBundle);
  let source = read(filePath);
  if (source.includes(`${marker}WindowHints`)) {
    return;
  }

  const iconExpression = `require("node:path").join(process.resourcesPath,"..","content","webview","assets","${iconAsset}")`;
  const replacementComment = `/* ${marker}WindowHints */`;

  source = source.replaceAll("process.platform===`win32`", "(process.platform===`win32`||process.platform===`linux`)");

  const readyNeedle = "D.once(`ready-to-show`,()=>{";
  if (source.includes(readyNeedle) && !source.includes("D.setIcon(")) {
    source = source.replace(readyNeedle, `process.platform===\`linux\`&&D.setIcon(${iconExpression}),${readyNeedle}`);
  }

  if (!source.includes(replacementComment)) {
    source = `${replacementComment}\n${source}`;
  }

  write(filePath, source);
}

export function patchCodexForLinux(root) {
  patchPackageJson(root);
  patchBetterSqlite(root);
  patchNodePty(root);
  patchOwlFeatureFallback(root);
  patchWindowHints(root);
}

function main() {
  const root = process.argv[2];
  if (!root) {
    console.error("Usage: codex-linux-patcher.mjs <extracted-app-asar-dir>");
    process.exit(1);
  }
  patchCodexForLinux(root);
  console.log(`Patched Codex bundle for Linux compatibility: ${root}`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}
