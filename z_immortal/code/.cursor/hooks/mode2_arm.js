#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const { writeStatus } = require("./mode2_status.js");

const ROOT = path.resolve(__dirname, "../..");
const MARKER = path.join(ROOT, ".cursor", "mode2-session.json");
const NEXT = path.join(ROOT, ".cursor", "mode2-next.md");

function parseHours() {
  const idx = process.argv.indexOf("--hours");
  if (idx >= 0 && process.argv[idx + 1]) {
    const n = Number(process.argv[idx + 1]);
    if (Number.isFinite(n)) return n;
  }
  return 8;
}

const hours = Math.max(parseHours(), 0.1);
const now = Date.now() / 1000;
const payload = {
  armed_at: now,
  ends_at: now + hours * 3600,
  hours,
  project: "tongxuan",
};

fs.mkdirSync(path.dirname(MARKER), { recursive: true });
fs.writeFileSync(MARKER, JSON.stringify(payload, null, 2) + "\n", "utf8");
if (!fs.existsSync(NEXT)) {
  fs.writeFileSync(NEXT, "next: combat feel + early stage pacing\n", "utf8");
}
writeStatus("working", "Mode-2 started. Autonomously polishing.");
console.log("MODE2_ARMED ends_at=" + Math.floor(payload.ends_at) + " hours=" + hours);