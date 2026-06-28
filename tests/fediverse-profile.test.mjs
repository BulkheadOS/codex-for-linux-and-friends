import test from "node:test";
import assert from "node:assert/strict";
import {
  DEFAULT_PROFILES,
  checkProfile,
  checkProfiles,
  main,
} from "../scripts/verify-fediverse-profiles.mjs";

function response(body, { status = 200, contentType = "application/json" } = {}) {
  return {
    ok: status >= 200 && status < 300,
    status,
    headers: {
      get(name) {
        return name.toLowerCase() === "content-type" ? contentType : "";
      },
    },
    async text() {
      return typeof body === "string" ? body : JSON.stringify(body);
    },
  };
}

function makeFetch(routes) {
  return async (url, options = {}) => {
    const key = `${options.method || "GET"} ${url}`;
    const route = routes[key] || routes[`GET ${url}`];
    if (!route) {
      throw new Error(`unexpected fetch ${key}`);
    }
    return typeof route === "function" ? route(url, options) : route;
  };
}

const electricProfile = DEFAULT_PROFILES.find((profile) => profile.host === "electrictown.ie");
const coolockProfile = DEFAULT_PROFILES.find((profile) => profile.host === "coolockvillage.ie");

function profileFixture(profile) {
  if (profile.host === "coolockvillage.ie") {
    return {
      name: "Coolock Village",
      summary: "Community services, events, and local discovery for Coolock Village.",
      iconUrl: "https://coolockvillage.ie/images/coolock_village_logo.png",
      profilePath: "@coolockvillage",
    };
  }

  return {
    name: "ElectricTown",
    summary: "Ireland-focused open-home hardware and local AI labs.",
    iconUrl: "https://electrictown.ie/icon-512.png",
    profilePath: "@electrictown",
  };
}

function mastodonSearchUrl(profile, instance = "mastodon.social") {
  const handle = `${profile.username}@${profile.host}`;
  return `https://${instance}/api/v2/search?q=${encodeURIComponent(`@${handle}`)}&type=accounts`;
}

function baseRoutes({
  profile = electricProfile,
  mastodonAccount,
  mastodonInstance = "mastodon.social",
  actorOverrides = {},
  iconHeadStatus = 200,
}) {
  const handle = `${profile.username}@${profile.host}`;
  const actorUrl = `https://${profile.host}/ap/actor`;
  const fixture = profileFixture(profile);
  return {
    [`GET https://${profile.host}/.well-known/webfinger?resource=acct:${encodeURIComponent(handle)}`]: response({
      subject: `acct:${handle}`,
      links: [
        {
          rel: "self",
          type: "application/activity+json",
          href: actorUrl,
        },
        {
          rel: "http://webfinger.net/rel/profile-page",
          type: "text/html",
          href: `https://${profile.host}/${fixture.profilePath}`,
        },
      ],
    }),
    [`GET ${actorUrl}`]: response({
      type: "Organization",
      preferredUsername: profile.username,
      name: fixture.name,
      summary: fixture.summary,
      icon: { url: fixture.iconUrl },
      inbox: `https://${profile.host}/ap/inbox`,
      outbox: `https://${profile.host}/ap/outbox`,
      publicKey: { id: `${actorUrl}#main-key` },
      ...actorOverrides,
    }),
    [`HEAD ${fixture.iconUrl}`]: response("", {
      status: iconHeadStatus,
      contentType: iconHeadStatus >= 200 && iconHeadStatus < 300 ? "image/png" : "text/plain",
    }),
    [`GET ${fixture.iconUrl}`]: response("", {
      contentType: "image/png",
    }),
    [`GET ${mastodonSearchUrl(profile, mastodonInstance)}`]: response({
      accounts: mastodonAccount ? [mastodonAccount] : [],
      statuses: [],
      hashtags: [],
    }),
  };
}

test("passes direct checks and exact Mastodon account cache", async () => {
  const result = await checkProfile(electricProfile, {
    fetchImpl: makeFetch(
      baseRoutes({
        mastodonAccount: {
          acct: "electrictown@electrictown.ie",
          display_name: "ElectricTown",
          uri: "https://electrictown.ie/ap/actor",
          avatar: "https://files.mastodon.social/cache/electrictown.png",
          header: "https://files.mastodon.social/cache/electrictown-header.png",
          fields: [{ name: "Website", value: "electrictown.ie" }],
        },
      }),
    ),
  });

  assert.equal(result.ok, true);
  assert.equal(result.webfinger.status, "pass");
  assert.equal(result.actor.status, "pass");
  assert.equal(result.icon.status, "pass");
  assert.equal(result.mastodon.status, "pass");
  assert.equal(result.mastodon.returnedAcct, "electrictown@electrictown.ie");
});

