#!/usr/bin/env node

import fs from "node:fs";

export const upstreamTargets = {
  arm64: {
    arch: "arm64",
    label: "macOS Apple Silicon DMG",
    url: "https://persistent.oaistatic.com/codex-app-prod/Codex.dmg",
  },
  x64: {
    arch: "x64",
    label: "macOS Intel DMG",
    url: "https://persistent.oaistatic.com/codex-app-prod/Codex-latest-x64.dmg",
  },
};

export function normalizeArch(input = process.arch) {
  if (input === "x64" || input === "amd64" || input === "x86_64") {
    return "x64";
  }
  if (input === "arm64" || input === "aarch64") {
    return "arm64";
  }
  throw new Error(`Unsupported architecture: ${input}`);
}

export function parseHeaders(rawHeaders) {
  const headers = new Map();
  for (const line of rawHeaders.split(/\r?\n/)) {
    const separator = line.indexOf(":");
    if (separator === -1) {
      continue;
    }
    const key = line.slice(0, separator).trim().toLowerCase();
    const value = line.slice(separator + 1).trim();
    if (key) {
      headers.set(key, value);
    }
  }
  return {
    etag: headers.get("etag") || null,
    lastModified: headers.get("last-modified") || null,
    contentLength: Number(headers.get("content-length") || 0) || null,
    contentType: headers.get("content-type") || null,
  };
}

export async function fetchMetadata({ arch, url }) {
  const response = await fetch(url, { method: "HEAD", redirect: "follow" });
  if (!response.ok) {
    throw new Error(`HEAD ${url} failed with ${response.status} ${response.statusText}`);
  }

  return {
    arch,
    url: response.url,
    etag: response.headers.get("etag"),
    lastModified: response.headers.get("last-modified"),
    contentLength: Number(response.headers.get("content-length") || 0) || null,
    contentType: response.headers.get("content-type"),
  };
}

function readJson(path) {
  try {
    return JSON.parse(fs.readFileSync(path, "utf8"));
  } catch {
    return null;
  }
}

function materiallyEqual(left, right) {
  if (!left || !right) {
    return false;
  }
  const keys = ["arch", "url", "etag", "lastModified", "contentLength", "contentType"];
  return keys.every((key) => String(left[key] || "") === String(right[key] || ""));
}

function parseArgs(argv) {
  const args = {
    arch: normalizeArch(process.arch),
    url: "",
    output: "",
    write: false,
    fixture: "",
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    switch (arg) {
      case "--arch":
        args.arch = normalizeArch(argv[++index]);
        break;
      case "--url":
        args.url = argv[++index];
        break;
      case "--output":
        args.output = argv[++index];
        break;
      case "--write":
        args.write = true;
        break;
      case "--fixture":
        args.fixture = argv[++index];
        break;
      case "-h":
      case "--help":
        console.log("Usage: upstream-metadata.mjs [--arch x64|arm64] [--url URL] [--output PATH] [--write] [--fixture HEADERS]");
        process.exit(0);
        break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const target = upstreamTargets[args.arch];
  const url = args.url || target.url;
  const metadata = args.fixture
    ? { arch: args.arch, url, ...parseHeaders(fs.readFileSync(args.fixture, "utf8")) }
    : await fetchMetadata({ arch: args.arch, url });

  if (args.output) {
    const previous = readJson(args.output);
    if (args.write && materiallyEqual(previous, metadata)) {
      return;
    }
    fs.writeFileSync(args.output, `${JSON.stringify(metadata, null, 2)}\n`);
    return;
  }

  process.stdout.write(`${JSON.stringify(metadata, null, 2)}\n`);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}
