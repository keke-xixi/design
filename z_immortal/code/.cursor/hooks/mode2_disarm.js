#!/usr/bin/env node
const fs = require("fs");
const path = require("path");
const { writeStatus } = require("./mode2_status.js");

const ROOT = path.resolve(__dirname, "../..");
const MARKER = path.join(ROOT, ".cursor", "mode2-session.json");

if (fs.existsSync(MARKER)) {
  fs.unlinkSync(MARKER);
  writeStatus("paused", "Mode-2 paused. Send 2 to start again.");
  console.log("MODE2_DISARMED");
} else {
  writeStatus("idle", "No Mode-2 session.");
  console.log("MODE2_ALREADY_OFF");
}