test("falls back to ranged GET when icon HEAD is rejected", async () => {
  const result = await checkProfile(electricProfile, {
    fetchImpl: makeFetch(
      baseRoutes({
        iconHeadStatus: 405,
        mastodonAccount: {
          acct: "electrictown@electrictown.ie",
          display_name: "ElectricTown",
          uri: "https://electrictown.ie/ap/actor",
          avatar: "https://files.mastodon.social/cache/electrictown.png",
          fields: [],
        },
      }),
    ),
  });

  assert.equal(result.ok, true);
  assert.equal(result.icon.status, "pass");
  assert.equal(result.icon.method, "GET");
});

test("warns on Mastodon cache account mismatch without failing direct checks", async () => {
  const result = await checkProfile(electricProfile, {
    fetchImpl: makeFetch(
      baseRoutes({
        mastodonAccount: {
          acct: "Dublin@electrictown.ie",
          display_name: "ElectricTown",
          uri: "https://electrictown.ie/ap/actor",
          avatar: "https://files.mastodon.social/cache/electrictown.png",
          header: "https://files.mastodon.social/cache/electrictown-header.png",
          fields: [],
        },
      }),
    ),
  });

  assert.equal(result.ok, true);
  assert.equal(result.mastodon.status, "warning");
  assert.match(result.mastodon.failures[0], /expected acct electrictown@electrictown.ie/);
});

test("strict Mastodon mode fails on account mismatch", async () => {
  const result = await checkProfile(electricProfile, {
    strictMastodon: true,
    fetchImpl: makeFetch(
      baseRoutes({
        mastodonAccount: {
          acct: "Dublin@electrictown.ie",
          display_name: "ElectricTown",
          uri: "https://electrictown.ie/ap/actor",
          avatar: "https://files.mastodon.social/cache/electrictown.png",
          fields: [],
        },
      }),
    ),
  });

  assert.equal(result.ok, false);
  assert.equal(result.mastodon.status, "warning");
});

test("uses the configured Mastodon instance for account search", async () => {
  const result = await checkProfile(electricProfile, {
    mastodonInstance: "mastodon.example",
    fetchImpl: makeFetch(
      baseRoutes({
        mastodonInstance: "mastodon.example",
        mastodonAccount: {
          acct: "electrictown@electrictown.ie",
          display_name: "ElectricTown",
          uri: "https://electrictown.ie/ap/actor",
          avatar: "https://files.mastodon.example/cache/electrictown.png",
          fields: [],
        },
      }),
    ),
  });

  assert.equal(result.ok, true);
  assert.equal(result.mastodon.instance, "mastodon.example");
  assert.match(result.mastodon.searchUrl, /^https:\/\/mastodon\.example\/api\/v2\/search/);
  assert.equal(result.mastodon.status, "pass");
});

test("strict Mastodon mode fails when the configured instance is blocked", async () => {
  const routes = baseRoutes({
    mastodonInstance: "mastodon.org",
    mastodonAccount: {
      acct: "electrictown@electrictown.ie",
      display_name: "ElectricTown",
      uri: "https://electrictown.ie/ap/actor",
      avatar: "https://files.mastodon.example/cache/electrictown.png",
      fields: [],
    },
  });
  routes["GET https://mastodon.org/api/v2/search?q=%40electrictown%40electrictown.ie&type=accounts"] = async () => {
    throw new TypeError("fetch failed", { cause: new Error("tlsv1 alert internal error") });
  };

  const result = await checkProfile(electricProfile, {
    mastodonInstance: "mastodon.org",
    strictMastodon: true,
    fetchImpl: makeFetch(routes),
  });

  assert.equal(result.ok, false);
  assert.equal(result.mastodon.status, "blocked");
  assert.match(result.mastodon.failures.join("\n"), /fetch failed: tlsv1 alert internal error/);
  assert.doesNotMatch(result.mastodon.failures[0], /\n/);
});

