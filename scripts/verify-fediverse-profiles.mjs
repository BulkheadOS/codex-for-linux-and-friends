#!/usr/bin/env node
import { fileURLToPath } from "node:url";

export const DEFAULT_PROFILES = [
  {
    label: "Coolock Village",
    username: "coolockvillage",
    host: "coolockvillage.ie",
    expectedAcct: "coolockvillage@coolockvillage.ie",
  },
  {
    label: "ElectricTown",
    username: "electrictown",
    host: "electrictown.ie",
    expectedAcct: "electrictown@electrictown.ie",
  },
];

function withTimeout(timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  return { controller, timer };
}

function headerValue(response, name) {
  return response.headers?.get?.(name) || response.headers?.get?.(name.toLowerCase()) || "";
}

async function fetchJson(url, { fetchImpl, timeoutMs, headers = {} }) {
  const { controller, timer } = withTimeout(timeoutMs);
  try {
    const response = await fetchImpl(url, {
      headers,
      signal: controller.signal,
      redirect: "follow",
    });
    const text = await response.text();
    let json = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch (error) {
      return {
        ok: false,
        status: response.status,
        url,
        error: `invalid JSON: ${error.message}`,
      };
    }
    return {
      ok: response.ok,
      status: response.status,
      url,
      json,
      contentType: headerValue(response, "content-type"),
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      url,
      error: error.name === "AbortError" ? `timeout after ${timeoutMs}ms` : error.message,
    };
  } finally {
    clearTimeout(timer);
  }
}

async function fetchStatusRequest(url, { fetchImpl, timeoutMs, method, headers = {} }) {
  const { controller, timer } = withTimeout(timeoutMs);
  try {
    const response = await fetchImpl(url, {
      method,
      headers,
      signal: controller.signal,
      redirect: "follow",
    });
    return {
      ok: response.ok,
      status: response.status,
      url,
      method,
      contentType: headerValue(response, "content-type"),
    };
  } catch (error) {
    return {
      ok: false,
      status: 0,
      url,
      method,
      error: error.name === "AbortError" ? `timeout after ${timeoutMs}ms` : error.message,
    };
  } finally {
    clearTimeout(timer);
  }
}

async function fetchStatus(url, { fetchImpl, timeoutMs }) {
  const headResponse = await fetchStatusRequest(url, { fetchImpl, timeoutMs, method: "HEAD" });
  if (headResponse.ok) {
    return headResponse;
  }

  const getResponse = await fetchStatusRequest(url, {
    fetchImpl,
    timeoutMs,
    method: "GET",
    headers: { range: "bytes=0-0" },
  });

  if (getResponse.ok) {
    return {
      ...getResponse,
      fallbackFrom: {
        method: headResponse.method,
        status: headResponse.status,
        error: headResponse.error || null,
      },
    };
  }

  return {
    ...getResponse,
    fallbackFrom: {
      method: headResponse.method,
      status: headResponse.status,
      error: headResponse.error || null,
    },
  };
}

function firstLink(links, predicate) {
  return Array.isArray(links) ? links.find(predicate) : undefined;
}

function statusFromFailures(failures) {
  return failures.length === 0 ? "pass" : "fail";
}

function accountMatches(account, expectedAcct) {
  return String(account?.acct || "").toLowerCase() === expectedAcct.toLowerCase();
}

function accountMatchesActor(account, actorUrl) {
  return String(account?.uri || "").toLowerCase() === actorUrl.toLowerCase();
}

