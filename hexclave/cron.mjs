// Calls Hexclave's internal maintenance endpoints, as the self-hosting guide asks
// ("configure exactly one scheduler"). One loop per container, talking to the local backend.
const base = `http://127.0.0.1:${process.env.BACKEND_PORT || "8102"}`;
const secret = process.env.CRON_SECRET;
const qstash = !!(process.env.HEXCLAVE_QSTASH_TOKEN || process.env.STACK_QSTASH_TOKEN);

if (!secret) {
  console.error("[cron] CRON_SECRET is not set; maintenance jobs are disabled.");
  setInterval(() => {}, 1 << 30);
} else {
  const jobs = [
    // Sends queued emails (verification, password reset, invitations).
    { path: "/api/latest/internal/email-queue-step?only_one_step=true", everyMs: 10_000 },
    // Advances workflows (event dispatch, runs, schedules).
    { path: "/api/latest/internal/workflow-engine-step?only_one_step=true", everyMs: 10_000 },
  ];
  if (qstash) {
    // External DB sync (ClickHouse analytics mirrors) needs QStash; enabled only when it is configured.
    jobs.push({ path: "/api/latest/internal/external-db-sync/sequencer", everyMs: 60_000 });
    jobs.push({ path: "/api/latest/internal/external-db-sync/poller", everyMs: 60_000 });
  }
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const run = async (job) => {
    let failures = 0;
    for (;;) {
      try {
        const res = await fetch(base + job.path, { headers: { Authorization: `Bearer ${secret}` }, signal: AbortSignal.timeout(290_000) });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        await res.arrayBuffer();
        if (failures > 0) console.log(`[cron] ${job.path.split("?")[0]} recovered`);
        failures = 0;
      } catch (e) {
        failures++;
        // Quiet while the backend is still migrating on first boot.
        if (failures === 30 || failures % 360 === 0) console.warn(`[cron] ${job.path.split("?")[0]} failing: ${e.message}`);
      }
      await sleep(job.everyMs);
    }
  };
  await sleep(15_000);
  console.log(`[cron] started: ${jobs.map((j) => j.path.split("?")[0]).join(", ")}`);
  await Promise.all(jobs.map(run));
}
