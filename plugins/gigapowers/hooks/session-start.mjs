#!/usr/bin/env node
// Cross-platform launcher for the gigapowers SessionStart hook.
// On Windows it dispatches the PowerShell hook (detached, non-blocking).
// On macOS/Linux it is currently a clean no-op -- the bash port is planned
// (see README "Requirements"). Either way it never blocks or fails the session.
import { spawn } from "node:child_process";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

try {
  if (process.platform === "win32") {
    const here = dirname(fileURLToPath(import.meta.url));
    const ps1 = join(here, "session-start.ps1");
    const child = spawn(
      "powershell",
      ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1],
      { detached: true, stdio: "ignore" }
    );
    child.unref();
  }
} catch {
  // Never block or fail the session over a hook-launch error.
}
process.exit(0);