export async function checkProfile(profile, options = {}) {
  const fetchImpl = options.fetchImpl || globalThis.fetch;
  if (typeof fetchImpl !== "function") {
    throw new Error("global fetch is unavailable; use Node.js 20+ or pass fetchImpl");
  }

  const timeoutMs = Number(options.timeoutMs || 15000);
  const mastodonInstance = options.mastodonInstance || "mastodon.social";
  const expectedAcct = profile.expectedAcct || `${profile.username}@${profile.host}`;
  const handle = `${profile.username}@${profile.host}`;
  const webfingerUrl = `https://${profile.host}/.well-known/webfinger?resource=acct:${encodeURIComponent(handle)}`;

  const webfingerResponse = await fetchJson(webfingerUrl, {
    fetchImpl,
    timeoutMs,
    headers: { accept: "application/jrd+json, application/json" },
  });

  const webfingerFailures = [];
  const webfinger = webfingerResponse.json || {};
  if (!webfingerResponse.ok) {
    webfingerFailures.push(webfingerResponse.error || `HTTP ${webfingerResponse.status}`);
  }
  if (webfinger.subject !== `acct:${handle}`) {
    webfingerFailures.push(`subject mismatch: ${webfinger.subject || "missing"}`);
  }

  const actorLink = firstLink(
    webfinger.links,
    (link) => link.rel === "self" && String(link.type || "").includes("activity"),
  );
  const profileLink = firstLink(
    webfinger.links,
    (link) => link.rel === "http://webfinger.net/rel/profile-page",
  );
  if (!actorLink?.href) {
    webfingerFailures.push("missing ActivityPub self link");
  }
  if (!profileLink?.href) {
    webfingerFailures.push("missing profile-page link");
  }

  const actorUrl = actorLink?.href || `https://${profile.host}/ap/actor`;
  const actorResponse = await fetchJson(actorUrl, {
    fetchImpl,
    timeoutMs,
    headers: {
      accept: "application/activity+json, application/ld+json, application/json",
    },
  });
  const actor = actorResponse.json || {};
  const actorFailures = [];
  const expectedActorType = profile.expectedActorType || "Organization";
  if (!actorResponse.ok) {
    actorFailures.push(actorResponse.error || `HTTP ${actorResponse.status}`);
  }
  if (actor.type !== expectedActorType) {
    actorFailures.push(`type mismatch: expected ${expectedActorType}, got ${actor.type || "missing"}`);
  }
  if (actor.preferredUsername !== profile.username) {
    actorFailures.push(`preferredUsername mismatch: ${actor.preferredUsername || "missing"}`);
  }
  if (!actor.name) {
    actorFailures.push("missing name");
  }
  if (!actor.summary) {
    actorFailures.push("missing summary");
  }
  if (!actor.inbox || !actor.outbox) {
    actorFailures.push("missing inbox/outbox");
  }
  if (!actor.publicKey) {
    actorFailures.push("missing publicKey");
  }

  const iconUrl = typeof actor.icon === "string" ? actor.icon : actor.icon?.url;
  if (!iconUrl) {
    actorFailures.push("missing icon URL");
  }
  const iconResponse = iconUrl
    ? await fetchStatus(iconUrl, { fetchImpl, timeoutMs })
    : { ok: false, status: 0, url: "", error: "missing icon URL" };
  const iconFailures = [];
  if (!iconResponse.ok) {
    iconFailures.push(iconResponse.error || `HTTP ${iconResponse.status}`);
  }

  const mastodonSearchUrl = `https://${mastodonInstance}/api/v2/search?q=${encodeURIComponent(
    `@${handle}`,
  )}&type=accounts`;
  const mastodonResponse = await fetchJson(mastodonSearchUrl, {
    fetchImpl,
    timeoutMs,
    headers: { accept: "application/json" },
  });
  const mastodonJson = mastodonResponse.json || {};
  const accounts = Array.isArray(mastodonJson.accounts) ? mastodonJson.accounts : [];
  const exactAccount = accounts.find((account) => accountMatches(account, expectedAcct));
  const actorAccount = accounts.find((account) => accountMatchesActor(account, actorUrl));
  const selectedAccount = exactAccount || actorAccount || accounts[0] || null;
  let mastodonStatus = "warning";
  const mastodonFailures = [];
  if (!mastodonResponse.ok) {
    mastodonStatus = "blocked";
    mastodonFailures.push(mastodonJson.error || mastodonResponse.error || `HTTP ${mastodonResponse.status}`);
  } else if (!selectedAccount) {
    mastodonFailures.push("no matching account returned");
  } else if (!exactAccount) {
    mastodonFailures.push(`expected acct ${expectedAcct}, got ${selectedAccount.acct || "missing"}`);
  } else {
    mastodonStatus = "pass";
  }

  const directFailures = [...webfingerFailures, ...actorFailures, ...iconFailures];
  const strictMastodon = Boolean(options.strictMastodon);
  const ok = directFailures.length === 0 && (!strictMastodon || mastodonStatus === "pass");

  return {
    label: profile.label,
    handle,
    ok,
    webfinger: {
      status: statusFromFailures(webfingerFailures),
      url: webfingerUrl,
      subject: webfinger.subject || null,
      actorUrl,
      profileUrl: profileLink?.href || null,
      failures: webfingerFailures,
    },
    actor: {
      status: statusFromFailures(actorFailures),
      url: actorUrl,
      type: actor.type || null,
      preferredUsername: actor.preferredUsername || null,
      name: actor.name || null,
      summaryLength: typeof actor.summary === "string" ? actor.summary.length : 0,
      iconUrl: iconUrl || null,
      hasInbox: Boolean(actor.inbox),
      hasOutbox: Boolean(actor.outbox),
      hasPublicKey: Boolean(actor.publicKey),
      failures: actorFailures,
    },
    icon: {
      status: statusFromFailures(iconFailures),
      url: iconUrl || null,
      httpStatus: iconResponse.status,
      method: iconResponse.method || null,
      contentType: iconResponse.contentType || null,
      failures: iconFailures,
    },
    mastodon: {
      status: mastodonStatus,
      instance: mastodonInstance,
      searchUrl: mastodonSearchUrl,
      expectedAcct,
      returnedAcct: selectedAccount?.acct || null,
      displayName: selectedAccount?.display_name || null,
      uri: selectedAccount?.uri || null,
      avatarPresent: Boolean(selectedAccount?.avatar || selectedAccount?.avatar_static),
      headerPresent: Boolean(selectedAccount?.header || selectedAccount?.header_static),
      fieldsCount: Array.isArray(selectedAccount?.fields) ? selectedAccount.fields.length : 0,
      failures: mastodonFailures,
    },
  };
}

