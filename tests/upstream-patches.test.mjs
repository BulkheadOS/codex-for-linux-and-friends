import assert from "node:assert/strict";
import test from "node:test";
import {
  patchLinuxOpenTargetWorkerSource,
  patchLinuxPrimaryTitlebarSource,
  patchLinuxRecursiveFileWatchSource,
  patchLinuxTitlebarOverlaySyncSource
} from "../src/patchers/upstream-patches.mjs";

const workerOpenTargetFixture = [
  "function K7(e){return e}",
  "function u9(e){return e.pathCommand}",
  "var $ce={id:`vscode`,platforms:{darwin:{label:`VS Code`,icon:`apps/vscode.png`,kind:`editor`,detect:()=>null}}}",
  "function ele(){return u9({pathCommand:K7(`code`),executableName:`Code.exe`,installDirName:`Microsoft VS Code`})}",
  "var tle={id:`vscodeInsiders`,platforms:{darwin:{label:`VS Code Insiders`,icon:`apps/vscode-insiders.png`,kind:`editor`,detect:()=>null}}}",
  "var Gce={id:`systemDefault`,platforms:{linux:{label:`Default app`,icon:`apps/file-explorer.png`,kind:`systemDefault`,hidden:!0,detect:()=>`system-default`}}}",
  "var gle=new Map([$ce,tle,Gce].flatMap(e=>{let t=e.platforms[process.platform];return t==null?[]:[[e.id,{id:e.id,...t}]]}));",
  "function W9(e){let t=gle.get(e);if(t==null)throw Error(`Unknown open target \"${e}\"`);return t}",
  "class OpenInWorker{handleRequest(e){if(e.method===`get-target-command`)return this.getTargetCommand(e.params)}getTargetCommand(e){return W9(e.target).detect()}}"
].join(";");

const primaryTitlebarFixture = [
  "function N9({appearance:e,opaqueWindowSurfaceEnabled:t,platform:n,windowZoom:r=1}){",
  "switch(e){",
  "case`primary`:return n===`darwin`?t?{titleBarStyle:`hiddenInset`,trafficLightPosition:p9(r)}:{vibrancy:`menu`,titleBarStyle:`hiddenInset`,trafficLightPosition:p9(r)}:n===`win32`||n===`linux`?{titleBarStyle:`hidden`,titleBarOverlay:m9(r)}:{titleBarStyle:`default`};",
  "case`secondary`:return{titleBarStyle:`default`}}",
  "}"
].join("");

const titlebarOverlaySyncFixture = [
  "class h9{",
  "setWindowZoom(e,t){let n=a.BrowserWindow.fromWebContents(e);n==null||this.windowAppearances.get(n.id)!==`primary`||(process.platform===`darwin`?n.setWindowButtonPosition(p9(t)):(process.platform===`win32`||process.platform===`linux`)&&(this.windowZooms.set(n.id,t),n.setTitleBarOverlay(m9(t))))}",
  "installApplicationMenuTitleBarOverlaySync(e,t){if(process.platform!==`win32`&&process.platform!==`linux`||t!==`primary`)return;let n=()=>{e.isDestroyed()||e.setTitleBarOverlay(m9(this.windowZooms.get(e.id)))};return a.nativeTheme.on(`updated`,n),n(),()=>{a.nativeTheme.off(`updated`,n)}}",
  "}"
].join("");

const recursiveFileWatchFixture = [
  "class LocalHost{",
  "async startFileWatch(e){",
  "let t=cU(),n=!1,r=await this.platformPath(),i=this.getFileSystemPath(e.path),a=w.default.watch(i,{recursive:e.recursive},(t,n)=>{e.onChange({changedPaths:n==null?[]:[r.join(e.path,n.toString())]})}),o=e=>{n||(n=!0,a.close(),t.resolve(e))};",
  "return a.on(`error`,e=>{o({reason:`watch-error`,error:e})}),{path:e.path,closed:t.promise,dispose:async()=>{o({reason:`disposed`})}}",
  "}",
  "}"
].join("");

test("patches worker-side Linux editor open targets", () => {
  const patched = patchLinuxOpenTargetWorkerSource(workerOpenTargetFixture);

  assert.match(patched, /__codexLinuxWorkerVSCode=/);
  assert.match(patched, /__codexLinuxWorkerCursor=/);
  assert.match(patched, /__codexLinuxWorkerNvim=/);
  assert.match(patched, /detect:\(\)=>K7\(`code`\)/);
  assert.match(
    patched,
    /\[__codexLinuxWorkerVSCode,__codexLinuxWorkerVSCodeInsiders,__codexLinuxWorkerCursor,__codexLinuxWorkerZed,__codexLinuxWorkerNvim,\$ce,tle,Gce\]/
  );
});

test("worker-side Linux open target patch is idempotent", () => {
  const once = patchLinuxOpenTargetWorkerSource(workerOpenTargetFixture);
  const twice = patchLinuxOpenTargetWorkerSource(once);

  assert.equal(twice, once);
  assert.equal((twice.match(/__codexLinuxWorkerVSCode=/g) ?? []).length, 1);
});

test("keeps Linux primary windows on the managed titlebar path", () => {
  const patched = patchLinuxPrimaryTitlebarSource(primaryTitlebarFixture);

  assert.doesNotMatch(patched, /n===`win32`\|\|n===`linux`\?\{titleBarStyle:`hidden`/);
  assert.match(patched, /n===`win32`\?\{titleBarStyle:`hidden`,titleBarOverlay:m9\(r\)\}:\{titleBarStyle:`default`\}/);
});

test("Linux primary titlebar patch is idempotent", () => {
  const once = patchLinuxPrimaryTitlebarSource(primaryTitlebarFixture);
  const twice = patchLinuxPrimaryTitlebarSource(once);

  assert.equal(twice, once);
});

test("keeps Linux out of runtime titlebar overlay sync", () => {
  const patched = patchLinuxTitlebarOverlaySyncSource(titlebarOverlaySyncFixture);

  assert.doesNotMatch(patched, /process\.platform===`win32`\|\|process\.platform===`linux`/);
  assert.doesNotMatch(patched, /process\.platform!==`win32`&&process\.platform!==`linux`/);
  assert.match(patched, /:process\.platform===`win32`&&\(this\.windowZooms\.set/);
  assert.match(patched, /if\(process\.platform!==`win32`\|\|t!==`primary`\)return/);
});

test("Linux titlebar overlay sync patch is idempotent", () => {
  const once = patchLinuxTitlebarOverlaySyncSource(titlebarOverlaySyncFixture);
  const twice = patchLinuxTitlebarOverlaySyncSource(once);

  assert.equal(twice, once);
});

test("disables recursive file watching by default on Linux", () => {
  const patched = patchLinuxRecursiveFileWatchSource(recursiveFileWatchFixture);

  assert.match(patched, /function __codexLinuxRecursiveWatch\(e\)/);
  assert.match(patched, /CODEX_LINUX_RECURSIVE_WATCH/);
  assert.match(patched, /recursive:__codexLinuxRecursiveWatch\(e\.recursive\)/);
  assert.doesNotMatch(patched, /recursive:e\.recursive/);
});

test("Linux recursive file watch patch is idempotent", () => {
  const once = patchLinuxRecursiveFileWatchSource(recursiveFileWatchFixture);
  const twice = patchLinuxRecursiveFileWatchSource(once);

  assert.equal(twice, once);
  assert.equal((twice.match(/__codexLinuxRecursiveWatch/g) ?? []).length, 2);
});
