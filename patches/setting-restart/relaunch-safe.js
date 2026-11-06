/**
 * dsh-setting-restart — local relaunch helper (dsh 0.2.0-rc.2, port-safe).
 *
 * WHY THIS REPLACES THE SHIPPED relaunch.js
 * -----------------------------------------
 * The shipped helper waits for the old process to disappear with
 * `process.kill(pid, 0)` and then immediately respawns. On Windows that is not
 * enough: the old process can report "not alive" while its listening socket on
 * 127.0.0.1:3080 is still held, and the freshly spawned instance then dies with
 * `listen EADDRINUSE: address already in use 127.0.0.1:3080`. Because the
 * webserver is a *required* plugin, that single bind failure cascades: 13 other
 * plugins stay "waiting for services (webServer)" and the boot is reported as
 * "3 required plugins did not activate" — exactly the failure seen on
 * 2026-10-10. A second cause of the same symptom is two launchers racing (the
 * helper plus a manual restart script) starting two hosts at once.
 *
 * This helper fixes both: it waits for the process to exit AND for the port to
 * become bindable, fails closed if the port never frees, and records its result
 * so a failed relaunch leaves evidence instead of a silent dead service.
 *
 * Usage: node relaunch-safe.js <json-payload> | b64:<payload> | - (stdin)
 * Payload: { pid, execPath, argv, cwd, port?, timeoutMs?, pollMs?, logFile? }
 */
import { spawn } from "node:child_process";
import { createServer } from "node:net";
import { appendFileSync } from "node:fs";

let raw;
if (process.argv[2] === "-") {
  raw = await new Promise((resolve) => {
    let data = "";
    process.stdin.setEncoding("utf8");
    process.stdin.on("data", (chunk) => {
      data += chunk;
    });
    process.stdin.on("end", () => resolve(data));
  });
} else if (typeof process.argv[2] === "string" && process.argv[2].startsWith("b64:")) {
  raw = Buffer.from(process.argv[2].slice(4), "base64").toString("utf8");
} else {
  raw = process.argv[2];
}

const payload = JSON.parse(raw);
const { pid, execPath, argv, cwd } = payload;
if (
  !Number.isInteger(pid) ||
  typeof execPath !== "string" ||
  !Array.isArray(argv) ||
  argv.length === 0 ||
  typeof cwd !== "string"
) {
  console.error("[relaunch-safe] malformed payload");
  process.exit(1);
}

const port = Number.isInteger(payload.port) ? payload.port : 3080;
const timeoutMs = Number.isFinite(payload.timeoutMs) ? payload.timeoutMs : 60000;
const pollMs = Number.isFinite(payload.pollMs) && payload.pollMs > 0 ? payload.pollMs : 300;
const logFile = typeof payload.logFile === "string" ? payload.logFile : null;

const note = (message) => {
  const line = `[${new Date().toISOString()}] ${message}\n`;
  if (logFile) {
    try {
      appendFileSync(logFile, line);
    } catch {
      // Logging must never be the reason a restart fails.
    }
  }
};

/** Is the old process gone? (Windows-safe.) */
const alive = (target) => {
  try {
    process.kill(target, 0);
    return true;
  } catch {
    return false;
  }
};

/** Can a fresh server bind the port right now? */
const portFree = () =>
  new Promise((resolve) => {
    const probe = createServer();
    probe.once("error", () => resolve(false));
    probe.once("listening", () => probe.close(() => resolve(true)));
    probe.listen(port, "127.0.0.1");
  });

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const deadline = Date.now() + timeoutMs;
let sawExit = false;
let sawFreePort = false;

while (Date.now() < deadline) {
  const gone = !alive(pid);
  if (gone) sawExit = true;
  // Check the port even before the pid disappears: the listener can be the last
  // thing a dying process releases.
  if (await portFree()) {
    sawFreePort = true;
    // Hold the port briefly so nothing else can grab it first, then release and
    // spawn. A same-instant duplicate launcher cannot win the race.
    await sleep(400);
    if ((await portFree()) && !alive(pid)) break;
  }
  await sleep(pollMs);
}

if (!sawFreePort) {
  note(`ABORT: 127.0.0.1:${port} never became bindable within ${timeoutMs}ms (old pid ${pid} alive=${alive(pid)}); refusing to start a second host`);
  console.error(`[relaunch-safe] port ${port} never freed; not relaunching`);
  process.exit(1);
}
if (alive(pid)) {
  note(`ABORT: old pid ${pid} still alive after ${timeoutMs}ms; refusing to start a second host`);
  console.error(`[relaunch-safe] old process ${pid} still alive; not relaunching`);
  process.exit(1);
}

note(`relaunching: pid ${pid} gone, port ${port} free`);
const child = spawn(execPath, argv, {
  cwd,
  detached: true,
  stdio: "ignore",
  windowsHide: true,
  env: process.env,
});
child.unref();
note(`spawned new host pid ${child.pid}`);
process.exit(0);
