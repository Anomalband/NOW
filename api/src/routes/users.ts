import type { FastifyPluginAsync } from "fastify";
import { z } from "zod";
import { prisma } from "../db.js";

const createUserBodySchema = z.object({
  displayName: z.string().trim().min(2).max(40),
  age: z.number().int().min(18).max(99),
  city: z.string().trim().min(2).max(40).optional(),
});

export const userRoutes: FastifyPluginAsync = async (app) => {
  app.post("/users", async (request, reply) => {
    const parsed = createUserBodySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({
        error: "Invalid body",
        details: parsed.error.issues,
      });
    }

    const user = await prisma.user.create({
      data: {
        displayName: parsed.data.displayName,
        age: parsed.data.age,
        city: parsed.data.city ?? "Istanbul",
      },
      select: {
        id: true,
        displayName: true,
        age: true,
        city: true,
        karma: true,
        createdAt: true,
      },
    });

    return reply.code(201).send(user);
  });

  app.get("/users/:id", async (request, reply) => {
    const paramsSchema = z.object({ id: z.string().min(1) });
    const parsed = paramsSchema.safeParse(request.params);

    if (!parsed.success) {
      return reply.code(400).send({
        error: "Invalid user id",
      });
    }

    const user = await prisma.user.findUnique({
      where: { id: parsed.data.id },
      select: {
        id: true,
        displayName: true,
        age: true,
        city: true,
        karma: true,
        createdAt: true,
      },
    });

    if (!user) {
      return reply.code(404).send({ error: "User not found" });
    }

    return reply.send(user);
  });

  app.get("/users/:id/karma-history", async (request, reply) => {
    const paramsSchema = z.object({ id: z.string().min(1) });
    const querySchema = z.object({
      limit: z.coerce.number().int().min(1).max(200).default(50),
    });

    const parsedParams = paramsSchema.safeParse(request.params);
    const parsedQuery = querySchema.safeParse(request.query);

    if (!parsedParams.success || !parsedQuery.success) {
      return reply.code(400).send({
        error: "Invalid request",
      });
    }

    const user = await prisma.user.findUnique({
      where: { id: parsedParams.data.id },
      select: { id: true, karma: true },
    });

    if (!user) {
      return reply.code(404).send({ error: "User not found" });
    }

    const events = await prisma.karmaEvent.findMany({
      where: { userId: parsedParams.data.id },
      orderBy: { createdAt: "desc" },
      take: parsedQuery.data.limit,
      select: {
        id: true,
        delta: true,
        reason: true,
        matchId: true,
        metadata: true,
        createdAt: true,
      },
    });

    return reply.send({
      karma: user.karma,
      count: events.length,
      data: events,
    });
  });
};
