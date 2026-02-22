import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { config } from "../config.js";
import { prisma } from "../db.js";

const cleanupQuerySchema = z.object({
  dryRun: z
    .union([z.literal("true"), z.literal("false"), z.boolean()])
    .optional()
    .transform((value) => value === true || value === "true"),
});

export const cleanupRoutes: FastifyPluginAsync = async (app) => {
  app.post("/admin/cleanup", async (request, reply) => {
    const token = request.headers["x-admin-token"];
    if (token !== config.APP_ADMIN_TOKEN) {
      return reply.code(401).send({ error: "Unauthorized" });
    }

    const parsed = cleanupQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({ error: "Invalid query" });
    }

    const now = new Date();
    const whereExpired = { expiresAt: { lt: now } };

    if (parsed.data.dryRun) {
      const [expiredMessages, expiredMatches, expiredSelections, expiredProfiles] = await Promise.all([
        prisma.message.count({ where: whereExpired }),
        prisma.match.count({ where: whereExpired }),
        prisma.questSelection.count({ where: whereExpired }),
        prisma.dailyProfile.count({ where: whereExpired }),
      ]);

      return reply.send({
        dryRun: true,
        expiredMessages,
        expiredMatches,
        expiredSelections,
        expiredProfiles,
        checkedAt: now.toISOString(),
      });
    }

    const [deletedMessages, deletedMatches, deletedSelections, deletedProfiles] = await prisma.$transaction([
      prisma.message.deleteMany({ where: whereExpired }),
      prisma.match.deleteMany({ where: whereExpired }),
      prisma.questSelection.deleteMany({ where: whereExpired }),
      prisma.dailyProfile.deleteMany({ where: whereExpired }),
    ]);

    return reply.send({
      dryRun: false,
      deletedMessages: deletedMessages.count,
      deletedMatches: deletedMatches.count,
      deletedSelections: deletedSelections.count,
      deletedProfiles: deletedProfiles.count,
      cleanedAt: now.toISOString(),
    });
  });
};
