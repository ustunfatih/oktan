import { app, monthlyPriceCheck } from "./app";
import type { Env } from "./env";

export default {
  fetch: app.fetch,
  scheduled(_controller, env, ctx) {
    ctx.waitUntil(monthlyPriceCheck(env));
  },
} satisfies ExportedHandler<Env>;
