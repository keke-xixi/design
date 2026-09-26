#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const { writeStatus } = require("./mode2_status.js");

const ROOT = path.resolve(__dirname, "../..");
const MARKER = path.join(ROOT, ".cursor", "mode2-session.json");
const NEXT = path.join(ROOT, ".cursor", "mode2-next.md");

function out(obj) {
  process.stdout.write(JSON.stringify(obj));
}

function main() {
  let payload = {};
  try {
    const raw = fs.readFileSync(0, "utf8");
    if (raw.trim()) payload = JSON.parse(raw);
  } catch (_) {
    out({});
    return;
  }

  const status = String(payload.status || payload.reason || "").toLowerCase();
  if (["aborted", "error", "cancelled", "canceled"].includes(status)) {
    out({});
    return;
  }

  if (!fs.existsSync(MARKER)) {
    out({});
    return;
  }

  let sess;
  try {
    sess = JSON.parse(fs.readFileSync(MARKER, "utf8"));
  } catch (_) {
    out({});
    return;
  }

  const endsAt = Number(sess.ends_at || 0);
  const now = Date.now() / 1000;
  if (now >= endsAt) {
    try {
      fs.unlinkSync(MARKER);
    } catch (_) {}
    writeStatus("expired", "8h finished. Send 2 to start another round.");
    out({});
    return;
  }

  const remainingH = Math.max(0, (endsAt - now) / 3600);
  let nextHint = "rotate: fun / beauty / combat / maps / early retention";
  if (fs.existsSync(NEXT)) {
    try {
      const line = fs.readFileSync(NEXT, "utf8").trim().split(/\r?\n/)[0];
      if (line) nextHint = line;
    } catch (_) {}
  }

  writeStatus("working", "Continuing. Remaining ~" + remainingH.toFixed(2) + "h");

  const msg =
    "Mode-2 continue: do not ask user. Read and follow `.cursor/skills/tongxuan-mode-2/SKILL.md`. " +
    "Update .cursor/mode2-STATUS.md to WORKING. Remaining ~" +
    remainingH.toFixed(2) +
    "h. Focus: " +
    nextHint +
    ". Keep going; no commit/push.";
  out({ followup_message: msg });
}

main();