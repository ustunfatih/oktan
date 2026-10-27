import { app, monthlyPriceCheck } from "./app";
import type { Env } from "./env";
import { dailyCheck } from "./reminders";

const qatarToday = () => new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Qatar" }).format(new Date());

export default {
  fetch: app.fetch,
  scheduled(controller, env, ctx) {
    if (controller.cron === "0 5 * * *") {
      // Daily: fill-up reminders and the key-rotation notice. Errors are logged, never thrown into the cron.
      ctx.waitUntil(
        dailyCheck(env, qatarToday()).then(
          (r) => console.log(JSON.stringify({ event: "daily_check", ...r })),
          (e) => console.error(JSON.stringify({ event: "daily_check", ok: false, message: e instanceof Error ? e.message : String(e) })),
        ),
      );
      return;
    }
    ctx.waitUntil(monthlyPriceCheck(env));
  },
} satisfies ExportedHandler<Env>;
