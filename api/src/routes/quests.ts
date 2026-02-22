import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { prisma } from "../db.js";
import { config } from "../config.js";

const listQuestQuerySchema = z.object({
  district: z.string().trim().min(2).max(40).optional(),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

const createQuestBodySchema = z.object({
  title: z.string().trim().min(5).max(120),
  district: z.string().trim().min(2).max(40),
  active: z.boolean().optional(),
});

export const questRoutes: FastifyPluginAsync = async (app) => {
  app.get("/quests", async (request, reply) => {
    const parsed = listQuestQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({
        error: "Invalid query",
        details: parsed.error.issues,
      });
    }

    const quests = await prisma.quest.findMany({
      where: {
        active: true,
        district: parsed.data.district,
      },
      orderBy: [{ district: "asc" }, { createdAt: "desc" }],
      take: parsed.data.limit,
      select: {
        id: true,
        title: true,
        district: true,
        active: true,
      },
    });

    return reply.send({
      count: quests.length,
      data: quests,
    });
  });

  app.post("/quests", async (request, reply) => {
    const adminToken = request.headers["x-admin-token"];
    if (adminToken !== config.APP_ADMIN_TOKEN) {
      return reply.code(401).send({ error: "Unauthorized" });
    }

    const parsed = createQuestBodySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({
        error: "Invalid body",
        details: parsed.error.issues,
      });
    }

    const quest = await prisma.quest.upsert({
      where: {
        title_district: {
          title: parsed.data.title,
          district: parsed.data.district,
        },
      },
      create: {
        title: parsed.data.title,
        district: parsed.data.district,
        active: parsed.data.active ?? true,
      },
      update: {
        active: parsed.data.active ?? true,
      },
      select: {
        id: true,
        title: true,
        district: true,
        active: true,
      },
    });

    return reply.code(201).send(quest);
  });
};

