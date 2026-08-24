import { cleanupThreshold } from "./day";
import { handleReact } from "./react";
import type { Env } from "./types";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === "POST" && url.pathname === "/react") {
      return handleReact(request, env);
    }
    return new Response("Not found", { status: 404 });
  },

  // Очистка счётчиков старше 7 суток — contracts/react-api.md §7, research.md R10.
  async scheduled(_event: ScheduledController, env: Env, _ctx: ExecutionContext): Promise<void> {
    const threshold = cleanupThreshold(new Date());
    await env.DB.prepare("DELETE FROM rate_limits WHERE day < ?1").bind(threshold).run();
    await env.DB.prepare("DELETE FROM global_limits WHERE day < ?1").bind(threshold).run();
  },
} satisfies ExportedHandler<Env>;
