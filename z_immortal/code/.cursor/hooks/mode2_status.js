#!/usr/bin/env node
/**
 * Mode-2 human-readable status board.
 * Writes .cursor/mode2-STATUS.md so the user can see WORKING/PAUSED/EXPIRED/IDLE.
 * Called from arm/disarm/stop hooks.
 */
const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "../..");
const MARKER = path.join(ROOT, ".cursor", "mode2-session.json");
const NEXT = path.join(ROOT, ".cursor", "mode2-next.md");
const STATUS = path.join(ROOT, ".cursor", "mode2-STATUS.md");

function readNext() {
  if (!fs.existsSync(NEXT)) return "(none)";
  try {
    const line = fs.readFileSync(NEXT, "utf8").trim().split(/\r?\n/)[0];
    return line || "(none)";
  } catch (_) {
    return "(none)";
  }
}

function fmtLocal(sec) {
  try {
    return new Date(sec * 1000).toLocaleString("zh-CN", { hour12: false });
  } catch (_) {
    return String(sec);
  }
}

function writeStatus(state, note) {
  const now = Date.now() / 1000;
  let remaining = "-";
  let endsLabel = "-";
  let hours = "-";
  if (fs.existsSync(MARKER)) {
    try {
      const sess = JSON.parse(fs.readFileSync(MARKER, "utf8"));
      const endsAt = Number(sess.ends_at || 0);
      hours = String(sess.hours ?? "-");
      endsLabel = fmtLocal(endsAt);
      const left = Math.max(0, (endsAt - now) / 3600);
      remaining = left.toFixed(2) + " h";
      if (state === "working" && now >= endsAt) state = "expired";
    } catch (_) {}
  }

  const label =
    state === "working"
      ? "WORKING"
      : state === "paused"
        ? "PAUSED"
        : state === "expired"
          ? "EXPIRED"
          : "IDLE";

  const lines = [
    "# Mode-2 Status",
    "",
    "**Status: " + label + "**",
    "",
    "- Remaining: " + remaining,
    "- Planned hours: " + hours,
    "- Ends at: " + endsLabel,
    "- Current focus: " + readNext(),
    "- Updated: " + fmtLocal(now),
    "",
  ];
  if (note) {
    lines.push("> " + note, "");
  }
  lines.push(
    "---",
    "Send `2` to start · Send `3` / `stop` / `0` to pause.",
    "Open this file anytime to see if Mode-2 is running.",
    ""
  );
  fs.mkdirSync(path.dirname(STATUS), { recursive: true });
  fs.writeFileSync(STATUS, lines.join("\n"), "utf8");
}

module.exports = { writeStatus, STATUS };

if (require.main === module) {
  const arg = process.argv[2] || "idle";
  const note = process.argv.slice(3).join(" ") || "";
  writeStatus(arg, note);
}