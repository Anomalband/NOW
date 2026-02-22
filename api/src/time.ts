import { addDays, format, startOfDay } from "date-fns";
import { fromZonedTime, toZonedTime } from "date-fns-tz";

export const ISTANBUL_TIMEZONE = "Europe/Istanbul";

export function getIstanbulDayKey(referenceDate: Date = new Date()): string {
  const zonedNow = toZonedTime(referenceDate, ISTANBUL_TIMEZONE);
  return format(zonedNow, "yyyy-MM-dd");
}

export function getNextIstanbulMidnight(referenceDate: Date = new Date()): Date {
  const zonedNow = toZonedTime(referenceDate, ISTANBUL_TIMEZONE);
  const tomorrowStart = addDays(startOfDay(zonedNow), 1);
  return fromZonedTime(tomorrowStart, ISTANBUL_TIMEZONE);
}