export async function checkProfiles(options = {}) {
  const profiles = options.profiles || DEFAULT_PROFILES;
  const results = [];
  for (const profile of profiles) {
    results.push(await checkProfile(profile, options));
  }
  return {
    ok: results.every((result) => result.ok),
    strictMastodon: Boolean(options.strictMastodon),
    mastodonInstance: options.mastodonInstance || "mastodon.social",
    generatedAt: new Date().toISOString(),
    profiles: results,
  };
}

function printPlain(result) {
  console.log("Fediverse profile verification");
  console.log("External services can drift; re-run before making current public claims.");
  console.log(`Mastodon instance: ${result.mastodonInstance}`);
  console.log(`Strict Mastodon cache: ${result.strictMastodon ? "yes" : "no"}`);
  for (const profile of result.profiles) {
    console.log("");
    console.log(`${profile.handle}`);
    console.log(`  webfinger: ${profile.webfinger.status}`);
    console.log(`  actor:     ${profile.actor.status} (${profile.actor.name || "missing name"})`);
    console.log(`  icon:      ${profile.icon.status} (${profile.actor.iconUrl || "missing icon"})`);
    console.log(
      `  mastodon:  ${profile.mastodon.status} expected=${profile.mastodon.expectedAcct} returned=${profile.mastodon.returnedAcct || "none"}`,
    );
    for (const failure of [
      ...profile.webfinger.failures,
      ...profile.actor.failures,
      ...profile.icon.failures,
      ...profile.mastodon.failures,
    ]) {
      console.log(`    - ${failure}`);
    }
  }
}

function parseArgs(argv) {
  const options = {
    json: false,
    strictMastodon: false,
    mastodonInstance: "mastodon.social",
    timeoutMs: 15000,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--json") {
      options.json = true;
    } else if (arg === "--strict-mastodon") {
      options.strictMastodon = true;
    } else if (arg === "--mastodon-instance") {
      index += 1;
      options.mastodonInstance = argv[index];
      if (!options.mastodonInstance) {
        throw new Error("--mastodon-instance requires a host");
      }
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
  return `Usage: node scripts/verify-fediverse-profiles.mjs [--json] [--strict-mastodon] [--mastodon-instance HOST] [--timeout-ms N]

Checks public WebFinger, ActivityPub actor metadata, icon URL reachability, and
an unauthenticated Mastodon instance cache search for the ElectricTown and
Coolock Village organization profiles. No auth tokens or private data are used.
`;
}

export async function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  if (options.help) {
    console.log(usage());
    return 0;
  }

  const result = await checkProfiles(options);
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
