import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { prisma } from "../db.js";
import { getIstanbulDayKey, getNextIstanbulMidnight } from "../time.js";

const selectQuestBodySchema = z.object({
  userId: z.string().min(1),
  questId: z.string().min(1),
});

export const questSelectionRoutes: FastifyPluginAsync = async (app) => {
  app.post("/quest-selections", async (request, reply) => {
    const parsed = selectQuestBodySchema.safeParse(request.body);

    if (!parsed.success) {
      return reply.code(400).send({
        error: "Invalid body",
        details: parsed.error.issues,
      });
    }

    const [user, quest] = await Promise.all([
      prisma.user.findUnique({
        where: { id: parsed.data.userId },
        select: { id: true },
      }),
      prisma.quest.findUnique({
        where: { id: parsed.data.questId },
        select: { id: true, active: true },
      }),
    ]);

    if (!user) {
      return reply.code(404).send({ error: "User not found" });
    }

    if (!quest || !quest.active) {
      return reply.code(404).send({ error: "Quest not found or inactive" });
    }

    const dayKey = getIstanbulDayKey();
    const expiresAt = getNextIstanbulMidnight();

    const selection = await prisma.questSelection.upsert({
      where: {
        userId_dayKey: {
          userId: parsed.data.userId,
          dayKey,
        },
      },
      create: {
        userId: parsed.data.userId,
        questId: parsed.data.questId,
        dayKey,
        expiresAt,
      },
      update: {
        questId: parsed.data.questId,
        expiresAt,
      },
      select: {
        id: true,
        userId: true,
        questId: true,
        dayKey: true,
        selectedAt: true,
        expiresAt: true,
      },
    });

    return reply.code(201).send(selection);
  });
};

