import Fastify from "fastify";
import cors from "@fastify/cors";
import { config } from "./config.js";
import { prisma } from "./db.js";
import { healthRoutes } from "./routes/health.js";
import { userRoutes } from "./routes/users.js";
import { questRoutes } from "./routes/quests.js";
import { dailyProfileRoutes } from "./routes/dailyProfiles.js";
import { questSelectionRoutes } from "./routes/questSelections.js";
import { cleanupRoutes } from "./routes/cleanup.js";
import { matchRoutes } from "./routes/matches.js";

const app = Fastify({
  logger: true,
});

await app.register(cors, {
  origin: config.CORS_ORIGIN === "*" ? true : config.CORS_ORIGIN,
});

await app.register(healthRoutes, { prefix: "/api/v1" });
await app.register(userRoutes, { prefix: "/api/v1" });
await app.register(questRoutes, { prefix: "/api/v1" });
await app.register(dailyProfileRoutes, { prefix: "/api/v1" });
await app.register(questSelectionRoutes, { prefix: "/api/v1" });
await app.register(cleanupRoutes, { prefix: "/api/v1" });
await app.register(matchRoutes, { prefix: "/api/v1" });

app.get("/", async () => {
  return {
    service: "now-api",
    message: "Use /api/v1/health for health check.",
    apiBase: "/api/v1",
    timestamp: new Date().toISOString(),
  };
});

app.get("/api/v1", async () => {
  return {
    service: "now-api",
    message: "API base is active. Try /api/v1/health.",
    health: "/api/v1/health",
    timestamp: new Date().toISOString(),
  };
});

app.setErrorHandler((error, _request, reply) => {
  app.log.error(error);
  reply.code(500).send({
    error: "Internal server error",
  });
});

const closeSignals: NodeJS.Signals[] = ["SIGINT", "SIGTERM"];
for (const signal of closeSignals) {
  process.on(signal, async () => {
    app.log.info(`Received ${signal}, shutting down...`);
    await app.close();
    await prisma.$disconnect();
    process.exit(0);
  });
}

try {
  await app.listen({
    host: config.HOST,
    port: config.PORT,
  });
} catch (error) {
  app.log.error(error);
  await prisma.$disconnect();
  process.exit(1);
}
