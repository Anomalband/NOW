import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { prisma } from "../db.js";
import { getIstanbulDayKey, getNextIstanbulMidnight } from "../time.js";

const DATA_IMAGE_URI_REGEX = /^data:image\/[a-zA-Z0-9.+-]+;base64,[A-Za-z0-9+/=]+$/;

function isHttpOrHttpsUrl(value: string): boolean {
  try {
    const parsed = new URL(value);
    return parsed.protocol === "http:" || parsed.protocol === "https:";
  } catch {
    return false;
  }
}

const upsertDailyProfileBodySchema = z.object({
  userId: z.string().min(1),
  photoUrl: z
    .string()
    .trim()
    .min(1)
    .max(2_500_000)
    .refine((value) => isHttpOrHttpsUrl(value) || DATA_IMAGE_URI_REGEX.test(value), {
      message: "photoUrl must be an http(s) URL or a data:image base64 URI",
    }),
  district: z.string().trim().min(2).max(40),
  mood: z.string().trim().max(80).optional(),
});

export const dailyProfileRoutes: FastifyPluginAsync = async (app) => {
  app.post("/daily-profiles", async (request, reply) => {
    const parsed = upsertDailyProfileBodySchema.safeParse(request.body);

    if (!parsed.success) {
      return reply.code(400).send({
        error: "Invalid body",
        details: parsed.error.issues,
      });
    }

    const user = await prisma.user.findUnique({
      where: { id: parsed.data.userId },
      select: { id: true },
    });

    if (!user) {
      return reply.code(404).send({ error: "User not found" });
    }

    const dayKey = getIstanbulDayKey();
    const expiresAt = getNextIstanbulMidnight();

    const profile = await prisma.dailyProfile.upsert({
      where: {
        userId_dayKey: {
          userId: parsed.data.userId,
          dayKey,
        },
      },
      create: {
        userId: parsed.data.userId,
        dayKey,
        photoUrl: parsed.data.photoUrl,
        district: parsed.data.district,
        mood: parsed.data.mood,
        expiresAt,
      },
      update: {
        photoUrl: parsed.data.photoUrl,
        district: parsed.data.district,
        mood: parsed.data.mood,
        expiresAt,
      },
      select: {
        id: true,
        userId: true,
        dayKey: true,
        district: true,
        photoUrl: true,
        mood: true,
        expiresAt: true,
      },
    });

    return reply.code(201).send(profile);
  });
};
