#!/usr/bin/env node
import { fileURLToPath } from "node:url";

export const OPENAI_FEATURE_DOCS = [
  {
    id: "codex-app-platforms",
    label: "Codex app desktop platforms",
    url: "https://developers.openai.com/codex/quickstart",
    expectedStatus: "not-claimed-on-linux",
    requiredEvidence: [
      /The Codex app is available on macOS and Windows/i,
      /Download the Codex app for macOS or Windows/i,
    ],
    ignoreLinuxEvidence: [
      /Get notified for Linux/i,
      /Codex CLI is supported on macOS, Windows, and Linux/i,
      /Install the Codex CLI on macOS or Linux/i,
      /standalone installer.*Linux/i,
    ],
  },
  {
    id: "appshots",
    label: "Appshots",
    url: "https://developers.openai.com/codex/appshots",
    expectedStatus: "not-claimed-on-linux",
    requiredEvidence: [
      /Appshots are available in the Codex app on macOS/i,
      /Create them from the Codex app on macOS/i,
    ],
  },
  {
    id: "computer-use",
    label: "Computer Use",
    url: "https://developers.openai.com/codex/app/computer-use",
    expectedStatus: "not-claimed-on-linux",
    requiredEvidence: [
      /computer use in the Codex app is available on macOS and Windows/i,
      /Codex can see and operate graphical user interfaces on macOS or Windows/i,
    ],
  },
  {
    id: "automations",
    label: "Automations",
    url: "https://developers.openai.com/codex/app/automations",
    expectedStatus: "requires-local-running-app",
    requiredEvidence: [
      /machine running the local Codex app must be powered on/i,
      /Codex must be running/i,
      /selected project must still be available on disk/i,
    ],
  },
  {
    id: "remote-mobile-hosts",
    label: "Remote/mobile host setup",
    url: "https://developers.openai.com/codex/remote-connections",
    expectedStatus: "not-claimed-on-linux",
    requiredEvidence: [
      /Codex mobile setup supports Codex App hosts on macOS and Windows/i,
      /latest Codex App for macOS or Windows running on a host/i,
    ],
  },
  {
    id: "chronicle",
    label: "Chronicle",
    url: "https://developers.openai.com/codex/memories/chronicle",
    expectedStatus: "not-claimed-on-linux",
    requiredEvidence: [
      /Chronicle is in an opt-in research preview/i,
      /only available for ChatGPT Pro subscribers on macOS/i,
      /requires macOS Screen Recording and Accessibility permissions/i,
    ],
  },
];

function withTimeout(timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  return { controller, timer };
}