test("fails when direct actor icon is missing", async () => {
  const routes = baseRoutes({
    mastodonAccount: {
      acct: "electrictown@electrictown.ie",
      display_name: "ElectricTown",
      uri: "https://electrictown.ie/ap/actor",
      avatar: "https://files.mastodon.social/cache/electrictown.png",
      fields: [],
    },
  });
  routes["GET https://electrictown.ie/ap/actor"] = response({
    type: "Organization",
    preferredUsername: "electrictown",
    name: "ElectricTown",
    summary: "Ireland-focused open-home hardware and local AI labs.",
    inbox: "https://electrictown.ie/ap/inbox",
    outbox: "https://electrictown.ie/ap/outbox",
    publicKey: { id: "https://electrictown.ie/ap/actor#main-key" },
  });

  const result = await checkProfile(electricProfile, {
    fetchImpl: makeFetch(routes),
  });

  assert.equal(result.ok, false);
  assert.equal(result.actor.status, "fail");
  assert.match(result.actor.failures.join("\n"), /missing icon URL/);
});

test("fails when actor type is not Organization", async () => {
  const result = await checkProfile(electricProfile, {
    fetchImpl: makeFetch(
      baseRoutes({
        actorOverrides: { type: "Person" },
        mastodonAccount: {
          acct: "electrictown@electrictown.ie",
          display_name: "ElectricTown",
          uri: "https://electrictown.ie/ap/actor",
          avatar: "https://files.mastodon.social/cache/electrictown.png",
          fields: [],
        },
      }),
    ),
  });

  assert.equal(result.ok, false);
  assert.match(result.actor.failures.join("\n"), /type mismatch: expected Organization, got Person/);
});

test("default profiles cover the public organization handles", () => {
  assert.deepEqual(
    DEFAULT_PROFILES.map((profile) => profile.expectedAcct),
    ["coolockvillage@coolockvillage.ie", "electrictown@electrictown.ie"],
  );
});

test("checkProfiles aggregates defaults and tolerates a non-strict Mastodon cache mismatch", async () => {
  const routes = {
    ...baseRoutes({
      profile: coolockProfile,
      mastodonAccount: {
        acct: "Dublin@coolockvillage.ie",
        display_name: "Coolock Village",
        uri: "https://coolockvillage.ie/ap/actor",
        avatar: "https://files.mastodon.social/cache/coolock.png",
        header: "https://files.mastodon.social/cache/coolock-header.png",
        fields: [{ name: "Website", value: "coolockvillage.ie" }],
      },
    }),
    ...baseRoutes({
      profile: electricProfile,
      mastodonAccount: {
        acct: "electrictown@electrictown.ie",
        display_name: "ElectricTown",
        uri: "https://electrictown.ie/ap/actor",
        avatar: "https://files.mastodon.social/cache/electrictown.png",
        header: "https://files.mastodon.social/cache/electrictown-header.png",
        fields: [{ name: "Website", value: "electrictown.ie" }],
      },
    }),
  };

  const result = await checkProfiles({ fetchImpl: makeFetch(routes) });

  assert.equal(result.ok, true);
  assert.equal(result.profiles.length, 2);
  const coolock = result.profiles.find((profile) => profile.handle === "coolockvillage@coolockvillage.ie");
  const electricTown = result.profiles.find((profile) => profile.handle === "electrictown@electrictown.ie");
  assert.equal(coolock.mastodon.status, "warning");
  assert.equal(electricTown.mastodon.status, "pass");
});

test("main returns default and strict exit codes for current cache semantics", async () => {
  const routes = {
    ...baseRoutes({
      profile: coolockProfile,
      mastodonAccount: {
        acct: "Dublin@coolockvillage.ie",
        display_name: "Coolock Village",
        uri: "https://coolockvillage.ie/ap/actor",
        avatar: "https://files.mastodon.social/cache/coolock.png",
        fields: [],
      },
    }),
    ...baseRoutes({
      profile: electricProfile,
      mastodonAccount: {
        acct: "electrictown@electrictown.ie",
        display_name: "ElectricTown",
        uri: "https://electrictown.ie/ap/actor",
        avatar: "https://files.mastodon.social/cache/electrictown.png",
        fields: [],
      },
    }),
  };

  const originalFetch = globalThis.fetch;
  const originalLog = console.log;
  const output = [];
  globalThis.fetch = makeFetch(routes);
  console.log = (...args) => output.push(args.join(" "));
  try {
    assert.equal(await main(["--json"]), 0);
    assert.equal(await main(["--strict-mastodon", "--json"]), 1);
  } finally {
    globalThis.fetch = originalFetch;
    console.log = originalLog;
  }
  assert.match(output.join("\n"), /coolockvillage@coolockvillage\.ie/);
});
