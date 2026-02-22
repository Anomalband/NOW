import { MatchStatus } from "@prisma/client";
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

const userIdQuerySchema = z.object({
  userId: z.string().min(1),
});

const listMatchesQuerySchema = z.object({
  userId: z.string().min(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
});

const findOrCreateBodySchema = z.object({
  userId: z.string().min(1),
});

const matchIdParamsSchema = z.object({
  id: z.string().min(1),
});

const listMessagesQuerySchema = z.object({
  userId: z.string().min(1),
  limit: z.coerce.number().int().min(1).max(500).default(200),
});

const sendMessageBodySchema = z.object({
  senderId: z.string().min(1),
  content: z.string().trim().min(1).max(500),
});

const submitProofBodySchema = z.object({
  userId: z.string().min(1),
  photoUrl: z
    .string()
    .trim()
    .min(1)
    .max(2_500_000)
    .refine((value) => isHttpOrHttpsUrl(value) || DATA_IMAGE_URI_REGEX.test(value), {
      message: "photoUrl must be an http(s) URL or a data:image base64 URI",
    }),
});

const completeBodySchema = z.object({
  userId: z.string().min(1),
});

const activeMatchStatuses = [MatchStatus.PENDING, MatchStatus.ACCEPTED] as const;
const candidateBusyErrorCode = "CANDIDATE_BUSY";

function isMatchParticipant(
  match: {
    userAId: string;
    userBId: string;
  },
  userId: string,
): boolean {
  return match.userAId === userId || match.userBId === userId;
}

export const matchRoutes: FastifyPluginAsync = async (app) => {
  app.get("/matches", async (request, reply) => {
    const parsed = listMatchesQuerySchema.safeParse(request.query);
    if (!parsed.success) {
      return reply.code(400).send({
        error: "Invalid query",
        details: parsed.error.issues,
      });
    }

    const now = new Date();
    const matches = await prisma.match.findMany({
      where: {
        OR: [{ userAId: parsed.data.userId }, { userBId: parsed.data.userId }],
        expiresAt: { gt: now },
      },
      orderBy: [{ status: "asc" }, { createdAt: "desc" }],
      take: parsed.data.limit,
      include: {
        quest: {
          select: {
            id: true,
            title: true,
            district: true,
          },
        },
        userA: {
          select: {
            id: true,
            displayName: true,
            age: true,
            city: true,
            karma: true,
          },
        },
        userB: {
          select: {
            id: true,
            displayName: true,
            age: true,
            city: true,
            karma: true,
          },
        },
        messages: {
          orderBy: { createdAt: "desc" },
          take: 1,
          select: {
            id: true,
            senderId: true,
            content: true,
            createdAt: true,
          },
        },
      },
    });

    return reply.send({
      count: matches.length,
      data: matches.map((match) => {
        const isUserA = match.userAId === parsed.data.userId;
        const partner = isUserA ? match.userB : match.userA;
        const lastMessage = match.messages[0] ?? null;

        return {
          id: match.id,
          status: match.status,
          createdAt: match.createdAt,
          expiresAt: match.expiresAt,
          completedAt: match.completedAt,
          quest: match.quest,
          partner,
          proof: {
            mine: isUserA ? match.proofPhotoA : match.proofPhotoB,
            partner: isUserA ? match.proofPhotoB : match.proofPhotoA,
            mineSubmittedAt: isUserA ? match.proofSubmittedAAt : match.proofSubmittedBAt,
            partnerSubmittedAt: isUserA ? match.proofSubmittedBAt : match.proofSubmittedAAt,
          },
          confirmation: {
            mine: isUserA ? match.confirmedByAAt : match.confirmedByBAt,
            partner: isUserA ? match.confirmedByBAt : match.confirmedByAAt,
          },
          lastMessage,
        };
      }),
    });
  });

  app.post("/matches/find-or-create", async (request, reply) => {
    const parsed = findOrCreateBodySchema.safeParse(request.body);
    if (!parsed.success) {
      return reply.code(400).send({
        error: "Invalid body",
        details: parsed.error.issues,
      });
    }

    const userId = parsed.data.userId;
    const now = new Date();
    const dayKey = getIstanbulDayKey();
    const expiresAt = getNextIstanbulMidnight();

    const [user, mySelection, myProfile] = await Promise.all([
      prisma.user.findUnique({
        where: { id: userId },
        select: { id: true },
      }),
      prisma.questSelection.findUnique({
        where: {
          userId_dayKey: {
            userId,
            dayKey,
          },
        },
        select: {
          questId: true,
        },
      }),
      prisma.dailyProfile.findUnique({
        where: {
          userId_dayKey: {
            userId,
            dayKey,
          },
        },
        select: {
          id: true,
        },
      }),
    ]);

    if (!user) {
      return reply.code(404).send({ error: "User not found" });
    }
    if (!mySelection) {
      return reply.code(400).send({ error: "Select a quest first" });
    }
    if (!myProfile) {
      return reply.code(400).send({ error: "Publish daily profile first" });
    }

    const existingForUser = await prisma.match.findFirst({
      where: {
        OR: [{ userAId: userId }, { userBId: userId }],
        status: { in: [...activeMatchStatuses] },
        expiresAt: { gt: now },
      },
      include: {
        quest: {
          select: {
            id: true,
            title: true,
            district: true,
          },
        },
        userA: {
          select: {
            id: true,
            displayName: true,
            age: true,
            city: true,
            karma: true,
          },
        },
        userB: {
          select: {
            id: true,
            displayName: true,
            age: true,
            city: true,
            karma: true,
          },
        },
      },
    });

    if (existingForUser) {
      return reply.send({
        created: false,
        matched: true,
        data: existingForUser,
      });
    }

    const candidateSelections = await prisma.questSelection.findMany({
      where: {
        questId: mySelection.questId,
        dayKey,
        userId: { not: userId },
        expiresAt: { gt: now },
      },
      orderBy: { selectedAt: "asc" },
      select: {
        userId: true,
      },
    });

    let candidateUserId: string | null = null;
    for (const candidate of candidateSelections) {
      const [candidateProfile, pairMatch, candidateActiveMatch] = await Promise.all([
        prisma.dailyProfile.findUnique({
          where: {
            userId_dayKey: {
              userId: candidate.userId,
              dayKey,
            },
          },
          select: { id: true },
        }),
        prisma.match.findFirst({
          where: {
            questId: mySelection.questId,
            expiresAt: { gt: now },
            OR: [
              { userAId: userId, userBId: candidate.userId },
              { userAId: candidate.userId, userBId: userId },
            ],
          },
          select: { id: true },
        }),
        prisma.match.findFirst({
          where: {
            OR: [{ userAId: candidate.userId }, { userBId: candidate.userId }],
            status: { in: [...activeMatchStatuses] },
            expiresAt: { gt: now },
          },
          select: { id: true },
        }),
      ]);

      if (!candidateProfile) {
        continue;
      }
      if (pairMatch) {
        continue;
      }
      if (candidateActiveMatch) {
        continue;
      }

      candidateUserId = candidate.userId;
      break;
    }

    if (!candidateUserId) {
      return reply.send({
        created: false,
        matched: false,
        data: null,
        message: "No candidate found yet",
      });
    }

    const matchResult = await prisma
      .$transaction(async (tx) => {
        const requesterRaceMatch = await tx.match.findFirst({
          where: {
            OR: [{ userAId: userId }, { userBId: userId }],
            status: { in: [...activeMatchStatuses] },
            expiresAt: { gt: new Date() },
          },
          include: {
            quest: {
              select: {
                id: true,
                title: true,
                district: true,
              },
            },
            userA: {
              select: {
                id: true,
                displayName: true,
                age: true,
                city: true,
                karma: true,
              },
            },
            userB: {
              select: {
                id: true,
                displayName: true,
                age: true,
                city: true,
                karma: true,
              },
            },
          },
        });
        if (requesterRaceMatch) {
          return {
            created: false,
            data: requesterRaceMatch,
          };
        }

        const pairMatch = await tx.match.findFirst({
          where: {
            questId: mySelection.questId,
            expiresAt: { gt: new Date() },
            OR: [
              { userAId: userId, userBId: candidateUserId },
              { userAId: candidateUserId, userBId: userId },
            ],
          },
          include: {
            quest: {
              select: {
                id: true,
                title: true,
                district: true,
              },
            },
            userA: {
              select: {
                id: true,
                displayName: true,
                age: true,
                city: true,
                karma: true,
              },
            },
            userB: {
              select: {
                id: true,
                displayName: true,
                age: true,
                city: true,
                karma: true,
              },
            },
          },
        });
        if (pairMatch) {
          return {
            created: false,
            data: pairMatch,
          };
        }

        const candidateRaceMatch = await tx.match.findFirst({
          where: {
            OR: [{ userAId: candidateUserId }, { userBId: candidateUserId }],
            status: { in: [...activeMatchStatuses] },
            expiresAt: { gt: new Date() },
          },
          select: { id: true },
        });
        if (candidateRaceMatch) {
          throw new Error(candidateBusyErrorCode);
        }

        const [userAId, userBId] = [userId, candidateUserId].sort((a, b) => a.localeCompare(b));

        const createdMatch = await tx.match.create({
          data: {
            userAId,
            userBId,
            questId: mySelection.questId,
            status: MatchStatus.ACCEPTED,
            expiresAt,
          },
          include: {
            quest: {
              select: {
                id: true,
                title: true,
                district: true,
              },
            },
            userA: {
              select: {
                id: true,
                displayName: true,
                age: true,
                city: true,
                karma: true,
              },
            },
            userB: {
              select: {
                id: true,
                displayName: true,
                age: true,
                city: true,
                karma: true,
              },
            },
          },
        });

        return {
          created: true,
          data: createdMatch,
        };
      })
      .catch((error) => {
        if (error instanceof Error && error.message === candidateBusyErrorCode) {
          return null;
        }
        throw error;
      });

    if (!matchResult) {
      return reply.send({
        created: false,
        matched: false,
        data: null,
        message: "No candidate found yet",
      });
    }

    return reply.code(matchResult.created ? 201 : 200).send({
      created: matchResult.created,
      matched: true,
      data: matchResult.data,
    });
  });

  app.get("/matches/:id", async (request, reply) => {
    const paramsParsed = matchIdParamsSchema.safeParse(request.params);
    const queryParsed = userIdQuerySchema.safeParse(request.query);

    if (!paramsParsed.success || !queryParsed.success) {
      return reply.code(400).send({
        error: "Invalid request",
      });
    }

    const match = await prisma.match.findUnique({
      where: { id: paramsParsed.data.id },
      include: {
        quest: {
          select: {
            id: true,
            title: true,
            district: true,
          },
        },
        userA: {
          select: {
            id: true,
            displayName: true,
            age: true,
            city: true,
            karma: true,
          },
        },
        userB: {
          select: {
            id: true,
            displayName: true,
            age: true,
            city: true,
            karma: true,
          },
        },
      },
    });

    if (!match) {
      return reply.code(404).send({ error: "Match not found" });
    }
    if (!isMatchParticipant(match, queryParsed.data.userId)) {
      return reply.code(403).send({ error: "Forbidden" });
    }

    return reply.send(match);
  });

  app.get("/matches/:id/messages", async (request, reply) => {
    const paramsParsed = matchIdParamsSchema.safeParse(request.params);
    const queryParsed = listMessagesQuerySchema.safeParse(request.query);

    if (!paramsParsed.success || !queryParsed.success) {
      return reply.code(400).send({
        error: "Invalid request",
      });
    }

    const match = await prisma.match.findUnique({
      where: { id: paramsParsed.data.id },
      select: {
        id: true,
        userAId: true,
        userBId: true,
      },
    });

    if (!match) {
      return reply.code(404).send({ error: "Match not found" });
    }
    if (!isMatchParticipant(match, queryParsed.data.userId)) {
      return reply.code(403).send({ error: "Forbidden" });
    }

    const messages = await prisma.message.findMany({
      where: { matchId: paramsParsed.data.id },
      orderBy: { createdAt: "asc" },
      take: queryParsed.data.limit,
      select: {
        id: true,
        senderId: true,
        content: true,
        createdAt: true,
        expiresAt: true,
      },
    });

    return reply.send({
      count: messages.length,
      data: messages,
    });
  });

  app.post("/matches/:id/messages", async (request, reply) => {
    const paramsParsed = matchIdParamsSchema.safeParse(request.params);
    const bodyParsed = sendMessageBodySchema.safeParse(request.body);

    if (!paramsParsed.success || !bodyParsed.success) {
      return reply.code(400).send({
        error: "Invalid request",
      });
    }

    const match = await prisma.match.findUnique({
      where: { id: paramsParsed.data.id },
      select: {
        id: true,
        userAId: true,
        userBId: true,
        status: true,
        expiresAt: true,
      },
    });

    if (!match) {
      return reply.code(404).send({ error: "Match not found" });
    }
    if (!isMatchParticipant(match, bodyParsed.data.senderId)) {
      return reply.code(403).send({ error: "Forbidden" });
    }
    if (match.status === MatchStatus.CANCELLED) {
      return reply.code(400).send({ error: "Match is cancelled" });
    }
    if (match.expiresAt <= new Date()) {
      return reply.code(400).send({ error: "Match is expired" });
    }

    const message = await prisma.message.create({
      data: {
        matchId: match.id,
        senderId: bodyParsed.data.senderId,
        content: bodyParsed.data.content,
        expiresAt: match.expiresAt,
      },
      select: {
        id: true,
        senderId: true,
        content: true,
        createdAt: true,
        expiresAt: true,
      },
    });

    return reply.code(201).send(message);
  });

  app.post("/matches/:id/proof", async (request, reply) => {
    const paramsParsed = matchIdParamsSchema.safeParse(request.params);
    const bodyParsed = submitProofBodySchema.safeParse(request.body);

    if (!paramsParsed.success || !bodyParsed.success) {
      return reply.code(400).send({
        error: "Invalid request",
      });
    }

    const match = await prisma.match.findUnique({
      where: { id: paramsParsed.data.id },
      select: {
        id: true,
        userAId: true,
        userBId: true,
        status: true,
        expiresAt: true,
      },
    });

    if (!match) {
      return reply.code(404).send({ error: "Match not found" });
    }
    if (!isMatchParticipant(match, bodyParsed.data.userId)) {
      return reply.code(403).send({ error: "Forbidden" });
    }
    if (match.status === MatchStatus.CANCELLED) {
      return reply.code(400).send({ error: "Match is cancelled" });
    }
    if (match.status === MatchStatus.COMPLETED) {
      return reply.code(400).send({ error: "Match is already completed" });
    }
    if (match.expiresAt <= new Date()) {
      return reply.code(400).send({ error: "Match is expired" });
    }

    const isUserA = match.userAId === bodyParsed.data.userId;
    const updated = await prisma.match.update({
      where: { id: match.id },
      data: isUserA
        ? {
            proofPhotoA: bodyParsed.data.photoUrl,
            proofSubmittedAAt: new Date(),
            status: match.status === MatchStatus.PENDING ? MatchStatus.ACCEPTED : match.status,
          }
        : {
            proofPhotoB: bodyParsed.data.photoUrl,
            proofSubmittedBAt: new Date(),
            status: match.status === MatchStatus.PENDING ? MatchStatus.ACCEPTED : match.status,
          },
      select: {
        id: true,
        proofPhotoA: true,
        proofPhotoB: true,
        proofSubmittedAAt: true,
        proofSubmittedBAt: true,
        status: true,
      },
    });

    return reply.send(updated);
  });

  app.post("/matches/:id/complete", async (request, reply) => {
    const paramsParsed = matchIdParamsSchema.safeParse(request.params);
    const bodyParsed = completeBodySchema.safeParse(request.body);

    if (!paramsParsed.success || !bodyParsed.success) {
      return reply.code(400).send({
        error: "Invalid request",
      });
    }

    const match = await prisma.match.findUnique({
      where: { id: paramsParsed.data.id },
      select: {
        id: true,
        userAId: true,
        userBId: true,
        status: true,
        expiresAt: true,
        confirmedByAAt: true,
        confirmedByBAt: true,
        completedAt: true,
      },
    });

    if (!match) {
      return reply.code(404).send({ error: "Match not found" });
    }
    if (!isMatchParticipant(match, bodyParsed.data.userId)) {
      return reply.code(403).send({ error: "Forbidden" });
    }
    if (match.status === MatchStatus.CANCELLED) {
      return reply.code(400).send({ error: "Match is cancelled" });
    }
    if (match.expiresAt <= new Date()) {
      return reply.code(400).send({ error: "Match is expired" });
    }

    const isUserA = match.userAId === bodyParsed.data.userId;
    const now = new Date();

    const completed = await prisma.$transaction(async (tx) => {
      let workingMatch = await tx.match.update({
        where: { id: match.id },
        data: isUserA
          ? { confirmedByAAt: now }
          : { confirmedByBAt: now },
        select: {
          id: true,
          userAId: true,
          userBId: true,
          status: true,
          confirmedByAAt: true,
          confirmedByBAt: true,
          completedAt: true,
        },
      });

      const canFinalize =
        workingMatch.status !== MatchStatus.COMPLETED &&
        workingMatch.confirmedByAAt &&
        workingMatch.confirmedByBAt;

      if (canFinalize) {
        workingMatch = await tx.match.update({
          where: { id: workingMatch.id },
          data: {
            status: MatchStatus.COMPLETED,
            completedAt: now,
          },
          select: {
            id: true,
            userAId: true,
            userBId: true,
            status: true,
            confirmedByAAt: true,
            confirmedByBAt: true,
            completedAt: true,
          },
        });

        await Promise.all([
          tx.user.update({
            where: { id: workingMatch.userAId },
            data: { karma: { increment: 10 } },
          }),
          tx.user.update({
            where: { id: workingMatch.userBId },
            data: { karma: { increment: 10 } },
          }),
        ]);

        await tx.karmaEvent.createMany({
          data: [
            {
              userId: workingMatch.userAId,
              matchId: workingMatch.id,
              delta: 10,
              reason: "MATCH_COMPLETED",
              metadata: {
                source: "mvp",
              },
            },
            {
              userId: workingMatch.userBId,
              matchId: workingMatch.id,
              delta: 10,
              reason: "MATCH_COMPLETED",
              metadata: {
                source: "mvp",
              },
            },
          ],
        });
      }

      return workingMatch;
    });

    return reply.send(completed);
  });
};
