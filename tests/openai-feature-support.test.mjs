import test from "node:test";
import assert from "node:assert/strict";
import {
  OPENAI_FEATURE_DOCS,
  checkFeatureDoc,
  checkOpenAIFeatureSupport,
  htmlToText,
  main,
} from "../scripts/verify-openai-feature-support.mjs";

function response(body, { status = 200 } = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    async text() {
      return body;
    },
  };
}

function makeFetch(routes) {
  return async (url) => {
    const route = routes[url];
    if (!route) {
      throw new Error(`unexpected fetch ${url}`);
    }
    return typeof route === "function" ? route(url) : route;
  };
}

function fixtureFor(feature) {
  if (feature.id === "codex-app-platforms") {
    return `
      <main>
        <p>The Codex app is available on macOS and Windows.</p>
        <p>Download the Codex app for macOS or Windows.</p>
      </main>
    `;
  }
  if (feature.id === "appshots") {
    return `
      <main>
        <p>Appshots are available in the Codex app on macOS.</p>
        <p>Create them from the Codex app on macOS.</p>
      </main>
    `;
  }
  if (feature.id === "computer-use") {
    return `
      <main>
        <p>Computer use in the Codex app is available on macOS and Windows.</p>
        <p>Codex can see and operate graphical user interfaces on macOS or Windows.</p>
      </main>
    `;
  }
  if (feature.id === "automations") {
    return `
      <main>
        <p>For project-scoped automations, the machine running the local Codex app must be powered on.</p>
        <p>Codex must be running.</p>
        <p>The selected project must still be available on disk.</p>
      </main>
    `;
  }
  if (feature.id === "remote-mobile-hosts") {
    return `
      <main>
        <p>Codex mobile setup supports Codex App hosts on macOS and Windows.</p>
        <p>The latest Codex App for macOS or Windows running on a host that is awake, online, and signed in.</p>
      </main>
    `;
  }
  return `
    <main>
      <p>Chronicle is in an opt-in research preview.</p>
      <p>It is only available for ChatGPT Pro subscribers on macOS.</p>
      <p>It requires macOS Screen Recording and Accessibility permissions.</p>
    </main>
  `;
}

function allExpectedRoutes(overrides = {}) {
  return Object.fromEntries(
    OPENAI_FEATURE_DOCS.map((feature) => [
      feature.url,
      response(overrides[feature.id] || fixtureFor(feature)),
    ]),
  );
}

test("htmlToText strips scripts and decodes common entities", () => {
  const text = htmlToText("<main>A&amp;B&nbsp;<script>Linux supported</script><p>Codex</p></main>");

  assert.equal(text, "A&B Codex");
});

test("classifies current OpenAI docs wording as not claimed on Linux where expected", async () => {
  const result = await checkOpenAIFeatureSupport({
    fetchImpl: makeFetch(allExpectedRoutes()),
  });

  assert.equal(result.ok, true);
  assert.equal(result.sourceHost, "developers.openai.com");
  assert.deepEqual(
    result.features.map((feature) => [feature.id, feature.status]),
    [
      ["codex-app-platforms", "not-claimed-on-linux"],
      ["appshots", "not-claimed-on-linux"],
      ["computer-use", "not-claimed-on-linux"],
      ["automations", "requires-local-running-app"],
      ["remote-mobile-hosts", "not-claimed-on-linux"],
      ["chronicle", "not-claimed-on-linux"],
    ],
  );
});

test("fails closed when a required official docs phrase disappears", async () => {
  const feature = OPENAI_FEATURE_DOCS.find((candidate) => candidate.id === "appshots");
  const result = await checkFeatureDoc(feature, {
    fetchImpl: makeFetch({
      [feature.url]: response("<main><p>Appshots work differently now.</p></main>"),
    }),
  });

  assert.equal(result.ok, false);
  assert.equal(result.status, "unknown");
  assert.match(result.failures.join("\n"), /missing expected docs phrase/);
});

test("fails closed when official docs appear to claim Linux support", async () => {
  const feature = OPENAI_FEATURE_DOCS.find((candidate) => candidate.id === "computer-use");
  const result = await checkFeatureDoc(feature, {
    fetchImpl: makeFetch({
      [feature.url]: response(`
        <main>
          <p>Computer use in the Codex app is available on macOS and Windows.</p>
          <p>Codex can see and operate graphical user interfaces on macOS or Windows.</p>
          <p>Computer Use is now supported on Linux.</p>
        </main>
      `),
    }),
  });

  assert.equal(result.ok, false);
  assert.equal(result.status, "unknown");
  assert.match(result.failures.join("\n"), /possible Linux support wording/);
  assert.deepEqual(result.linuxSupportSentences, ["Computer Use is now supported on Linux."]);
});

test("ignores quickstart Linux notification and CLI wording", async () => {
  const feature = OPENAI_FEATURE_DOCS.find((candidate) => candidate.id === "codex-app-platforms");
  const result = await checkFeatureDoc(feature, {
    fetchImpl: makeFetch({
      [feature.url]: response(`
        <main>
          <p>The Codex app is available on macOS and Windows.</p>
          <p>Download the Codex app for macOS or Windows.</p>
          <p>Download for Windows. Get notified for Linux.</p>
          <p>The Codex CLI is supported on macOS, Windows, and Linux.</p>
        </main>
      `),
    }),
  });

  assert.equal(result.ok, true);
  assert.deepEqual(result.linuxSupportSentences, []);
});

test("does not let CLI wording hide desktop app Linux support", async () => {
  const feature = OPENAI_FEATURE_DOCS.find((candidate) => candidate.id === "codex-app-platforms");
  const result = await checkFeatureDoc(feature, {
    fetchImpl: makeFetch({
      [feature.url]: response(`
        <main>
          <p>The Codex app is available on macOS and Windows.</p>
          <p>Download the Codex app for macOS or Windows.</p>
          <p>The Codex app is now supported on Linux, while the Codex CLI remains supported.</p>
        </main>
      `),
    }),
  });

  assert.equal(result.ok, false);
  assert.match(result.linuxSupportSentences.join("\n"), /Codex app is now supported on Linux/);
});

test("fails closed when Chronicle docs appear to claim Linux support", async () => {
  const feature = OPENAI_FEATURE_DOCS.find((candidate) => candidate.id === "chronicle");
  const result = await checkFeatureDoc(feature, {
    fetchImpl: makeFetch({
      [feature.url]: response(`
        <main>
          <p>Chronicle is in an opt-in research preview.</p>
          <p>It is only available for ChatGPT Pro subscribers on macOS.</p>
          <p>It requires macOS Screen Recording and Accessibility permissions.</p>
          <p>Chronicle is available in the Codex app on Linux.</p>
        </main>
      `),
    }),
  });

  assert.equal(result.ok, false);
  assert.match(result.linuxSupportSentences.join("\n"), /Chronicle is available in the Codex app on Linux/);
});

test("main returns nonzero when docs no longer match repo expectations", async () => {
  const originalFetch = globalThis.fetch;
  const originalLog = console.log;
  const output = [];
  globalThis.fetch = makeFetch(
    allExpectedRoutes({
      appshots: "<main><p>Appshots are available in Codex on every desktop Linux session.</p></main>",
    }),
  );
  console.log = (...args) => output.push(args.join(" "));
  try {
    assert.equal(await main(["--json"]), 1);
  } finally {
    globalThis.fetch = originalFetch;
    console.log = originalLog;
  }
  assert.match(output.join("\n"), /appshots/);
});
