import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { normalizeArch, parseHeaders } from "../lib/upstream-metadata.mjs";

test("normalizes Linux architecture names", () => {
  assert.equal(normalizeArch("x86_64"), "x64");
  assert.equal(normalizeArch("amd64"), "x64");
  assert.equal(normalizeArch("aarch64"), "arm64");
});

test("parses relevant HTTP headers", () => {
  const parsed = parseHeaders([
    "HTTP/2 200",
    "content-type: application/x-apple-diskimage",
    "content-length: 488624725",
    "last-modified: Sat, 27 Jun 2026 05:16:09 GMT",
    "etag: 0x8DED40B32FC93A1",
    "",
  ].join("\n"));

  assert.equal(parsed.contentType, "application/x-apple-diskimage");
  assert.equal(parsed.contentLength, 488624725);
  assert.equal(parsed.lastModified, "Sat, 27 Jun 2026 05:16:09 GMT");
  assert.equal(parsed.etag, "0x8DED40B32FC93A1");
});

test("fixture mode writes deterministic metadata", async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "codex-linux-metadata-"));
  const fixture = path.join(dir, "headers.txt");
  const output = path.join(dir, "metadata.json");
  fs.writeFileSync(fixture, "content-length: 123\netag: abc\nlast-modified: today\n");

  const { spawnSync } = await import("node:child_process");
  const result = spawnSync(process.execPath, [
    "lib/upstream-metadata.mjs",
    "--arch",
    "x64",
    "--url",
    "https://example.test/Codex.dmg",
    "--fixture",
    fixture,
    "--output",
    output,
  ], { encoding: "utf8" });

  assert.equal(result.status, 0, result.stderr);
  const metadata = JSON.parse(fs.readFileSync(output, "utf8"));
  assert.equal(metadata.arch, "x64");
  assert.equal(metadata.url, "https://example.test/Codex.dmg");
  assert.equal(metadata.contentLength, 123);
});