function decodeHtml(value) {
  return value
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, "\"")
    .replace(/&#34;/g, "\"")
    .replace(/&#39;/g, "'")
    .replace(/&rsquo;/g, "'")
    .replace(/&ldquo;/g, "\"")
    .replace(/&rdquo;/g, "\"");
}

export function htmlToText(html) {
  return decodeHtml(
    html
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim(),
  )
    .replace(/\s+/g, " ")
    .trim();
}

function splitSentences(text) {
  return text
    .split(/(?<=[.!?])\s+/)
    .map((sentence) => sentence.trim())
    .filter(Boolean);
}

function snippet(value, limit = 220) {
  const compact = value.replace(/\s+/g, " ").trim();
  return compact.length > limit ? `${compact.slice(0, limit - 3)}...` : compact;
}

function requiredEvidenceMatches(text, patterns) {
  return patterns.map((pattern) => {
    const match = text.match(pattern);
    return {
      pattern: pattern.source,
      matched: Boolean(match),
      snippet: match ? snippet(match[0]) : null,
    };
  });
}

function linuxSupportSentences(sentences, ignorePatterns = []) {
  return sentences.filter((sentence) => {
    if (!/\bLinux\b/i.test(sentence)) {
      return false;
    }
    if (ignorePatterns.some((pattern) => pattern.test(sentence))) {
      return false;
    }
    if (!/(available|support|supported|download|install|works|runs|computer use|appshots|codex app)/i.test(sentence)) {
      return false;
    }
    return !/(not available|not supported|not claimed|notify|notification|behind a notification)/i.test(sentence);
  });
}

async function fetchText(url, { fetchImpl, timeoutMs }) {
  const { controller, timer } = withTimeout(timeoutMs);
  try {
    const response = await fetchImpl(url, {
      headers: { accept: "text/html,application/xhtml+xml" },
      redirect: "follow",
      signal: controller.signal,
    });
    const body = await response.text();
    return {
      ok: response.ok,
      status: response.status,
      url,
      text: htmlToText(body),
      error: response.ok ? null : `HTTP ${response.status}`,
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      url,
      text: "",
      error: error.name === "AbortError" ? `timeout after ${timeoutMs}ms` : error.message,
    };
  } finally {
    clearTimeout(timer);
  }
}

export async function checkFeatureDoc(feature, options = {}) {
  const fetchImpl = options.fetchImpl || globalThis.fetch;
  if (typeof fetchImpl !== "function") {
    throw new Error("global fetch is unavailable; use Node.js 20+ or pass fetchImpl");
  }

  const timeoutMs = Number(options.timeoutMs || 15000);
  const response = await fetchText(feature.url, { fetchImpl, timeoutMs });
  const evidence = requiredEvidenceMatches(response.text, feature.requiredEvidence);
  const sentences = splitSentences(response.text);
  const linuxSentences = linuxSupportSentences(sentences, feature.ignoreLinuxEvidence || []);
  const failures = [];

  if (!response.ok) {
    failures.push(response.error || `HTTP ${response.status}`);
  }
  for (const match of evidence) {
    if (!match.matched) {
      failures.push(`missing expected docs phrase: ${match.pattern}`);
    }
  }
  if (feature.expectedStatus === "not-claimed-on-linux" && linuxSentences.length > 0) {
    failures.push("official docs now contain possible Linux support wording");
  }

  return {
    id: feature.id,
    label: feature.label,
    url: feature.url,
    ok: failures.length === 0,
    status: failures.length === 0 ? feature.expectedStatus : "unknown",
    expectedStatus: feature.expectedStatus,
    httpStatus: response.status,
    evidence,
    linuxSupportSentences: linuxSentences.map((sentence) => snippet(sentence)),
    failures,
  };
}

export async function checkOpenAIFeatureSupport(options = {}) {
  const features = options.features || OPENAI_FEATURE_DOCS;
  const results = [];
  for (const feature of features) {
    results.push(await checkFeatureDoc(feature, options));
  }

  return {
    ok: results.every((result) => result.ok),
    generatedAt: new Date().toISOString(),
    sourceHost: "developers.openai.com",
    features: results,
  };
}

function printPlain(result) {
  console.log("OpenAI Codex feature support verification");
  console.log("Source: official OpenAI developer docs");
  console.log("Docs can drift; re-run before changing public Linux feature claims.");
  for (const feature of result.features) {
    console.log("");
    console.log(`${feature.label}: ${feature.status}`);
    console.log(`  url: ${feature.url}`);
    for (const failure of feature.failures) {
      console.log(`  - ${failure}`);
    }
    for (const sentence of feature.linuxSupportSentences) {
      console.log(`  possible Linux support wording: ${sentence}`);
    }
  }
}

function parseArgs(argv) {
  const options = {
    json: false,
    timeoutMs: 15000,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--json") {
      options.json = true;
    } else if (arg === "--timeout-ms") {
      index += 1;
      options.timeoutMs = Number(argv[index]);
      if (!Number.isFinite(options.timeoutMs) || options.timeoutMs < 1000) {
        throw new Error("--timeout-ms requires a number >= 1000");
      }
    } else if (arg === "-h" || arg === "--help") {
      options.help = true;
    } else {
      throw new Error(`Unknown option: ${arg}`);
    }
  }

  return options;
}

function usage() {
  return `Usage: node scripts/verify-openai-feature-support.mjs [--json] [--timeout-ms N]

Checks official OpenAI Codex docs for the platform claims this repository uses
when reporting Appshots, Computer Use, Automations, and app-platform support.
No auth tokens, local app launch, or private data are used.
`;
}

export async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  if (options.help) {
    console.log(usage());
    return 0;
  }

  const result = await checkOpenAIFeatureSupport(options);
  if (options.json) {
    console.log(JSON.stringify(result, null, 2));
  } else {
    printPlain(result);
  }

  return result.ok ? 0 : 1;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().then(
    (code) => {
      process.exitCode = code;
    },
    (error) => {
      console.error(error.message);
      process.exitCode = 1;
    },
  );
}
