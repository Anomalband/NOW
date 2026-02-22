import "dotenv/config";
import { z } from "zod";

const configSchema = z.object({
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
  HOST: z.string().default("0.0.0.0"),
  PORT: z.coerce.number().int().positive().default(3000),
  DATABASE_URL: z.string().min(1, "DATABASE_URL is required"),
  APP_ADMIN_TOKEN: z.string().min(12, "APP_ADMIN_TOKEN should be at least 12 chars"),
  CORS_ORIGIN: z.string().default("*"),
});

export const config = configSchema.parse(process.env);
