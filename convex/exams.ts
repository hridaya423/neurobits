import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { requireUser } from "./lib/auth";
import {
  gcsePreferredBoardForSubject,
  isGcseCoreSubject,
} from "./lib/gcseCore";

type ExamCatalogEntry = {
  slug: string;
  displayName: string;
  countryCode: string;
  countryName: string;
  examFamily: string;
  board: string;
  level: string;
  subject: string;
  year?: number;
  aliases: string[];
  specUrl?: string;
  isActive: boolean;
};

type ExamKnowledgeEntry = {
  slug: string;
  countryCode: string;
  examFamily: string;
  board: string;
  level: string;
  subject: string;
  year?: number;
  sourceType: string;
  title: string;
  content: string;
  tags: string[];
  sourceUrl?: string;
  sourceDocId?: string;
  license?: string;
  qualityScore?: number;
  isActive: boolean;
};

const examCatalogEntryInputValidator = v.object({
  slug: v.string(),
  displayName: v.string(),
  countryCode: v.string(),
  countryName: v.string(),
  examFamily: v.string(),
  board: v.string(),
  level: v.string(),
  subject: v.string(),
  year: v.optional(v.number()),
  aliases: v.array(v.string()),
  specUrl: v.optional(v.string()),
  isActive: v.optional(v.boolean()),
});

const examCatalogEntryValidator = v.object({
  slug: v.string(),
  displayName: v.string(),
  countryCode: v.string(),
  countryName: v.string(),
  examFamily: v.string(),
  board: v.string(),
  level: v.string(),
  subject: v.string(),
  year: v.optional(v.number()),
  aliases: v.array(v.string()),
  specUrl: v.optional(v.string()),
  isActive: v.boolean(),
});

const examKnowledgeEntryInputValidator = v.object({
  slug: v.string(),
  countryCode: v.string(),
  examFamily: v.string(),
  board: v.string(),
  level: v.string(),
  subject: v.string(),
  year: v.optional(v.number()),
  sourceType: v.string(),
  title: v.string(),
  content: v.string(),
  tags: v.array(v.string()),
  sourceUrl: v.optional(v.string()),
  sourceDocId: v.optional(v.string()),
  license: v.optional(v.string()),
  qualityScore: v.optional(v.number()),
  isActive: v.optional(v.boolean()),
});

const examKnowledgeEntryValidator = v.object({
  slug: v.string(),
  countryCode: v.string(),
  examFamily: v.string(),
  board: v.string(),
  level: v.string(),
  subject: v.string(),
  year: v.optional(v.number()),
  sourceType: v.string(),
  title: v.string(),
  content: v.string(),
  tags: v.array(v.string()),
  sourceUrl: v.optional(v.string()),
  sourceDocId: v.optional(v.string()),
  license: v.optional(v.string()),
  qualityScore: v.optional(v.number()),
  isActive: v.boolean(),
});

const userExamTargetValidator = v.object({
  _id: v.id("userExamTargets"),
  _creationTime: v.number(),
  userId: v.id("users"),
  countryCode: v.string(),
  countryName: v.string(),
  examFamily: v.string(),
  board: v.string(),
  level: v.string(),
  subject: v.string(),
  year: v.optional(v.number()),
  currentGrade: v.optional(v.string()),
  targetGrade: v.optional(v.string()),
  mockDateAt: v.optional(v.number()),
  examDateAt: v.optional(v.number()),
  timetableMode: v.optional(v.string()),
  timetableProvider: v.optional(v.string()),
  timetableSyncedAt: v.optional(v.number()),
  timetableSummary: v.optional(v.string()),
  timetableSourceText: v.optional(v.string()),
  timetableSlots: v.optional(
    v.array(
      v.object({
        day: v.string(),
        start: v.string(),
        end: v.string(),
        subject: v.string(),
      })
    )
  ),
  revisionWindows: v.optional(
    v.array(
      v.object({
        day: v.string(),
        start: v.string(),
        end: v.string(),
        durationMinutes: v.number(),
      })
    )
  ),
  weeklyStudyMinutes: v.optional(v.number()),
  weeklySessionsTarget: v.optional(v.number()),
  intentQuery: v.optional(v.string()),
  sourceCatalogSlug: v.optional(v.string()),
  isActive: v.boolean(),
  createdAt: v.number(),
  updatedAt: v.number(),
});

const examTrendPointValidator = v.object({
  dayStart: v.number(),
  attempts: v.number(),
  avgMarksPct: v.number(),
});

const examWeakTopicValidator = v.object({
  topic: v.string(),
  attempts: v.number(),
  avgMarksPct: v.number(),
});

const examCurriculumSectionValidator = v.object({
  id: v.string(),
  title: v.string(),
  paperIds: v.array(v.string()),
  subtopics: v.array(v.string()),
  topics: v.optional(
    v.array(
      v.object({
        id: v.string(),
        title: v.string(),
        subtopics: v.array(
          v.object({
            id: v.string(),
            title: v.string(),
          })
        ),
      })
    )
  ),
  focus: v.optional(v.string()),
});

const examCurriculumPaperValidator = v.object({
  id: v.string(),
  title: v.string(),
  durationMinutes: v.number(),
  marks: v.number(),
  weightPercent: v.optional(v.number()),
  sectionIds: v.array(v.string()),
  assessmentFocus: v.array(v.string()),
});

const examTechniqueValidator = v.object({
  label: v.string(),
  guidance: v.string(),
});

const examPitfallValidator = v.object({
  tag: v.string(),
  summary: v.string(),
  fix: v.string(),
  severity: v.number(),
  relatedTopics: v.array(v.string()),
});

const examReportReasonProfileValidator = v.object({
  code: v.string(),
  label: v.string(),
  count: v.number(),
  share: v.number(),
  deltaShare: v.number(),
});

const examReportInsightActionValidator = v.object({
  title: v.string(),
  whyNow: v.string(),
  whyItWorks: v.string(),
  expectedGain: v.string(),
  effortLabel: v.string(),
  topic: v.string(),
  quizPreset: v.any(),
});

const studyTimeBandValidator = v.object({
  key: v.string(),
  label: v.string(),
  count: v.number(),
  share: v.number(),
});

const examKnowledgeContextEntryValidator = v.object({
  slug: v.string(),
  sourceType: v.string(),
  title: v.string(),
  board: v.string(),
  level: v.string(),
  subject: v.string(),
});

function normalize(value: string): string {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function normalizeCountryCode(value: string | undefined | null): string {
  const upper = String(value ?? "").trim().toUpperCase();
  if (!upper) return "";
  if (upper === "UK" || upper === "GBR") return "GB";
  return upper;
}

function normalizeLevelForMatch(value: string | undefined | null): string {
  const raw = String(value ?? "").trim().toLowerCase();
  if (!raw) return "";
  if (raw === "foundation tier") return "foundation";
  if (raw === "higher tier") return "higher";
  if (
    raw === "foundation / higher" ||
    raw === "foundation-higher" ||
    raw === "foundation & higher"
  ) {
    return "foundation/higher";
  }
  if (raw === "all tier" || raw === "all tiers") return "all tiers";
  if (raw === "general") return "gcse";
  return raw;
}

function matchesTargetLevel(targetLevelRaw: string, entryLevelRaw: string): boolean {
  const targetLevel = normalizeLevelForMatch(targetLevelRaw);
  const entryLevel = normalizeLevelForMatch(entryLevelRaw);

  if (!targetLevel) return true;
  if (!entryLevel) return true;
  if (targetLevel === entryLevel) return true;

  const targetTierLike =
    targetLevel === "foundation" ||
    targetLevel === "higher" ||
    targetLevel === "foundation/higher";
  const entryTierLike =
    entryLevel === "foundation" ||
    entryLevel === "higher" ||
    entryLevel === "foundation/higher";
  const targetGeneric =
    targetLevel === "gcse" ||
    targetLevel === "all tiers" ||
    targetLevel === "foundation/higher";
  const entryGeneric =
    entryLevel === "gcse" ||
    entryLevel === "all tiers" ||
    entryLevel === "foundation/higher";

  if (targetTierLike && entryGeneric) return true;
  if (targetGeneric && entryTierLike) return true;

  return false;
}

function buildKnowledgeSnippet(entry: ExamKnowledgeEntry): string {
  const sourceType = entry.sourceType.toLowerCase();
  if (sourceType === "curriculum_map" || sourceType === "curriculum") {
    const parsed = parseJsonContent(entry.content);
    const sections = Array.isArray(parsed?.sections) ? parsed.sections : [];
    const sectionParts = sections
      .map((section: any) => {
        const sectionTitle = String(section?.title ?? "").trim();
        if (!sectionTitle) return "";
        const topicTitles = Array.isArray(section?.topics)
          ? section.topics
              .map((topic: any) => String(topic?.title ?? "").trim())
              .filter((title: string) => title.length > 0)
              .slice(0, 3)
          : [];
        if (topicTitles.length > 0) {
          return `${sectionTitle}: ${topicTitles.join(", ")}`;
        }
        return sectionTitle;
      })
      .filter((label: string) => label.length > 0)
      .slice(0, 3);
    if (sectionParts.length > 0) {
      return sectionParts.join(" | ");
    }
  }
  return entry.title;
}

function tokenize(value: string): string[] {
  return Array.from(
    new Set(
      normalize(value)
        .split(" ")
        .map((token) => token.trim())
        .filter((token) => token.length > 1)
    )
  );
}

function curriculumSearchBlob(entry: ExamKnowledgeEntry): string {
  const parsed = parseJsonContent(entry.content);
  if (!parsed || typeof parsed !== "object") return "";
  const sections = Array.isArray((parsed as any).sections)
    ? (parsed as any).sections
    : [];
  const parts: string[] = [];
  for (const section of sections) {
    if (!section || typeof section !== "object") continue;
    const sectionTitle = String((section as any).title ?? "").trim();
    if (sectionTitle) parts.push(sectionTitle);
    const topics = Array.isArray((section as any).topics)
      ? (section as any).topics
      : [];
    for (const topic of topics) {
      if (!topic || typeof topic !== "object") continue;
      const topicTitle = String((topic as any).title ?? "").trim();
      if (topicTitle) parts.push(topicTitle);
      const subtopics = Array.isArray((topic as any).subtopics)
        ? (topic as any).subtopics
        : [];
      for (const subtopic of subtopics) {
        const subtopicTitle = typeof subtopic === "string"
          ? subtopic.trim()
          : String((subtopic as any)?.title ?? "").trim();
        if (subtopicTitle) parts.push(subtopicTitle);
      }
    }
    const fallbackSubtopics = Array.isArray((section as any).subtopics)
      ? (section as any).subtopics
      : [];
    for (const subtopic of fallbackSubtopics) {
      const text = String(subtopic ?? "").trim();
      if (text) parts.push(text);
    }
  }
  return parts.join(" ").toLowerCase();
}

const GCSE_GRADE_VALUES = new Set([
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
]);

function normalizeGcseGrade(value: string | undefined): string | undefined {
  if (!value) return undefined;
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  if (GCSE_GRADE_VALUES.has(trimmed)) {
    return trimmed;
  }
  return undefined;
}

function normalizeTimestamp(value: number | undefined | null): number | undefined {
  if (value === undefined || value === null) return undefined;
  if (!Number.isFinite(value) || value <= 0) return undefined;
  return Math.floor(value);
}

function normalizePositiveInt(value: number | undefined | null): number | undefined {
  if (value === undefined || value === null) return undefined;
  if (!Number.isFinite(value) || value <= 0) return undefined;
  return Math.floor(value);
}

function normalizeOptionalText(
  value: string | undefined | null,
  maxLength = 2000
): string | undefined {
  if (value === undefined || value === null) return undefined;
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  if (trimmed.length <= maxLength) return trimmed;
  return trimmed.slice(0, maxLength);
}

function normalizeTimetableDay(value: string | undefined | null): string | undefined {
  if (!value) return undefined;
  const normalized = value.trim().toLowerCase();
  if (!normalized) return undefined;
  if (normalized.startsWith("mon")) return "mon";
  if (normalized.startsWith("tue")) return "tue";
  if (normalized.startsWith("wed")) return "wed";
  if (normalized.startsWith("thu")) return "thu";
  if (normalized.startsWith("fri")) return "fri";
  if (normalized.startsWith("sat")) return "sat";
  if (normalized.startsWith("sun")) return "sun";
  return undefined;
}

function normalizeTimeLabel(value: string | undefined | null): string | undefined {
  if (!value) return undefined;
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  const match = trimmed.match(/^(\d{1,2})(?::|\.)(\d{2})$/);
  if (!match) return undefined;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return undefined;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return undefined;
  return `${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
}

function normalizeTimetableSlots(
  value:
    | {
        day?: string | null;
        start?: string | null;
        end?: string | null;
        subject?: string | null;
      }[]
    | undefined
    | null
): { day: string; start: string; end: string; subject: string }[] | undefined {
  if (!value || !Array.isArray(value)) return undefined;
  const out: { day: string; start: string; end: string; subject: string }[] = [];
  const seen = new Set<string>();
  for (const row of value) {
    const day = normalizeTimetableDay(row?.day);
    const start = normalizeTimeLabel(row?.start);
    const end = normalizeTimeLabel(row?.end);
    const subject = normalizeOptionalText(row?.subject, 100);
    if (!day || !start || !end || !subject) continue;
    const key = `${day}|${start}|${end}|${subject.toLowerCase()}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ day, start, end, subject });
    if (out.length >= 120) break;
  }
  out.sort((a, b) => {
    const dayRank = (day: string) => {
      switch (day) {
        case "mon":
          return 0;
        case "tue":
          return 1;
        case "wed":
          return 2;
        case "thu":
          return 3;
        case "fri":
          return 4;
        case "sat":
          return 5;
        case "sun":
          return 6;
        default:
          return 99;
      }
    };
    const dayDiff = dayRank(a.day) - dayRank(b.day);
    if (dayDiff !== 0) return dayDiff;
    const startDiff = a.start.localeCompare(b.start);
    if (startDiff !== 0) return startDiff;
    return a.subject.localeCompare(b.subject);
  });
  return out.length > 0 ? out : undefined;
}

function normalizeRevisionWindows(
  value:
    | {
        day?: string | null;
        start?: string | null;
        end?: string | null;
        durationMinutes?: number | null;
      }[]
    | undefined
    | null
): { day: string; start: string; end: string; durationMinutes: number }[] | undefined {
  if (!value || !Array.isArray(value)) return undefined;
  const out: { day: string; start: string; end: string; durationMinutes: number }[] = [];
  const seen = new Set<string>();
  for (const row of value) {
    const day = normalizeTimetableDay(row?.day);
    const start = normalizeTimeLabel(row?.start);
    const end = normalizeTimeLabel(row?.end);
    const duration = normalizePositiveInt(row?.durationMinutes);
    if (!day || !start || !end || !duration) continue;
    const boundedDuration = Math.max(10, Math.min(duration, 180));
    const key = `${day}|${start}|${end}|${boundedDuration}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push({ day, start, end, durationMinutes: boundedDuration });
    if (out.length >= 28) break;
  }
  out.sort((a, b) => {
    const dayRank = (day: string) => {
      switch (day) {
        case "mon":
          return 0;
        case "tue":
          return 1;
        case "wed":
          return 2;
        case "thu":
          return 3;
        case "fri":
          return 4;
        case "sat":
          return 5;
        case "sun":
          return 6;
        default:
          return 99;
      }
    };
    const dayDiff = dayRank(a.day) - dayRank(b.day);
    if (dayDiff !== 0) return dayDiff;
    const startDiff = a.start.localeCompare(b.start);
    if (startDiff !== 0) return startDiff;
    return a.end.localeCompare(b.end);
  });
  return out.length > 0 ? out : undefined;
}

const TIMETABLE_MODES = new Set(["none", "manual", "sync_pending", "synced"]);

function normalizeTimetableMode(value: string | undefined | null): string | undefined {
  if (value === undefined || value === null) return undefined;
  const normalized = value.trim().toLowerCase();
  if (!normalized) return undefined;
  return TIMETABLE_MODES.has(normalized) ? normalized : undefined;
}

function expandQueryTokens(tokens: string[]): string[] {
  const synonyms: Record<string, string[]> = {
    math: ["mathematics", "maths"],
    maths: ["mathematics", "math"],
    english: ["language", "literature"],
    lit: ["literature"],
    cs: ["computer", "science"],
    comp: ["computer"],
    phy: ["physics"],
    chem: ["chemistry"],
    bio: ["biology"],
    econ: ["economics"],
  };
  const expanded = new Set(tokens);
  for (const token of tokens) {
    const extra = synonyms[token];
    if (!extra) continue;
    for (const alias of extra) {
      expanded.add(alias);
    }
  }
  return Array.from(expanded.values());
}

function asCatalogEntry(entry: any): ExamCatalogEntry {
  return {
    slug: entry.slug,
    displayName: entry.displayName,
    countryCode: entry.countryCode,
    countryName: entry.countryName,
    examFamily: entry.examFamily,
    board: entry.board,
    level: entry.level,
    subject: entry.subject,
    year: entry.year,
    aliases: entry.aliases,
    specUrl: entry.specUrl,
    isActive: entry.isActive,
  };
}

function sanitizeCatalogInput(input: {
  slug: string;
  displayName: string;
  countryCode: string;
  countryName: string;
  examFamily: string;
  board: string;
  level: string;
  subject: string;
  year?: number;
  aliases: string[];
  specUrl?: string;
  isActive?: boolean;
}): ExamCatalogEntry {
  const aliases = Array.from(
    new Set(
      input.aliases
        .map((alias) => alias.trim())
        .filter((alias) => alias.length > 0)
    )
  );

  return {
    slug: input.slug.trim().toLowerCase(),
    displayName: input.displayName.trim(),
    countryCode: input.countryCode.trim().toUpperCase(),
    countryName: input.countryName.trim(),
    examFamily: input.examFamily.trim().toLowerCase(),
    board: input.board.trim(),
    level: input.level.trim(),
    subject: input.subject.trim(),
    year: input.year,
    aliases,
    specUrl: input.specUrl?.trim() || undefined,
    isActive: input.isActive ?? true,
  };
}

function asKnowledgeEntry(entry: any): ExamKnowledgeEntry {
  return {
    slug: entry.slug,
    countryCode: entry.countryCode,
    examFamily: entry.examFamily,
    board: entry.board,
    level: entry.level,
    subject: entry.subject,
    year: entry.year,
    sourceType: entry.sourceType,
    title: entry.title,
    content: entry.content,
    tags: entry.tags,
    sourceUrl: entry.sourceUrl,
    sourceDocId: entry.sourceDocId,
    license: entry.license,
    qualityScore: entry.qualityScore,
    isActive: entry.isActive,
  };
}

function sanitizeKnowledgeInput(input: {
  slug: string;
  countryCode: string;
  examFamily: string;
  board: string;
  level: string;
  subject: string;
  year?: number;
  sourceType: string;
  title: string;
  content: string;
  tags: string[];
  sourceUrl?: string;
  sourceDocId?: string;
  license?: string;
  qualityScore?: number;
  isActive?: boolean;
}): ExamKnowledgeEntry {
  const tags = Array.from(
    new Set(
      input.tags
        .map((tag) => tag.trim())
        .filter((tag) => tag.length > 0)
    )
  );

  return {
    slug: input.slug.trim().toLowerCase(),
    countryCode: input.countryCode.trim().toUpperCase(),
    examFamily: input.examFamily.trim().toLowerCase(),
    board: input.board.trim(),
    level: input.level.trim(),
    subject: input.subject.trim(),
    year: input.year,
    sourceType: input.sourceType.trim().toLowerCase(),
    title: input.title.trim(),
    content: input.content.trim(),
    tags,
    sourceUrl: input.sourceUrl?.trim() || undefined,
    sourceDocId: input.sourceDocId?.trim() || undefined,
    license: input.license?.trim() || undefined,
    qualityScore: input.qualityScore,
    isActive: input.isActive ?? true,
  };
}

function parseJsonContent(content: string): any | null {
  const trimmed = content.trim();
  if (!trimmed) return null;
  try {
    return JSON.parse(trimmed);
  } catch {
    return null;
  }
}

function asStringArray(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  const out = new Set<string>();
  for (const item of value) {
    const text = String(item ?? "").trim();
    if (text) out.add(text);
  }
  return Array.from(out.values());
}

function asPositiveInt(value: unknown, fallback = 0): number {
  if (typeof value === "number" && Number.isFinite(value) && value > 0) {
    return Math.floor(value);
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed) && parsed > 0) {
      return Math.floor(parsed);
    }
  }
  return fallback;
}

function normalizeSection(raw: any, fallbackId: string) {
  if (!raw || typeof raw !== "object") return null;
  const id = String(raw.id ?? fallbackId).trim();
  const title = String(raw.title ?? "").trim();
  if (!id || !title) return null;

  const normalizedTopics: Array<{
    id: string;
    title: string;
    subtopics: Array<{ id: string; title: string }>;
  }> = [];
  const flattenedSubtopics: string[] = [];

  if (Array.isArray(raw.topics)) {
    for (let topicIndex = 0; topicIndex < raw.topics.length; topicIndex += 1) {
      const topicRow = raw.topics[topicIndex];
      if (!topicRow || typeof topicRow !== "object") continue;
      const topicTitle = String(topicRow.title ?? "").trim();
      if (!topicTitle) continue;
      const topicId = String(topicRow.id ?? `topic_${topicIndex + 1}`).trim();
      const topicSubtopics = Array.isArray(topicRow.subtopics)
        ? topicRow.subtopics
        : [];

      const normalizedSubtopics: Array<{ id: string; title: string }> = [];
      for (let subIndex = 0; subIndex < topicSubtopics.length; subIndex += 1) {
        const subRow = topicSubtopics[subIndex];
        const subTitle = typeof subRow === "string"
          ? subRow.trim()
          : String(subRow?.title ?? "").trim();
        if (!subTitle) continue;
        const subId = typeof subRow === "string"
          ? `subtopic_${subIndex + 1}`
          : String(subRow?.id ?? `subtopic_${subIndex + 1}`).trim();
        normalizedSubtopics.push({ id: subId, title: subTitle });
        flattenedSubtopics.push(`${topicTitle}: ${subTitle}`);
      }

      if (normalizedSubtopics.length === 0) continue;
      normalizedTopics.push({
        id: topicId,
        title: topicTitle,
        subtopics: normalizedSubtopics,
      });
    }
  }

  const legacySubtopics = normalizedTopics.length > 0
    ? []
    : asStringArray(raw.subtopics ?? raw.topics);
  const subtopics = normalizedTopics.length > 0
    ? Array.from(new Set(flattenedSubtopics))
    : legacySubtopics;

  const section = {
    id,
    title,
    paperIds: asStringArray(raw.paperIds),
    subtopics,
    ...(normalizedTopics.length > 0 ? { topics: normalizedTopics } : {}),
    focus: String(raw.focus ?? "").trim() || undefined,
  };
  return section;
}

function normalizePaper(raw: any, fallbackId: string) {
  if (!raw || typeof raw !== "object") return null;
  const id = String(raw.id ?? fallbackId).trim();
  const title = String(raw.title ?? "").trim();
  if (!id || !title) return null;
  const paper = {
    id,
    title,
    durationMinutes: asPositiveInt(raw.durationMinutes ?? raw.duration, 0),
    marks: asPositiveInt(raw.marks, 0),
    weightPercent: asPositiveInt(raw.weightPercent ?? raw.weight, 0) || undefined,
    sectionIds: asStringArray(raw.sectionIds),
    assessmentFocus: asStringArray(raw.assessmentFocus ?? raw.techniques),
  };
  return paper;
}

function normalizeTechnique(raw: any) {
  if (!raw || typeof raw !== "object") return null;
  const label = String(raw.label ?? raw.title ?? "").trim();
  const guidance = String(raw.guidance ?? raw.detail ?? raw.description ?? "").trim();
  if (!label || !guidance) return null;
  return { label, guidance };
}

function normalizePitfall(raw: any) {
  if (!raw || typeof raw !== "object") return null;
  const tag = String(raw.tag ?? raw.code ?? "").trim();
  const summary = String(raw.summary ?? raw.issue ?? "").trim();
  const fix = String(raw.fix ?? raw.remedy ?? raw.action ?? "").trim();
  if (!tag || !summary || !fix) return null;
  const severity = Math.max(1, Math.min(5, asPositiveInt(raw.severity, 3)));
  return {
    tag,
    summary,
    fix,
    severity,
    relatedTopics: asStringArray(raw.relatedTopics ?? raw.topics),
  };
}

async function getCatalogEntries(ctx: any): Promise<ExamCatalogEntry[]> {
  const entries = await ctx.db
    .query("examCatalog")
    .withIndex("by_is_active_and_updated_at", (q: any) => q.eq("isActive", true))
    .order("desc")
    .collect();

  return entries.map((entry: any) => asCatalogEntry(entry));
}

async function getKnowledgeEntriesForTarget(ctx: any, target: any) {
  const countryCode = normalizeCountryCode(target.countryCode);
  const examFamily = String(target.examFamily ?? "").trim().toLowerCase();
  const board = String(target.board ?? "").trim().toLowerCase();
  const level = normalizeLevelForMatch(target.level);
  const subject = String(target.subject ?? "").trim().toLowerCase();
  const year = typeof target.year === "number" ? target.year : undefined;

  const base = countryCode && examFamily
    ? await ctx.db
        .query("examKnowledge")
        .withIndex("by_country_and_exam_family_and_updated_at", (q: any) =>
          q.eq("countryCode", countryCode).eq("examFamily", examFamily)
        )
        .order("desc")
        .take(600)
    : await ctx.db
        .query("examKnowledge")
        .withIndex("by_is_active_and_updated_at", (q: any) =>
          q.eq("isActive", true)
        )
        .order("desc")
        .take(600);

  return base
    .filter((row: any) => {
      if (row.isActive !== true) return false;
      if (
        countryCode &&
        normalizeCountryCode(String(row.countryCode ?? "")) !== countryCode
      ) {
        return false;
      }
      if (examFamily && String(row.examFamily ?? "").toLowerCase() !== examFamily) {
        return false;
      }
      if (board && String(row.board ?? "").toLowerCase() !== board) return false;
      if (level && !matchesTargetLevel(level, String(row.level ?? ""))) {
        return false;
      }
      const rowSubject = String(row.subject ?? "").toLowerCase();
      if (subject && !rowSubject.includes(subject)) return false;
      if (year !== undefined && row.year !== undefined && row.year !== year) {
        return false;
      }
      return true;
    })
    .map((row: any) => asKnowledgeEntry(row));
}

const GCSE_GRADE_THRESHOLDS: Array<{ grade: number; threshold: number }> = [
  { grade: 9, threshold: 0.85 },
  { grade: 8, threshold: 0.76 },
  { grade: 7, threshold: 0.67 },
  { grade: 6, threshold: 0.58 },
  { grade: 5, threshold: 0.49 },
  { grade: 4, threshold: 0.4 },
  { grade: 3, threshold: 0.32 },
  { grade: 2, threshold: 0.24 },
  { grade: 1, threshold: 0.16 },
];

function estimateGcseGrade(value: number): number {
  const pct = Math.max(0, Math.min(1, value));
  for (const threshold of GCSE_GRADE_THRESHOLDS) {
    if (pct >= threshold.threshold) return threshold.grade;
  }
  return 1;
}

function isCoreGcseCatalogEntry(entry: ExamCatalogEntry): boolean {
  if (entry.examFamily.toLowerCase() !== "gcse") return false;
  if (entry.countryCode.toUpperCase() !== "GB") return false;
  if (!isGcseCoreSubject(entry.subject)) return false;
  const preferredBoard = gcsePreferredBoardForSubject(entry.subject);
  if (!preferredBoard) return false;
  return entry.board.trim().toLowerCase() === preferredBoard.toLowerCase();
}

export const listCatalog = query({
  args: {
    countryCode: v.optional(v.string()),
    examFamily: v.optional(v.string()),
    subject: v.optional(v.string()),
    query: v.optional(v.string()),
    coreOnly: v.optional(v.boolean()),
    limit: v.optional(v.number()),
  },
  returns: v.object({
    source: v.literal("db"),
    items: v.array(examCatalogEntryValidator),
  }),
  handler: async (ctx, args) => {
    const entries = await getCatalogEntries(ctx);
    const country = args.countryCode?.trim().toUpperCase();
    const family = args.examFamily?.trim().toLowerCase();
    const subject = args.subject?.trim().toLowerCase();
    const queryText = args.query?.trim() ?? "";
    const q = normalize(queryText);
    const coreOnly = args.coreOnly === true;
    const limit = Math.max(1, Math.min(2000, Math.floor(args.limit ?? 200)));

    const filtered = entries.filter((entry: ExamCatalogEntry) => {
      if (coreOnly && !isCoreGcseCatalogEntry(entry)) {
        return false;
      }
      if (country && entry.countryCode.toUpperCase() !== country) {
        return false;
      }
      if (family && entry.examFamily.toLowerCase() !== family) {
        return false;
      }
      if (subject && !entry.subject.toLowerCase().includes(subject)) {
        return false;
      }
      if (!q) return true;

      const hay = [
        entry.displayName,
        entry.countryName,
        entry.countryCode,
        entry.examFamily,
        entry.board,
        entry.level,
        entry.subject,
        ...entry.aliases,
      ]
        .join(" ")
        .toLowerCase();
      return hay.includes(q);
    });

    return {
      source: "db" as const,
      items: filtered.slice(0, limit),
    };
  },
});

export const resolveIntent = query({
  args: {
    text: v.string(),
    limit: v.optional(v.number()),
  },
  returns: v.object({
    source: v.literal("db"),
    items: v.array(
      v.object({
        entry: examCatalogEntryValidator,
        score: v.number(),
        confidence: v.number(),
        matchedTokens: v.array(v.string()),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const text = args.text.trim();
    const limit = Math.max(1, Math.min(20, Math.floor(args.limit ?? 5)));
    if (!text) {
      return { source: "db" as const, items: [] };
    }

    const entries = await getCatalogEntries(ctx);
    const normalizedInput = normalize(text);
    const tokens = expandQueryTokens(tokenize(text));

    const scored = entries
      .map((entry: ExamCatalogEntry) => {
        const fields = [
          normalize(entry.displayName),
          normalize(entry.countryName),
          normalize(entry.countryCode),
          normalize(entry.examFamily),
          normalize(entry.board),
          normalize(entry.level),
          normalize(entry.subject),
          ...entry.aliases.map((alias: string) => normalize(alias)),
        ];

        let score = 0;
        const matched = new Set<string>();
        const joined = fields.join(" ");

        if (joined.includes(normalizedInput)) {
          score += 8;
        }
        if (normalize(entry.displayName).includes(normalizedInput)) {
          score += 6;
        }

        for (const token of tokens) {
          let tokenScore = 0;
          for (const field of fields) {
            if (field === token) {
              tokenScore = Math.max(tokenScore, 3);
            } else if (field.includes(token)) {
              tokenScore = Math.max(tokenScore, 2);
            }
          }
          if (normalize(entry.subject).includes(token)) {
            tokenScore = Math.max(tokenScore, 4);
          }
          if (tokenScore > 0) {
            matched.add(token);
            score += tokenScore;
          }
        }

        if (
          entry.year !== undefined &&
          normalizedInput.includes(String(entry.year))
        ) {
          score += 2;
        }

        return {
          entry,
          score,
          confidence: Number(Math.min(1, score / 20).toFixed(3)),
          matchedTokens: Array.from(matched.values()),
        };
      })
      .filter(
        (row: {
          entry: ExamCatalogEntry;
          score: number;
          confidence: number;
          matchedTokens: string[];
        }) => row.score > 0
      )
      .sort(
        (a: { entry: ExamCatalogEntry; score: number }, b: { entry: ExamCatalogEntry; score: number }) => {
          if (b.score !== a.score) return b.score - a.score;
          return a.entry.displayName.localeCompare(b.entry.displayName);
        }
      )
      .slice(0, limit);

    return {
      source: "db" as const,
      items: scored,
    };
  },
});

export const getCatalogStatus = query({
  args: {},
  returns: v.object({
    totalEntries: v.number(),
    activeEntries: v.number(),
    lastUpdatedAt: v.optional(v.number()),
  }),
  handler: async (ctx) => {
    const all = await ctx.db.query("examCatalog").collect();
    const active = all.filter((item: any) => item.isActive === true);
    const sortedByUpdate = [...all].sort(
      (a: any, b: any) => (b.updatedAt ?? 0) - (a.updatedAt ?? 0)
    );
    return {
      totalEntries: all.length,
      activeEntries: active.length,
      lastUpdatedAt: sortedByUpdate[0]?.updatedAt,
    };
  },
});

export const bulkUpsertCatalog = mutation({
  args: {
    entries: v.array(examCatalogEntryInputValidator),
    replaceExisting: v.optional(v.boolean()),
  },
  returns: v.object({
    upserted: v.number(),
    deactivated: v.number(),
  }),
  handler: async (ctx, args) => {
    await requireUser(ctx);
    const now = Date.now();
    const replaceExisting = args.replaceExisting === true;

    const normalized = new Map<string, ExamCatalogEntry>();
    for (const raw of args.entries) {
      const entry = sanitizeCatalogInput(raw);
      if (entry.slug.length == 0) continue;
      normalized.set(entry.slug, entry);
    }

    let upserted = 0;
    for (const entry of normalized.values()) {
      const existing = await ctx.db
        .query("examCatalog")
        .withIndex("by_slug", (q: any) => q.eq("slug", entry.slug))
        .unique();

      if (existing) {
        await ctx.db.patch(existing._id, {
          displayName: entry.displayName,
          countryCode: entry.countryCode,
          countryName: entry.countryName,
          examFamily: entry.examFamily,
          board: entry.board,
          level: entry.level,
          subject: entry.subject,
          year: entry.year,
          aliases: entry.aliases,
          specUrl: entry.specUrl,
          isActive: entry.isActive,
          updatedAt: now,
        });
      } else {
        await ctx.db.insert("examCatalog", {
          slug: entry.slug,
          displayName: entry.displayName,
          countryCode: entry.countryCode,
          countryName: entry.countryName,
          examFamily: entry.examFamily,
          board: entry.board,
          level: entry.level,
          subject: entry.subject,
          year: entry.year,
          aliases: entry.aliases,
          specUrl: entry.specUrl,
          isActive: entry.isActive,
          createdAt: now,
          updatedAt: now,
        });
      }
      upserted += 1;
    }

    let deactivated = 0;
    if (replaceExisting) {
      const keepSlugs = new Set(Array.from(normalized.keys()));
      const activeExisting = await ctx.db
        .query("examCatalog")
        .withIndex("by_is_active_and_updated_at", (q: any) => q.eq("isActive", true))
        .collect();
      for (const item of activeExisting) {
        if (!keepSlugs.has(item.slug)) {
          await ctx.db.patch(item._id, {
            isActive: false,
            updatedAt: now,
          });
          deactivated += 1;
        }
      }
    }

    return {
      upserted,
      deactivated,
    };
  },
});

export const bulkUpsertKnowledge = mutation({
  args: {
    entries: v.array(examKnowledgeEntryInputValidator),
    replaceExisting: v.optional(v.boolean()),
  },
  returns: v.object({
    upserted: v.number(),
    deactivated: v.number(),
  }),
  handler: async (ctx, args) => {
    await requireUser(ctx);
    const now = Date.now();
    const replaceExisting = args.replaceExisting === true;

    const normalized = new Map<string, ExamKnowledgeEntry>();
    for (const raw of args.entries) {
      const entry = sanitizeKnowledgeInput(raw);
      if (entry.slug.length === 0 || entry.content.length === 0) continue;
      normalized.set(entry.slug, entry);
    }

    let upserted = 0;
    for (const entry of normalized.values()) {
      const existing = await ctx.db
        .query("examKnowledge")
        .withIndex("by_slug", (q: any) => q.eq("slug", entry.slug))
        .unique();

      if (existing) {
        await ctx.db.patch(existing._id, {
          countryCode: entry.countryCode,
          examFamily: entry.examFamily,
          board: entry.board,
          level: entry.level,
          subject: entry.subject,
          year: entry.year,
          sourceType: entry.sourceType,
          title: entry.title,
          content: entry.content,
          tags: entry.tags,
          sourceUrl: entry.sourceUrl,
          sourceDocId: entry.sourceDocId,
          license: entry.license,
          qualityScore: entry.qualityScore,
          isActive: entry.isActive,
          updatedAt: now,
        });
      } else {
        await ctx.db.insert("examKnowledge", {
          slug: entry.slug,
          countryCode: entry.countryCode,
          examFamily: entry.examFamily,
          board: entry.board,
          level: entry.level,
          subject: entry.subject,
          year: entry.year,
          sourceType: entry.sourceType,
          title: entry.title,
          content: entry.content,
          tags: entry.tags,
          sourceUrl: entry.sourceUrl,
          sourceDocId: entry.sourceDocId,
          license: entry.license,
          qualityScore: entry.qualityScore,
          isActive: entry.isActive,
          createdAt: now,
          updatedAt: now,
        });
      }
      upserted += 1;
    }

    let deactivated = 0;
    if (replaceExisting) {
      const keepSlugs = new Set(Array.from(normalized.keys()));
      const activeExisting = await ctx.db
        .query("examKnowledge")
        .withIndex("by_is_active_and_updated_at", (q: any) =>
          q.eq("isActive", true)
        )
        .collect();
      for (const item of activeExisting) {
        if (!keepSlugs.has(item.slug)) {
          await ctx.db.patch(item._id, {
            isActive: false,
            updatedAt: now,
          });
          deactivated += 1;
        }
      }
    }

    return {
      upserted,
      deactivated,
    };
  },
});

export const getRetrievalContext = query({
  args: {
    countryCode: v.optional(v.string()),
    examFamily: v.optional(v.string()),
    board: v.optional(v.string()),
    level: v.optional(v.string()),
    subject: v.optional(v.string()),
    year: v.optional(v.number()),
    topicQuery: v.optional(v.string()),
    limit: v.optional(v.number()),
  },
  returns: v.object({
    totalCandidates: v.number(),
    items: v.array(
      v.object({
        entry: examKnowledgeContextEntryValidator,
        score: v.number(),
        snippet: v.string(),
      })
    ),
  }),
  handler: async (ctx, args) => {
    const limit = Math.max(1, Math.min(20, Math.floor(args.limit ?? 6)));
    const countryCode = normalizeCountryCode(args.countryCode);
    const examFamily = args.examFamily?.trim().toLowerCase();
    const board = args.board?.trim().toLowerCase();
    const level = normalizeLevelForMatch(args.level);
    const subject = args.subject?.trim().toLowerCase();
    const topicQuery = args.topicQuery?.trim() ?? "";
    const queryTokens = tokenize(topicQuery);

    const base = countryCode && examFamily
      ? await ctx.db
          .query("examKnowledge")
          .withIndex("by_country_and_exam_family_and_updated_at", (q: any) =>
            q.eq("countryCode", countryCode).eq("examFamily", examFamily)
          )
          .order("desc")
          .take(250)
      : await ctx.db
          .query("examKnowledge")
          .withIndex("by_is_active_and_updated_at", (q: any) => q.eq("isActive", true))
          .order("desc")
          .take(250);

    const entries = base
      .filter((row: any) => row.isActive === true)
      .map((row: any) => asKnowledgeEntry(row));

    const hardFiltered = entries.filter((entry: ExamKnowledgeEntry) => {
      if (countryCode && normalizeCountryCode(entry.countryCode) !== countryCode) {
        return false;
      }
      if (examFamily && entry.examFamily.toLowerCase() !== examFamily) {
        return false;
      }
      if (board && entry.board.toLowerCase() !== board) return false;
      if (level && !matchesTargetLevel(level, entry.level)) {
        return false;
      }
      if (subject && !entry.subject.toLowerCase().includes(subject)) {
        return false;
      }
      if (args.year !== undefined && entry.year !== args.year) return false;
      return true;
    });

    const scoringBase = hardFiltered;

    const scored = scoringBase
      .map((entry: ExamKnowledgeEntry) => {
        const textBlob = [
          entry.title,
          curriculumSearchBlob(entry),
          entry.sourceType,
          entry.board,
          entry.level,
          entry.subject,
          ...entry.tags,
        ]
          .join(" ")
          .toLowerCase();

        let score = 0;
        if (countryCode && entry.countryCode === countryCode) score += 2.5;
        if (examFamily && entry.examFamily.toLowerCase() === examFamily) {
          score += 5;
        }
        if (board && entry.board.toLowerCase() === board) score += 4.5;
        if (level && entry.level.toLowerCase() === level) score += 3.5;
        if (subject && entry.subject.toLowerCase().includes(subject)) {
          score += 4;
        }
        if (args.year !== undefined && entry.year === args.year) score += 2;

        for (const token of queryTokens) {
          if (textBlob.includes(token)) {
            score += 1.3;
          }
        }

        if (entry.qualityScore !== undefined) {
          score += Math.max(0, Math.min(2, entry.qualityScore / 5));
        }

        const snippet = buildKnowledgeSnippet(entry);

        return {
          entry: {
            slug: entry.slug,
            sourceType: entry.sourceType,
            title: entry.title,
            board: entry.board,
            level: entry.level,
            subject: entry.subject,
          },
          score: Number(score.toFixed(3)),
          snippet,
        };
      })
      .filter((row: { score: number }) => row.score > 0)
      .sort((a: { score: number }, b: { score: number }) => b.score - a.score);

    return {
      totalCandidates: scored.length,
      items: scored.slice(0, limit),
    };
  },
});

export const getMyTarget = query({
  args: {},
  returns: v.union(v.null(), userExamTargetValidator),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const currentActive = await ctx.db
      .query("userExamTargets")
      .withIndex("by_user_id_and_is_active_and_updated_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .order("desc")
      .first();

    if (currentActive) return currentActive;

    const latest = await ctx.db
      .query("userExamTargets")
      .withIndex("by_user_id_and_updated_at", (q) => q.eq("userId", userId))
      .order("desc")
      .first();

    return latest ?? null;
  },
});

export const getMyTargetById = query({
  args: {
    targetId: v.id("userExamTargets"),
  },
  returns: v.union(v.null(), userExamTargetValidator),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const target = await ctx.db.get(args.targetId);
    if (!target || target.userId !== userId) {
      return null;
    }
    return target;
  },
});

export const listMyTargets = query({
  args: {},
  returns: v.array(userExamTargetValidator),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const rows = await ctx.db
      .query("userExamTargets")
      .withIndex("by_user_id_and_updated_at", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();
    return rows;
  },
});

export const getMyStudyTimeProfile = query({
  args: {
    targetId: v.optional(v.id("userExamTargets")),
    timezoneOffsetMinutes: v.optional(v.number()),
  },
  returns: v.object({
    sampleSize: v.number(),
    primaryBand: v.optional(v.string()),
    secondaryBand: v.optional(v.string()),
    bands: v.array(studyTimeBandValidator),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    if (args.targetId) {
      const target = await ctx.db.get(args.targetId);
      if (!target || target.userId !== userId) {
        throw new Error("Target not found");
      }
    }

    const offsetMinutesRaw = Number.isFinite(args.timezoneOffsetMinutes)
      ? Math.trunc(args.timezoneOffsetMinutes ?? 0)
      : 0;
    const offsetMinutes = Math.max(-720, Math.min(offsetMinutesRaw, 840));
    const offsetMs = offsetMinutes * 60 * 1000;

    const attempts = await ctx.db
      .query("challengeAttempts")
      .withIndex("by_user_id_and_created_at", (q) => q.eq("userId", userId))
      .order("desc")
      .take(260);

    const rows = args.targetId
      ? attempts.filter(
          (attempt) =>
            attempt.examTargetId !== undefined &&
            attempt.examTargetId === args.targetId
        )
      : attempts;

    const completed = rows.filter((attempt) => attempt.completed);

    const bandCounters = {
      after_school: 0,
      after_dinner: 0,
      before_sleep: 0,
      morning: 0,
      midday: 0,
    };

    const classifyHour = (hour: number): keyof typeof bandCounters => {
      if (hour >= 15 && hour < 18) return "after_school";
      if (hour >= 18 && hour < 21) return "after_dinner";
      if (hour >= 21 || hour < 1) return "before_sleep";
      if (hour >= 6 && hour < 11) return "morning";
      return "midday";
    };

    for (const attempt of completed) {
      const createdAt = attempt.createdAt ?? 0;
      if (!Number.isFinite(createdAt) || createdAt <= 0) continue;
      const localMs = createdAt + offsetMs;
      const hour = new Date(localMs).getUTCHours();
      const band = classifyHour(hour);
      bandCounters[band] += 1;
    }

    const sampleSize =
      bandCounters.after_school +
      bandCounters.after_dinner +
      bandCounters.before_sleep +
      bandCounters.morning +
      bandCounters.midday;

    const labelByBand: Record<string, string> = {
      after_school: "After school",
      after_dinner: "After dinner",
      before_sleep: "Before sleep",
      morning: "Morning",
      midday: "Midday",
    };

    const bands = Object.entries(bandCounters)
      .map(([key, count]) => ({
        key,
        label: labelByBand[key] ?? key,
        count,
        share: sampleSize > 0 ? count / sampleSize : 0,
      }))
      .sort((a, b) => {
        if (b.count !== a.count) return b.count - a.count;
        return a.key.localeCompare(b.key);
      });

    const nonZero = bands.filter((band) => band.count > 0);
    return {
      sampleSize,
      primaryBand: nonZero[0]?.key,
      secondaryBand: nonZero[1]?.key,
      bands,
    };
  },
});

export const upsertMyTarget = mutation({
  args: {
    countryCode: v.string(),
    countryName: v.string(),
    examFamily: v.string(),
    board: v.string(),
    level: v.string(),
    subject: v.string(),
    makeActive: v.optional(v.boolean()),
    year: v.optional(v.number()),
    currentGrade: v.optional(v.string()),
    targetGrade: v.optional(v.string()),
    mockDateAt: v.optional(v.number()),
    examDateAt: v.optional(v.number()),
    timetableMode: v.optional(v.string()),
    timetableProvider: v.optional(v.string()),
    timetableSyncedAt: v.optional(v.number()),
    timetableSummary: v.optional(v.string()),
    timetableSourceText: v.optional(v.string()),
    timetableSlots: v.optional(
      v.array(
        v.object({
          day: v.string(),
          start: v.string(),
          end: v.string(),
          subject: v.string(),
        })
      )
    ),
    revisionWindows: v.optional(
      v.array(
        v.object({
          day: v.string(),
          start: v.string(),
          end: v.string(),
          durationMinutes: v.number(),
        })
      )
    ),
    weeklyStudyMinutes: v.optional(v.number()),
    weeklySessionsTarget: v.optional(v.number()),
    intentQuery: v.optional(v.string()),
    sourceCatalogSlug: v.optional(v.string()),
  },
  returns: v.id("userExamTargets"),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();
    const makeActive = args.makeActive !== false;
    const examFamily = args.examFamily.trim().toLowerCase();
    const subject = args.subject.trim();
    const board = args.board.trim();
    const currentGrade = normalizeGcseGrade(args.currentGrade);
    const targetGrade = normalizeGcseGrade(args.targetGrade);
    const mockDateAt = normalizeTimestamp(args.mockDateAt);
    const examDateAt = normalizeTimestamp(args.examDateAt);
    const timetableMode = normalizeTimetableMode(args.timetableMode);
    const timetableProvider = normalizeOptionalText(args.timetableProvider, 120);
    const timetableSyncedAt = normalizeTimestamp(args.timetableSyncedAt);
    const timetableSummary = normalizeOptionalText(args.timetableSummary, 300);
    const timetableSourceText = normalizeOptionalText(
      args.timetableSourceText,
      16000
    );
    const timetableSlots = normalizeTimetableSlots(args.timetableSlots);
    const revisionWindows = normalizeRevisionWindows(args.revisionWindows);
    const weeklyStudyMinutes = normalizePositiveInt(args.weeklyStudyMinutes);
    const weeklySessionsTarget = normalizePositiveInt(args.weeklySessionsTarget);

    if (examFamily === "gcse" && isGcseCoreSubject(subject)) {
      const preferredBoard = gcsePreferredBoardForSubject(subject);
      if (
        preferredBoard &&
        board.toLowerCase() !== preferredBoard.toLowerCase()
      ) {
        throw new Error(
          `${subject} is currently locked to ${preferredBoard} in GCSE core mode.`
        );
      }
    }

    if (makeActive) {
      const active = await ctx.db
        .query("userExamTargets")
        .withIndex("by_user_id_and_is_active_and_updated_at", (q) =>
          q.eq("userId", userId).eq("isActive", true)
        )
        .collect();

      for (const item of active) {
        await ctx.db.patch(item._id, {
          isActive: false,
          updatedAt: now,
        });
      }
    }

    const id = await ctx.db.insert("userExamTargets", {
      userId,
      countryCode: args.countryCode.trim().toUpperCase(),
      countryName: args.countryName.trim(),
      examFamily,
      board,
      level: args.level.trim(),
      subject,
      year: args.year,
      currentGrade,
      targetGrade,
      mockDateAt,
      examDateAt,
      timetableMode,
      timetableProvider,
      timetableSyncedAt,
      timetableSummary,
      timetableSourceText,
      timetableSlots,
      revisionWindows,
      weeklyStudyMinutes,
      weeklySessionsTarget,
      intentQuery: args.intentQuery?.trim() || undefined,
      sourceCatalogSlug: args.sourceCatalogSlug?.trim() || undefined,
      isActive: makeActive,
      createdAt: now,
      updatedAt: now,
    });

    return id;
  },
});

export const updateTargetGrades = mutation({
  args: {
    targetId: v.id("userExamTargets"),
    currentGrade: v.optional(v.string()),
    targetGrade: v.optional(v.string()),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const target = await ctx.db.get(args.targetId);
    if (!target || target.userId !== userId) {
      throw new Error("Target not found");
    }

    const now = Date.now();
    await ctx.db.patch(args.targetId, {
      currentGrade: normalizeGcseGrade(args.currentGrade),
      targetGrade: normalizeGcseGrade(args.targetGrade),
      updatedAt: now,
    });

    return null;
  },
});

export const updateTargetPlanning = mutation({
  args: {
    targetId: v.id("userExamTargets"),
    mockDateAt: v.optional(v.union(v.number(), v.null())),
    examDateAt: v.optional(v.union(v.number(), v.null())),
    timetableMode: v.optional(v.union(v.string(), v.null())),
    timetableProvider: v.optional(v.union(v.string(), v.null())),
    timetableSyncedAt: v.optional(v.union(v.number(), v.null())),
    timetableSummary: v.optional(v.union(v.string(), v.null())),
    timetableSourceText: v.optional(v.union(v.string(), v.null())),
    timetableSlots: v.optional(
      v.union(
        v.array(
          v.object({
            day: v.string(),
            start: v.string(),
            end: v.string(),
            subject: v.string(),
          })
        ),
        v.null()
      )
    ),
    revisionWindows: v.optional(
      v.union(
        v.array(
          v.object({
            day: v.string(),
            start: v.string(),
            end: v.string(),
            durationMinutes: v.number(),
          })
        ),
        v.null()
      )
    ),
    weeklyStudyMinutes: v.optional(v.union(v.number(), v.null())),
    weeklySessionsTarget: v.optional(v.union(v.number(), v.null())),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const target = await ctx.db.get(args.targetId);
    if (!target || target.userId !== userId) {
      throw new Error("Target not found");
    }

    const patch: Record<string, any> = {
      updatedAt: Date.now(),
    };

    if (args.mockDateAt !== undefined) {
      patch.mockDateAt = normalizeTimestamp(args.mockDateAt);
    }
    if (args.examDateAt !== undefined) {
      patch.examDateAt = normalizeTimestamp(args.examDateAt);
    }
    if (args.timetableMode !== undefined) {
      patch.timetableMode = normalizeTimetableMode(args.timetableMode);
    }
    if (args.timetableProvider !== undefined) {
      patch.timetableProvider = normalizeOptionalText(args.timetableProvider, 120);
    }
    if (args.timetableSyncedAt !== undefined) {
      patch.timetableSyncedAt = normalizeTimestamp(args.timetableSyncedAt);
    }
    if (args.timetableSummary !== undefined) {
      patch.timetableSummary = normalizeOptionalText(args.timetableSummary, 300);
    }
    if (args.timetableSourceText !== undefined) {
      patch.timetableSourceText = normalizeOptionalText(
        args.timetableSourceText,
        16000
      );
    }
    if (args.timetableSlots !== undefined) {
      patch.timetableSlots = normalizeTimetableSlots(args.timetableSlots);
    }
    if (args.revisionWindows !== undefined) {
      patch.revisionWindows = normalizeRevisionWindows(args.revisionWindows);
    }
    if (args.weeklyStudyMinutes !== undefined) {
      patch.weeklyStudyMinutes = normalizePositiveInt(args.weeklyStudyMinutes);
    }
    if (args.weeklySessionsTarget !== undefined) {
      patch.weeklySessionsTarget = normalizePositiveInt(args.weeklySessionsTarget);
    }

    await ctx.db.patch(args.targetId, patch);
    return null;
  },
});

export const setGcseTimetablePlan = mutation({
  args: {
    timetableMode: v.optional(v.union(v.string(), v.null())),
    timetableProvider: v.optional(v.union(v.string(), v.null())),
    timetableSyncedAt: v.optional(v.union(v.number(), v.null())),
    timetableSummary: v.optional(v.union(v.string(), v.null())),
    timetableSourceText: v.optional(v.union(v.string(), v.null())),
    timetableSlots: v.optional(
      v.union(
        v.array(
          v.object({
            day: v.string(),
            start: v.string(),
            end: v.string(),
            subject: v.string(),
          })
        ),
        v.null()
      )
    ),
    revisionWindows: v.optional(
      v.union(
        v.array(
          v.object({
            day: v.string(),
            start: v.string(),
            end: v.string(),
            durationMinutes: v.number(),
          })
        ),
        v.null()
      )
    ),
    weeklyStudyMinutes: v.optional(v.union(v.number(), v.null())),
    weeklySessionsTarget: v.optional(v.union(v.number(), v.null())),
  },
  returns: v.object({
    updatedTargets: v.number(),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const now = Date.now();
    const targets = await ctx.db
      .query("userExamTargets")
      .withIndex("by_user_id_and_updated_at", (q) => q.eq("userId", userId))
      .collect();

    const gcseTargets = targets.filter(
      (target) => String(target.examFamily ?? "").toLowerCase() === "gcse"
    );

    for (const target of gcseTargets) {
      const patch: Record<string, any> = {
        updatedAt: now,
      };
      if (args.timetableMode !== undefined) {
        patch.timetableMode = normalizeTimetableMode(args.timetableMode);
      }
      if (args.timetableProvider !== undefined) {
        patch.timetableProvider = normalizeOptionalText(args.timetableProvider, 120);
      }
      if (args.timetableSyncedAt !== undefined) {
        patch.timetableSyncedAt = normalizeTimestamp(args.timetableSyncedAt);
      }
      if (args.timetableSummary !== undefined) {
        patch.timetableSummary = normalizeOptionalText(args.timetableSummary, 300);
      }
      if (args.timetableSourceText !== undefined) {
        patch.timetableSourceText = normalizeOptionalText(
          args.timetableSourceText,
          16000
        );
      }
      if (args.timetableSlots !== undefined) {
        patch.timetableSlots = normalizeTimetableSlots(args.timetableSlots);
      }
      if (args.revisionWindows !== undefined) {
        patch.revisionWindows = normalizeRevisionWindows(args.revisionWindows);
      }
      if (args.weeklyStudyMinutes !== undefined) {
        patch.weeklyStudyMinutes = normalizePositiveInt(args.weeklyStudyMinutes);
      }
      if (args.weeklySessionsTarget !== undefined) {
        patch.weeklySessionsTarget = normalizePositiveInt(args.weeklySessionsTarget);
      }
      await ctx.db.patch(target._id, patch);
    }

    return {
      updatedTargets: gcseTargets.length,
    };
  },
});

export const setActiveTarget = mutation({
  args: {
    targetId: v.id("userExamTargets"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const target = await ctx.db.get(args.targetId);
    if (!target || target.userId !== userId) {
      throw new Error("Target not found");
    }

    const now = Date.now();
    const active = await ctx.db
      .query("userExamTargets")
      .withIndex("by_user_id_and_is_active_and_updated_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .collect();
    for (const item of active) {
      if (item._id === args.targetId) continue;
      await ctx.db.patch(item._id, {
        isActive: false,
        updatedAt: now,
      });
    }

    await ctx.db.patch(args.targetId, {
      isActive: true,
      updatedAt: now,
    });

    return null;
  },
});

export const archiveTarget = mutation({
  args: {
    targetId: v.id("userExamTargets"),
  },
  returns: v.null(),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const target = await ctx.db.get(args.targetId);
    if (!target || target.userId !== userId) {
      throw new Error("Target not found");
    }

    const now = Date.now();
    await ctx.db.patch(args.targetId, {
      isActive: false,
      updatedAt: now,
    });

    const replacement = await ctx.db
      .query("userExamTargets")
      .withIndex("by_user_id_and_updated_at", (q) => q.eq("userId", userId))
      .order("desc")
      .collect();
    const next = replacement.find(
      (row) => row._id !== args.targetId && row.isActive !== true
    );
    if (target.isActive && next) {
      await ctx.db.patch(next._id, {
        isActive: true,
        updatedAt: now,
      });
    }

    return null;
  },
});

export const clearMyTarget = mutation({
  args: {},
  returns: v.null(),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const now = Date.now();

    const active = await ctx.db
      .query("userExamTargets")
      .withIndex("by_user_id_and_is_active_and_updated_at", (q) =>
        q.eq("userId", userId).eq("isActive", true)
      )
      .collect();

    for (const item of active) {
      await ctx.db.patch(item._id, {
        isActive: false,
        updatedAt: now,
      });
    }

    return null;
  },
});

export const getMyExamProfile = query({
  args: {
    targetId: v.id("userExamTargets"),
  },
  returns: v.object({
    target: v.union(v.null(), userExamTargetValidator),
    sourceCount: v.number(),
    sections: v.array(examCurriculumSectionValidator),
    papers: v.array(examCurriculumPaperValidator),
    examTechniques: v.array(examTechniqueValidator),
    pitfalls: v.array(examPitfallValidator),
    priorityPitfalls: v.array(examPitfallValidator),
    weaknessTags: v.array(v.string()),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const target = await ctx.db.get(args.targetId);
    if (!target || target.userId !== userId) {
      return {
        target: null,
        sourceCount: 0,
        sections: [],
        papers: [],
        examTechniques: [],
        pitfalls: [],
        priorityPitfalls: [],
        weaknessTags: [],
      };
    }

    const entries = await getKnowledgeEntriesForTarget(ctx, target);
    const sectionsById = new Map<string, any>();
    const papersById = new Map<string, any>();
    const techniquesByLabel = new Map<string, any>();
    const pitfallsByTag = new Map<string, any>();

    for (const entry of entries) {
      const sourceType = String(entry.sourceType ?? "").toLowerCase();
      const parsed = parseJsonContent(entry.content);
      if (!parsed) continue;

      if (sourceType === "curriculum_map" || sourceType === "curriculum") {
        const sectionRows = Array.isArray(parsed.sections) ? parsed.sections : [];
        for (let i = 0; i < sectionRows.length; i += 1) {
          const normalized = normalizeSection(sectionRows[i], `section_${i + 1}`);
          if (normalized) sectionsById.set(normalized.id, normalized);
        }

        const paperRows = Array.isArray(parsed.papers) ? parsed.papers : [];
        for (let i = 0; i < paperRows.length; i += 1) {
          const normalized = normalizePaper(paperRows[i], `paper_${i + 1}`);
          if (normalized) papersById.set(normalized.id, normalized);
        }

        const techniqueRows = Array.isArray(parsed.examTechniques)
          ? parsed.examTechniques
          : Array.isArray(parsed.techniques)
          ? parsed.techniques
          : [];
        for (const row of techniqueRows) {
          const normalized = normalizeTechnique(row);
          if (!normalized) continue;
          techniquesByLabel.set(normalized.label.toLowerCase(), normalized);
        }
        continue;
      }

      if (sourceType === "subtopic_map") {
        const sectionRows = Array.isArray(parsed)
          ? parsed
          : Array.isArray(parsed.sections)
          ? parsed.sections
          : [];
        for (let i = 0; i < sectionRows.length; i += 1) {
          const normalized = normalizeSection(sectionRows[i], `section_${i + 1}`);
          if (normalized) sectionsById.set(normalized.id, normalized);
        }
        continue;
      }

      if (sourceType === "paper_breakdown") {
        const paperRows = Array.isArray(parsed)
          ? parsed
          : Array.isArray(parsed.papers)
          ? parsed.papers
          : [];
        for (let i = 0; i < paperRows.length; i += 1) {
          const normalized = normalizePaper(paperRows[i], `paper_${i + 1}`);
          if (normalized) papersById.set(normalized.id, normalized);
        }
        continue;
      }

      if (sourceType === "exam_technique") {
        const techniqueRows = Array.isArray(parsed)
          ? parsed
          : Array.isArray(parsed.techniques)
          ? parsed.techniques
          : [];
        for (const row of techniqueRows) {
          const normalized = normalizeTechnique(row);
          if (!normalized) continue;
          techniquesByLabel.set(normalized.label.toLowerCase(), normalized);
        }
        continue;
      }

      if (sourceType === "examiner_report") {
        const pitfallRows = Array.isArray(parsed)
          ? parsed
          : Array.isArray(parsed.pitfalls)
          ? parsed.pitfalls
          : [];
        for (const row of pitfallRows) {
          const normalized = normalizePitfall(row);
          if (!normalized) continue;
          pitfallsByTag.set(normalized.tag.toLowerCase(), normalized);
        }
      }
    }

    const sections = Array.from(sectionsById.values()).sort((a, b) =>
      a.title.localeCompare(b.title)
    );
    const papers = Array.from(papersById.values()).sort((a, b) =>
      a.title.localeCompare(b.title)
    );
    const examTechniques = Array.from(techniquesByLabel.values()).sort((a, b) =>
      a.label.localeCompare(b.label)
    );
    const pitfalls = Array.from(pitfallsByTag.values()).sort(
      (a, b) => b.severity - a.severity
    );

    const attempts = await ctx.db
      .query("challengeAttempts")
      .withIndex("by_user_id_and_exam_target_id_and_created_at", (q) =>
        q.eq("userId", userId).eq("examTargetId", target._id)
      )
      .collect();

    const challengeTopicCache = new Map<string, string>();
    const weakTopicScores = new Map<string, { total: number; count: number }>();

    for (const attempt of attempts) {
      let marksPct: number | undefined;
      if (
        attempt.marksAwarded !== undefined &&
        attempt.marksAvailable !== undefined &&
        attempt.marksAvailable > 0
      ) {
        marksPct = attempt.marksAwarded / attempt.marksAvailable;
      } else if (attempt.accuracy !== undefined) {
        marksPct = attempt.accuracy;
      }
      if (marksPct === undefined) continue;

      const challengeId = attempt.challengeId?.toString();
      if (!challengeId) continue;

      let topicName = challengeTopicCache.get(challengeId);
      if (!topicName) {
        const challenge = await ctx.db.get(attempt.challengeId);
        if (challenge?.topic && challenge.topic.trim().length > 0) {
          topicName = challenge.topic.trim();
        } else if (challenge?.topicId) {
          const topic = await ctx.db.get(challenge.topicId);
          if (topic?.name) topicName = topic.name;
        }
        if (!topicName) topicName = "general";
        challengeTopicCache.set(challengeId, topicName);
      }

      const key = topicName.toLowerCase();
      const current = weakTopicScores.get(key) ?? { total: 0, count: 0 };
      current.total += marksPct;
      current.count += 1;
      weakTopicScores.set(key, current);
    }

    const weakTopics = Array.from(weakTopicScores.entries())
      .map(([topic, score]) => ({
        topic,
        avg: score.count > 0 ? score.total / score.count : 1,
      }))
      .filter((row) => row.avg < 0.65)
      .sort((a, b) => a.avg - b.avg)
      .slice(0, 6);
    const weakTopicNames = weakTopics.map((row) => row.topic);

    const priorityPitfalls = [...pitfalls]
      .map((pitfall) => {
        const pitfallTopics = pitfall.relatedTopics.map((topic: string) =>
          topic.toLowerCase()
        );
        const hasTopicMatch = weakTopicNames.some(
          (weakTopic) =>
            pitfallTopics.some(
              (pitfallTopic: string) =>
                weakTopic.includes(pitfallTopic) || pitfallTopic.includes(weakTopic)
            ) || weakTopic.includes(pitfall.tag.toLowerCase())
        );
        const score = pitfall.severity + (hasTopicMatch ? 2 : 0);
        return {
          ...pitfall,
          _score: score,
        };
      })
      .sort((a, b) => b._score - a._score)
      .slice(0, 6)
      .map(({ _score, ...rest }) => rest);

    const weaknessTags = priorityPitfalls
      .map((pitfall) => pitfall.tag)
      .filter((tag) => tag.trim().length > 0)
      .slice(0, 4);

    return {
      target,
      sourceCount: entries.length,
      sections,
      papers,
      examTechniques,
      pitfalls,
      priorityPitfalls,
      weaknessTags,
    };
  },
});

const DAY_MS = 86400000;

export const getMyExamDashboard = query({
  args: {
    targetId: v.optional(v.id("userExamTargets")),
  },
  returns: v.object({
    target: v.union(v.null(), userExamTargetValidator),
    currentGrade: v.optional(v.string()),
    targetGrade: v.optional(v.string()),
    projectedGrade: v.number(),
    gradeGapToTarget: v.number(),
    gradeStatus: v.string(),
    totalAttempts: v.number(),
    completedAttempts: v.number(),
    avgAccuracy: v.number(),
    avgMarksPct: v.number(),
    bestMarksPct: v.number(),
    totalStudySeconds: v.number(),
    lastAttemptedAt: v.number(),
    trend7d: v.array(examTrendPointValidator),
    weakTopics: v.array(examWeakTopicValidator),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);

    let target = args.targetId
      ? await ctx.db.get(args.targetId)
      : await ctx.db
          .query("userExamTargets")
          .withIndex("by_user_id_and_is_active_and_updated_at", (q) =>
            q.eq("userId", userId).eq("isActive", true)
          )
          .order("desc")
          .first();

    if (!target && !args.targetId) {
      target = await ctx.db
        .query("userExamTargets")
        .withIndex("by_user_id_and_updated_at", (q) => q.eq("userId", userId))
        .order("desc")
        .first();
    }

    if (!target || target.userId !== userId) {
      return {
        target: null,
        projectedGrade: 0,
        gradeGapToTarget: 0,
        gradeStatus: "no_target",
        totalAttempts: 0,
        completedAttempts: 0,
        avgAccuracy: 0,
        avgMarksPct: 0,
        bestMarksPct: 0,
        totalStudySeconds: 0,
        lastAttemptedAt: 0,
        trend7d: [],
        weakTopics: [],
      };
    }

    const attempts = await ctx.db
      .query("challengeAttempts")
      .withIndex("by_user_id_and_exam_target_id_and_created_at", (q) =>
        q.eq("userId", userId).eq("examTargetId", target._id)
      )
      .collect();

    const now = Date.now();
    const todayStart = Math.floor(now / DAY_MS) * DAY_MS;
    const trendBuckets = new Map<number, { attempts: number; marksSum: number; marksCount: number }>();
    for (let i = 0; i < 7; i += 1) {
      const dayStart = todayStart - (6 - i) * DAY_MS;
      trendBuckets.set(dayStart, { attempts: 0, marksSum: 0, marksCount: 0 });
    }

    let totalAttempts = 0;
    let completedAttempts = 0;
    let totalStudySeconds = 0;
    let lastAttemptedAt = 0;

    let accuracySum = 0;
    let accuracyCount = 0;
    let marksPctSum = 0;
    let marksPctCount = 0;
    let bestMarksPct = 0;

    const challengeTopicCache = new Map<string, string>();
    const topicAgg = new Map<string, { attempts: number; marksSum: number; marksCount: number }>();

    const getMarksPct = (attempt: any): number | undefined => {
      if (
        attempt.marksAwarded !== undefined &&
        attempt.marksAvailable !== undefined &&
        attempt.marksAvailable > 0
      ) {
        return attempt.marksAwarded / attempt.marksAvailable;
      }
      if (attempt.accuracy !== undefined) return attempt.accuracy;
      return undefined;
    };

    for (const attempt of attempts) {
      totalAttempts += 1;
      if (attempt.completed) completedAttempts += 1;

      totalStudySeconds += attempt.timeTakenSeconds ?? 0;
      if ((attempt.createdAt ?? 0) > lastAttemptedAt) {
        lastAttemptedAt = attempt.createdAt ?? 0;
      }

      if (attempt.accuracy !== undefined) {
        accuracySum += attempt.accuracy;
        accuracyCount += 1;
      }

      const marksPct = getMarksPct(attempt);
      if (marksPct !== undefined) {
        marksPctSum += marksPct;
        marksPctCount += 1;
        if (marksPct > bestMarksPct) bestMarksPct = marksPct;
      }

      const attemptDay = Math.floor((attempt.createdAt ?? 0) / DAY_MS) * DAY_MS;
      const bucket = trendBuckets.get(attemptDay);
      if (bucket) {
        bucket.attempts += 1;
        if (marksPct !== undefined) {
          bucket.marksSum += marksPct;
          bucket.marksCount += 1;
        }
      }

      const challengeId = attempt.challengeId?.toString();
      if (!challengeId) continue;

      let topicName = challengeTopicCache.get(challengeId);
      if (!topicName) {
        const challenge = await ctx.db.get(attempt.challengeId);
        if (challenge?.topic && challenge.topic.trim().length > 0) {
          topicName = challenge.topic.trim();
        } else if (challenge?.topicId) {
          const topic = await ctx.db.get(challenge.topicId);
          if (topic?.name) topicName = topic.name;
        }
        if (!topicName) topicName = "General";
        challengeTopicCache.set(challengeId, topicName);
      }

      const current = topicAgg.get(topicName) ?? {
        attempts: 0,
        marksSum: 0,
        marksCount: 0,
      };
      current.attempts += 1;
      if (marksPct !== undefined) {
        current.marksSum += marksPct;
        current.marksCount += 1;
      }
      topicAgg.set(topicName, current);
    }

    const trend7d = Array.from(trendBuckets.entries())
      .sort((a, b) => a[0] - b[0])
      .map(([dayStart, bucket]) => ({
        dayStart,
        attempts: bucket.attempts,
        avgMarksPct:
          bucket.marksCount > 0 ? bucket.marksSum / bucket.marksCount : 0,
      }));

    const weakTopics = Array.from(topicAgg.entries())
      .map(([topic, agg]) => ({
        topic,
        attempts: agg.attempts,
        avgMarksPct: agg.marksCount > 0 ? agg.marksSum / agg.marksCount : 0,
      }))
      .filter((row) => row.attempts > 0)
      .sort((a, b) => {
        if (a.avgMarksPct !== b.avgMarksPct) return a.avgMarksPct - b.avgMarksPct;
        return b.attempts - a.attempts;
      })
      .slice(0, 5);

    const projectedGrade = marksPctCount > 0 ? estimateGcseGrade(marksPctSum / marksPctCount) : 0;
    const targetGradeNumber = Number.parseInt(String(target.targetGrade ?? ""), 10);
    const hasTargetGrade = Number.isFinite(targetGradeNumber) && targetGradeNumber > 0;
    const gradeGapToTarget = hasTargetGrade && projectedGrade > 0
      ? Math.max(0, targetGradeNumber - projectedGrade)
      : 0;
    let gradeStatus = "no_target";
    if (hasTargetGrade) {
      if (projectedGrade >= targetGradeNumber) {
        gradeStatus = "on_track";
      } else if (projectedGrade + 1 >= targetGradeNumber) {
        gradeStatus = "close";
      } else {
        gradeStatus = "at_risk";
      }
    }

    return {
      target,
      ...(target.currentGrade ? { currentGrade: target.currentGrade } : {}),
      ...(target.targetGrade ? { targetGrade: target.targetGrade } : {}),
      projectedGrade,
      gradeGapToTarget,
      gradeStatus,
      totalAttempts,
      completedAttempts,
      avgAccuracy: accuracyCount > 0 ? accuracySum / accuracyCount : 0,
      avgMarksPct: marksPctCount > 0 ? marksPctSum / marksPctCount : 0,
      bestMarksPct,
      totalStudySeconds,
      lastAttemptedAt,
      trend7d,
      weakTopics,
    };
  },
});

const examReportPeriodValidator = v.union(
  v.literal("daily"),
  v.literal("weekly"),
  v.literal("monthly")
);

export const getMyExamSubjectReport = query({
  args: {
    targetId: v.id("userExamTargets"),
    period: examReportPeriodValidator,
  },
  returns: v.object({
    target: v.union(v.null(), userExamTargetValidator),
    period: examReportPeriodValidator,
    windowStart: v.number(),
    windowEnd: v.number(),
    previousWindowStart: v.number(),
    totalAttempts: v.number(),
    completedAttempts: v.number(),
    avgAccuracy: v.number(),
    avgMarksPct: v.number(),
    bestMarksPct: v.number(),
    totalStudySeconds: v.number(),
    marksDeltaPct: v.number(),
    accuracyDeltaPct: v.number(),
    consistency: v.object({
      activeDays: v.number(),
      windowDays: v.number(),
      consistencyPct: v.number(),
      completionRate: v.number(),
      sessionsPerActiveDay: v.number(),
      dailyMinutes: v.number(),
      cadenceDelta: v.number(),
    }),
    progression: v.object({
      trendSlopePct: v.number(),
      volatilityPct: v.number(),
      bestRunDays: v.number(),
      momentumLabel: v.string(),
    }),
    execution: v.object({
      avgSecondsPerAttempt: v.number(),
      avgSecondsPerQuestion: v.number(),
      speedAccuracySignal: v.string(),
      questionsEstimated: v.number(),
    }),
    errorProfile: v.array(examReportReasonProfileValidator),
    motivation: v.object({
      wins: v.array(v.string()),
      nextMilestone: v.string(),
    }),
    insightActions: v.array(examReportInsightActionValidator),
    trend: v.array(examTrendPointValidator),
    topicBreakdown: v.array(examWeakTopicValidator),
  }),
  handler: async (ctx, args) => {
    const userId = await requireUser(ctx);
    const target = await ctx.db.get(args.targetId);
    if (!target || target.userId !== userId) {
      return {
        target: null,
        period: args.period,
        windowStart: 0,
        windowEnd: 0,
        previousWindowStart: 0,
        totalAttempts: 0,
        completedAttempts: 0,
        avgAccuracy: 0,
        avgMarksPct: 0,
        bestMarksPct: 0,
        totalStudySeconds: 0,
        marksDeltaPct: 0,
        accuracyDeltaPct: 0,
        consistency: {
          activeDays: 0,
          windowDays: 0,
          consistencyPct: 0,
          completionRate: 0,
          sessionsPerActiveDay: 0,
          dailyMinutes: 0,
          cadenceDelta: 0,
        },
        progression: {
          trendSlopePct: 0,
          volatilityPct: 0,
          bestRunDays: 0,
          momentumLabel: "build_evidence",
        },
        execution: {
          avgSecondsPerAttempt: 0,
          avgSecondsPerQuestion: 0,
          speedAccuracySignal: "insufficient_data",
          questionsEstimated: 0,
        },
        errorProfile: [],
        motivation: {
          wins: ["Run a few sessions to unlock detailed progress insights."],
          nextMilestone: "Complete 3 exam sessions this week to unlock trajectory analysis.",
        },
        insightActions: [],
        trend: [],
        topicBreakdown: [],
      };
    }

    const now = Date.now();
    const todayStart = Math.floor(now / DAY_MS) * DAY_MS;
    const windowDays = args.period === "daily" ? 1 : args.period === "weekly" ? 7 : 30;
    const trendDays = args.period === "daily" ? 7 : args.period === "weekly" ? 14 : 30;
    const windowStart = todayStart - (windowDays - 1) * DAY_MS;
    const previousWindowStart = windowStart - windowDays * DAY_MS;
    const windowEnd = now;

    const attempts = await ctx.db
      .query("challengeAttempts")
      .withIndex("by_user_id_and_exam_target_id_and_created_at", (q) =>
        q.eq("userId", userId).eq("examTargetId", target._id)
      )
      .collect();

    const getMarksPct = (attempt: any): number | undefined => {
      if (
        attempt.marksAwarded !== undefined &&
        attempt.marksAvailable !== undefined &&
        attempt.marksAvailable > 0
      ) {
        return attempt.marksAwarded / attempt.marksAvailable;
      }
      if (attempt.accuracy !== undefined) return attempt.accuracy;
      return undefined;
    };

    const inCurrent = attempts.filter((attempt: any) =>
      (attempt.createdAt ?? 0) >= windowStart && (attempt.createdAt ?? 0) <= windowEnd
    );
    const inPrevious = attempts.filter((attempt: any) =>
      (attempt.createdAt ?? 0) >= previousWindowStart && (attempt.createdAt ?? 0) < windowStart
    );

    const aggregate = (rows: any[]) => {
      let totalAttempts = 0;
      let completedAttempts = 0;
      let totalStudySeconds = 0;
      let marksSum = 0;
      let marksCount = 0;
      let accuracySum = 0;
      let accuracyCount = 0;
      let bestMarksPct = 0;

      for (const attempt of rows) {
        totalAttempts += 1;
        if (attempt.completed) completedAttempts += 1;
        totalStudySeconds += attempt.timeTakenSeconds ?? 0;

        if (attempt.accuracy !== undefined) {
          accuracySum += attempt.accuracy;
          accuracyCount += 1;
        }
        const marksPct = getMarksPct(attempt);
        if (marksPct !== undefined) {
          marksSum += marksPct;
          marksCount += 1;
          if (marksPct > bestMarksPct) bestMarksPct = marksPct;
        }
      }

      return {
        totalAttempts,
        completedAttempts,
        totalStudySeconds,
        avgAccuracy: accuracyCount > 0 ? accuracySum / accuracyCount : 0,
        avgMarksPct: marksCount > 0 ? marksSum / marksCount : 0,
        bestMarksPct,
      };
    };

    const currentAgg = aggregate(inCurrent);
    const previousAgg = aggregate(inPrevious);

    const marksDeltaPct = currentAgg.avgMarksPct - previousAgg.avgMarksPct;
    const accuracyDeltaPct = currentAgg.avgAccuracy - previousAgg.avgAccuracy;

    const trendBuckets = new Map<
      number,
      { attempts: number; marksSum: number; marksCount: number }
    >();
    for (let i = 0; i < trendDays; i += 1) {
      const dayStart = todayStart - (trendDays - 1 - i) * DAY_MS;
      trendBuckets.set(dayStart, { attempts: 0, marksSum: 0, marksCount: 0 });
    }

    for (const attempt of attempts) {
      const day = Math.floor((attempt.createdAt ?? 0) / DAY_MS) * DAY_MS;
      const bucket = trendBuckets.get(day);
      if (!bucket) continue;
      bucket.attempts += 1;
      const marksPct = getMarksPct(attempt);
      if (marksPct !== undefined) {
        bucket.marksSum += marksPct;
        bucket.marksCount += 1;
      }
    }

    const trend = Array.from(trendBuckets.entries())
      .sort((a, b) => a[0] - b[0])
      .map(([dayStart, bucket]) => ({
        dayStart,
        attempts: bucket.attempts,
        avgMarksPct:
          bucket.marksCount > 0 ? bucket.marksSum / bucket.marksCount : 0,
      }));

    const challengeTopicCache = new Map<string, string>();
    const topicAgg = new Map<string, { attempts: number; marksSum: number; marksCount: number }>();
    for (const attempt of inCurrent) {
      const challengeId = attempt.challengeId?.toString();
      if (!challengeId) continue;

      let topicName = challengeTopicCache.get(challengeId);
      if (!topicName) {
        const challenge = await ctx.db.get(attempt.challengeId);
        if (challenge?.topic && challenge.topic.trim().length > 0) {
          topicName = challenge.topic.trim();
        } else if (challenge?.topicId) {
          const topic = await ctx.db.get(challenge.topicId);
          if (topic?.name) topicName = topic.name;
        }
        if (!topicName) topicName = "General";
        challengeTopicCache.set(challengeId, topicName);
      }

      const existing = topicAgg.get(topicName) ?? {
        attempts: 0,
        marksSum: 0,
        marksCount: 0,
      };
      existing.attempts += 1;
      const marksPct = getMarksPct(attempt);
      if (marksPct !== undefined) {
        existing.marksSum += marksPct;
        existing.marksCount += 1;
      }
      topicAgg.set(topicName, existing);
    }

    const topicBreakdown = Array.from(topicAgg.entries())
      .map(([topic, agg]) => ({
        topic,
        attempts: agg.attempts,
        avgMarksPct: agg.marksCount > 0 ? agg.marksSum / agg.marksCount : 0,
      }))
      .sort((a, b) => {
        if (a.avgMarksPct !== b.avgMarksPct) return a.avgMarksPct - b.avgMarksPct;
        return b.attempts - a.attempts;
      })
      .slice(0, 10);

    const currentActiveDaySet = new Set<number>(
      inCurrent
        .map((attempt: any) => Math.floor((attempt.createdAt ?? 0) / DAY_MS))
        .filter((day: number) => day > 0)
    );
    const activeDays = currentActiveDaySet.size;
    const completionRate =
      currentAgg.totalAttempts > 0
        ? currentAgg.completedAttempts / currentAgg.totalAttempts
        : 0;
    const consistencyPct = windowDays > 0 ? activeDays / windowDays : 0;
    const sessionsPerActiveDay =
      activeDays > 0 ? currentAgg.totalAttempts / activeDays : 0;
    const dailyMinutes =
      windowDays > 0 ? currentAgg.totalStudySeconds / 60 / windowDays : 0;
    const weeklySessionsTarget =
      typeof target.weeklySessionsTarget === "number"
        ? Math.max(0, Math.floor(target.weeklySessionsTarget))
        : 0;
    const targetSessionsForWindow =
      weeklySessionsTarget > 0
        ? (weeklySessionsTarget / 7) * windowDays
        : 0;
    const cadenceDelta = currentAgg.totalAttempts - targetSessionsForWindow;

    const trendWithAttempts = trend.filter((point) => point.attempts > 0);
    let trendSlopePct = 0;
    if (trendWithAttempts.length >= 2) {
      const n = trendWithAttempts.length;
      let sumX = 0;
      let sumY = 0;
      let sumXY = 0;
      let sumXX = 0;
      for (let i = 0; i < n; i += 1) {
        const x = i;
        const y = trendWithAttempts[i].avgMarksPct;
        sumX += x;
        sumY += y;
        sumXY += x * y;
        sumXX += x * x;
      }
      const denominator = n * sumXX - sumX * sumX;
      if (denominator !== 0) {
        trendSlopePct = ((n * sumXY - sumX * sumY) / denominator) * 100;
      }
    }

    let volatilityPct = 0;
    if (trendWithAttempts.length > 0) {
      const mean =
        trendWithAttempts.reduce((sum, point) => sum + point.avgMarksPct, 0) /
        trendWithAttempts.length;
      const variance =
        trendWithAttempts.reduce((sum, point) => {
          const diff = point.avgMarksPct - mean;
          return sum + diff * diff;
        }, 0) / trendWithAttempts.length;
      volatilityPct = Math.sqrt(Math.max(0, variance)) * 100;
    }

    let bestRunDays = 0;
    let currentRun = 0;
    for (const point of trend) {
      if (point.attempts > 0) {
        currentRun += 1;
        if (currentRun > bestRunDays) bestRunDays = currentRun;
      } else {
        currentRun = 0;
      }
    }

    const momentumLabel =
      marksDeltaPct >= 0.05 && completionRate >= 0.7
        ? "strong_upward"
        : marksDeltaPct >= 0.01
        ? "building"
        : marksDeltaPct <= -0.05
        ? "slipping"
        : "stable";

    const challengeQuestionCountCache = new Map<string, number>();
    let questionsEstimated = 0;
    for (const attempt of inCurrent) {
      if (Array.isArray(attempt.answers) && attempt.answers.length > 0) {
        questionsEstimated += attempt.answers.length;
        continue;
      }
      const challengeId = attempt.challengeId?.toString();
      if (!challengeId) continue;
      let questionCount = challengeQuestionCountCache.get(challengeId);
      if (questionCount === undefined) {
        const challenge = await ctx.db.get(attempt.challengeId);
        questionCount =
          typeof challenge?.questionCount === "number" && challenge.questionCount > 0
            ? Math.floor(challenge.questionCount)
            : 0;
        challengeQuestionCountCache.set(challengeId, questionCount);
      }
      questionsEstimated += Math.max(0, questionCount);
    }

    const avgSecondsPerAttempt =
      currentAgg.totalAttempts > 0
        ? currentAgg.totalStudySeconds / currentAgg.totalAttempts
        : 0;
    const avgSecondsPerQuestion =
      questionsEstimated > 0 ? currentAgg.totalStudySeconds / questionsEstimated : 0;
    const speedAccuracySignal =
      avgSecondsPerQuestion > 0 && avgSecondsPerQuestion < 45 && currentAgg.avgMarksPct < 0.55
        ? "rushing"
        : avgSecondsPerQuestion > 110 && currentAgg.avgMarksPct < 0.55
        ? "overthinking"
        : currentAgg.totalAttempts > 0
        ? "balanced"
        : "insufficient_data";

    const aggregateReasonCodes = (rows: any[]) => {
      const map = new Map<string, number>();
      for (const attempt of rows) {
        if (!Array.isArray(attempt.answers)) continue;
        for (const answer of attempt.answers) {
          const reasonCode = String(answer?.reasonCode ?? "").trim().toLowerCase();
          if (!reasonCode || reasonCode === "all_criteria_met") continue;
          map.set(reasonCode, (map.get(reasonCode) ?? 0) + 1);
        }
      }
      return map;
    };

    const currentReasonCounts = aggregateReasonCodes(inCurrent);
    const previousReasonCounts = aggregateReasonCodes(inPrevious);
    const currentReasonTotal = Array.from(currentReasonCounts.values()).reduce(
      (sum, count) => sum + count,
      0
    );
    const previousReasonTotal = Array.from(previousReasonCounts.values()).reduce(
      (sum, count) => sum + count,
      0
    );

    const errorProfile = Array.from(currentReasonCounts.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 4)
      .map(([code, count]) => {
        const share = currentReasonTotal > 0 ? count / currentReasonTotal : 0;
        const prevShare =
          previousReasonTotal > 0
            ? (previousReasonCounts.get(code) ?? 0) / previousReasonTotal
            : 0;
        return {
          code,
          label: examReasonLabelsFromCodes([code])[0] ?? formatReasonCodeLabel(code),
          count,
          share,
          deltaShare: share - prevShare,
        };
      });

    const topWeakTopic = topicBreakdown.length > 0 ? topicBreakdown[0].topic : "";
    const topReasonCode = errorProfile.length > 0 ? errorProfile[0].code : "";

    const insightActions: Array<{
      title: string;
      whyNow: string;
      whyItWorks: string;
      expectedGain: string;
      effortLabel: string;
      topic: string;
      quizPreset: any;
    }> = [];

    if (topWeakTopic) {
      const reasonCodes = ["weak_topic", ...(topReasonCode ? [topReasonCode] : [])];
      const methods = learningMethodsForSession("weak_focus", reasonCodes);
      const estimatedMinutes = 24;
      insightActions.push({
        title: "Repair weakest topic first",
        whyNow: `Current data shows the lowest marks concentration in ${topWeakTopic}.`,
        whyItWorks:
          methods.length > 0
            ? `${methods.join(" + ")} targets memory retrieval and error correction.`
            : "Focused retrieval and feedback improves retention and transfer.",
        expectedGain: expectedGainForSession("weak_focus", topWeakTopic, reasonCodes),
        effortLabel: effortLabelFromMinutes(estimatedMinutes),
        topic: `${target.subject} ${topWeakTopic}`,
        quizPreset: buildExamSessionPreset({
          sessionType: "weak_focus",
          recentMarks: currentAgg.avgMarksPct,
          questionCount: 14,
          includeHints: currentAgg.avgMarksPct < 0.6,
        }),
      });
    }

    if (topReasonCode) {
      const methods = learningMethodsForSession("weak_focus", [topReasonCode]);
      const reasonLabel = examReasonLabelsFromCodes([topReasonCode])[0] ??
        formatReasonCodeLabel(topReasonCode);
      const estimatedMinutes = 18;
      insightActions.push({
        title: "Run a reason-code correction drill",
        whyNow: `${reasonLabel} is currently the most frequent mark-loss pattern.`,
        whyItWorks:
          methods.length > 0
            ? `${methods.join(" + ")} reduces repeat errors under timed conditions.`
            : "Targeted correction drills reduce repeated mark losses.",
        expectedGain: expectedGainForSession("weak_focus", reasonLabel, [topReasonCode]),
        effortLabel: effortLabelFromMinutes(estimatedMinutes),
        topic: `${target.subject} ${reasonLabel}`,
        quizPreset: buildExamSessionPreset({
          sessionType: "weak_focus",
          recentMarks: currentAgg.avgMarksPct,
          questionCount: 12,
          includeHints: true,
        }),
      });
    }

    if (insightActions.length < 3) {
      const estimatedMinutes = 20;
      insightActions.push({
        title: "Stabilize with timed mixed practice",
        whyNow: "Mixed retrieval strengthens exam transfer across topics.",
        whyItWorks:
          "Interleaving plus retrieval practice improves discrimination and long-term retention.",
        expectedGain: "Improve consistency and reduce score volatility in this subject.",
        effortLabel: effortLabelFromMinutes(estimatedMinutes),
        topic: `${target.subject} timed mixed practice`,
        quizPreset: buildExamSessionPreset({
          sessionType: "mixed_practice",
          recentMarks: currentAgg.avgMarksPct,
          questionCount: 12,
          includeHints: currentAgg.avgMarksPct < 0.55,
        }),
      });
    }

    const wins: string[] = [];
    if (marksDeltaPct > 0.01) {
      wins.push(`Marks improved by ${(marksDeltaPct * 100).toFixed(1)}% vs previous window.`);
    }
    if (completionRate >= 0.7 && currentAgg.totalAttempts > 0) {
      wins.push(`Strong completion quality: ${(completionRate * 100).toFixed(0)}% sessions completed.`);
    }
    if (activeDays >= Math.max(2, Math.ceil(windowDays * 0.4))) {
      wins.push(`Consistent revision rhythm: active on ${activeDays}/${windowDays} days.`);
    }
    if (bestRunDays >= 3) {
      wins.push(`Best run this period: ${bestRunDays} consecutive active days.`);
    }
    if (wins.length === 0) {
      wins.push("Starting signal collected. Each completed session improves personalization quality.");
    }

    const nextMilestone =
      currentAgg.avgMarksPct < 0.5
        ? "Next milestone: move your average marks above 55% with two focused sessions."
        : currentAgg.avgMarksPct < 0.62
        ? "Next milestone: stabilize above 62% average marks for this subject."
        : currentAgg.avgMarksPct < 0.72
        ? "Next milestone: push to 72% while maintaining current consistency."
        : "Next milestone: maintain this band and reduce volatility on weak topics.";

    return {
      target,
      period: args.period,
      windowStart,
      windowEnd,
      previousWindowStart,
      totalAttempts: currentAgg.totalAttempts,
      completedAttempts: currentAgg.completedAttempts,
      avgAccuracy: currentAgg.avgAccuracy,
      avgMarksPct: currentAgg.avgMarksPct,
      bestMarksPct: currentAgg.bestMarksPct,
      totalStudySeconds: currentAgg.totalStudySeconds,
      marksDeltaPct,
      accuracyDeltaPct,
      consistency: {
        activeDays,
        windowDays,
        consistencyPct,
        completionRate,
        sessionsPerActiveDay,
        dailyMinutes,
        cadenceDelta,
      },
      progression: {
        trendSlopePct,
        volatilityPct,
        bestRunDays,
        momentumLabel,
      },
      execution: {
        avgSecondsPerAttempt,
        avgSecondsPerQuestion,
        speedAccuracySignal,
        questionsEstimated,
      },
      errorProfile,
      motivation: {
        wins: wins.slice(0, 3),
        nextMilestone,
      },
      insightActions: insightActions.slice(0, 3),
      trend,
      topicBreakdown,
    };
  },
});

const GCSE_HOME_CORE_SUBJECTS = new Set<string>([
  "mathematics",
  "english language",
  "english literature",
  "biology",
  "chemistry",
  "physics",
]);

const EXAM_REASON_LABELS: Record<string, string> = {
  weak_topic: "Weak topic",
  recency_gap: "Not practiced recently",
  exam_soon: "Exam date approaching",
  target_gap: "Target grade gap",
  baseline_needed: "Build starting profile",
  maintain_momentum: "Keep momentum",
  build_evidence: "Needs more evidence",
  incomplete_reasoning: "Incomplete reasoning",
  missing_keyword: "Missing key term",
  calculation_error: "Calculation error",
  misread_prompt: "Misread question prompt",
  no_working: "No working shown",
};

const EXAM_REASON_SEVERITY: Record<string, number> = {
  weak_topic: 0.9,
  incomplete_reasoning: 0.85,
  missing_keyword: 0.8,
  misread_prompt: 0.78,
  calculation_error: 0.76,
  no_working: 0.72,
  exam_soon: 0.62,
  target_gap: 0.6,
  recency_gap: 0.52,
  baseline_needed: 0.5,
  build_evidence: 0.45,
  maintain_momentum: 0.32,
};

function reasonSeverity(code: string): number {
  return EXAM_REASON_SEVERITY[code] ?? 0.5;
}

function formatReasonCodeLabel(code: string): string {
  const formatted = code.replace(/[_-]+/g, " ").trim();
  if (!formatted) return code;
  return formatted
    .split(" ")
    .map((part) =>
      part.length > 0 ? part[0].toUpperCase() + part.slice(1) : part
    )
    .join(" ");
}

function examReasonLabelsFromCodes(codes: string[]): string[] {
  return Array.from(
    new Set(
      codes
        .map((code) => EXAM_REASON_LABELS[code] ?? formatReasonCodeLabel(code))
        .map((label) => label.trim())
        .filter((label) => label.length > 0)
    )
  );
}

function effortLabelFromMinutes(minutes: number): string {
  const safe = Math.max(10, Math.round(minutes));
  const lower = Math.max(10, Math.round(safe * 0.85));
  const upper = Math.max(lower + 2, Math.round(safe * 1.15));
  return `~${lower}-${upper} min`;
}

const SESSION_METHOD_PRIORS: Record<string, Array<{ method: string; weight: number }>> = {
  baseline: [
    { method: "Retrieval practice", weight: 1.0 },
    { method: "Metacognitive calibration", weight: 0.95 },
    { method: "Generation before feedback", weight: 0.7 },
  ],
  weak_focus: [
    { method: "Retrieval practice", weight: 1.0 },
    { method: "Spaced repetition", weight: 0.9 },
    { method: "Error-focused feedback", weight: 0.88 },
    { method: "Worked-example fading", weight: 0.66 },
  ],
  mixed_practice: [
    { method: "Interleaving", weight: 0.95 },
    { method: "Desirable difficulty", weight: 0.82 },
    { method: "Variability of practice", weight: 0.78 },
    { method: "Retrieval practice", weight: 0.75 },
  ],
};

const REASON_METHOD_RULES: Record<string, Array<{ method: string; weight: number }>> = {
  weak_topic: [
    { method: "Spaced repetition", weight: 0.9 },
    { method: "Retrieval practice", weight: 0.8 },
  ],
  recency_gap: [{ method: "Spaced repetition", weight: 0.75 }],
  missing_keyword: [
    { method: "Elaborative interrogation", weight: 0.82 },
    { method: "Dual coding", weight: 0.6 },
  ],
  incomplete_reasoning: [
    { method: "Self-explanation", weight: 0.88 },
    { method: "Worked-example fading", weight: 0.68 },
  ],
  misread_prompt: [{ method: "Command-word decoding", weight: 0.9 }],
  calculation_error: [{ method: "Error-focused feedback", weight: 0.84 }],
  no_working: [{ method: "Worked-example fading", weight: 0.7 }],
};

function learningMethodsForSession(
  sessionType: string,
  reasonCodes: string[]
): string[] {
  const scores = new Map<string, number>();

  const priors = SESSION_METHOD_PRIORS[sessionType] ?? [
    { method: "Retrieval practice", weight: 1.0 },
    { method: "Spaced repetition", weight: 0.7 },
  ];
  for (const { method, weight } of priors) {
    scores.set(method, (scores.get(method) ?? 0) + weight);
  }

  for (const code of reasonCodes) {
    const rules = REASON_METHOD_RULES[code] ?? [];
    for (const { method, weight } of rules) {
      scores.set(method, (scores.get(method) ?? 0) + weight);
    }
  }

  return Array.from(scores.entries())
    .sort((a, b) => b[1] - a[1])
    .map(([method]) => method)
    .slice(0, 2);
}

function actionLabelForSession(sessionType: string, topic: string): string {
  const normalized = topic.trim();
  const cleanTopic = normalized.length > 0 ? normalized : "this topic";
  switch (sessionType) {
    case "baseline":
      return `Build your baseline for ${cleanTopic}`;
    case "weak_focus":
      return `Repair weakest performance in ${cleanTopic}`;
    case "mixed_practice":
      return `Run mixed exam retrieval on ${cleanTopic}`;
    default:
      return `Run focused retrieval on ${cleanTopic}`;
  }
}

function expectedGainForSession(
  sessionType: string,
  topic: string,
  reasonCodes: string[]
): string {
  const lowerTopic = topic.trim();
  if (sessionType === "baseline") {
    return `Pinpoint weak areas and calibrate next sessions for ${lowerTopic}.`;
  }
  if (reasonCodes.includes("misread_prompt")) {
    return `Improve command-word accuracy in ${lowerTopic}.`;
  }
  if (reasonCodes.includes("missing_keyword")) {
    return `Improve mark-scheme keyword coverage in ${lowerTopic}.`;
  }
  if (reasonCodes.includes("incomplete_reasoning")) {
    return `Strengthen explanation depth for higher-mark answers in ${lowerTopic}.`;
  }
  if (reasonCodes.includes("calculation_error")) {
    return `Reduce avoidable calculation slips in ${lowerTopic}.`;
  }
  if (sessionType === "mixed_practice") {
    return `Stabilize exam performance across mixed ${lowerTopic} questions.`;
  }
  return `Lift marks on ${lowerTopic} through targeted retrieval.`;
}

function whyNowForSession(reasonLabels: string[]): string {
  if (reasonLabels.length > 0) {
    return reasonLabels[0];
  }
  return "Highest expected score gain right now";
}

function buildExamSessionPreset(opts: {
  sessionType: string;
  recentMarks: number;
  questionCount?: number;
  includeHints?: boolean;
}) {
  const safeMarks = Math.max(0, Math.min(1, opts.recentMarks));
  const isBaseline = opts.sessionType === "baseline";
  const profile = isBaseline ? "exam_baseline" : "exam_standard";
  const difficulty = isBaseline
    ? "Medium"
    : safeMarks < 0.45
    ? "Easy"
    : safeMarks < 0.7
    ? "Medium"
    : "Hard";
  const questionCountRaw = opts.questionCount ?? 10;
  const effectiveCount = isBaseline
    ? 24
    : Math.max(6, Math.min(20, Math.floor(questionCountRaw)));
  const timePerQuestion = isBaseline ? 75 : 70;
  const includeHints = opts.includeHints === true || isBaseline;
  return {
    questionCount: effectiveCount,
    timePerQuestion,
    totalTimeLimit: effectiveCount * timePerQuestion,
    timedMode: true,
    difficulty,
    includeCodeChallenges: false,
    includeMcqs: true,
    includeInput: true,
    includeFillBlank: false,
    includeHints,
    includeImageQuestions: false,
    examModeProfile: profile,
    autoStart: true,
  };
}

export const getGcseExamHome = query({
  args: {},
  returns: v.any(),
  handler: async (ctx) => {
    const userId = await requireUser(ctx);
    const targets = await ctx.db
      .query("userExamTargets")
      .withIndex("by_user_id_and_updated_at", (q) => q.eq("userId", userId))
      .collect();

    const gcseTargets = targets
      .filter((target) => {
        const family = String(target.examFamily ?? "").toLowerCase().trim();
        if (family !== "gcse") return false;
        const subject = String(target.subject ?? "").toLowerCase().trim();
        return GCSE_HOME_CORE_SUBJECTS.has(subject);
      })
      .sort((a, b) =>
        String(a.subject ?? "").localeCompare(String(b.subject ?? ""))
      );

    const reviseToday: Array<Record<string, any>> = [];
    const needsWork: Array<Record<string, any>> = [];
    const subjectProgress: Array<Record<string, any>> = [];
    const now = Date.now();
    const trailingDays = 14;
    const trailingStart = now - trailingDays * DAY_MS;
    const recentDailySeconds = new Map<number, number>();
    let recentAttemptCount = 0;

    let nearestMockInDays: number | null = null;
    let nearestGcseInDays: number | null = null;
    let atRiskCount = 0;
    let closeCount = 0;
    let onTrackCount = 0;
    let missingDateCount = 0;
    let timetableMode = "none";
    let weeklyStudyMinutes = 0;
    let weeklySessionsTarget = 0;

    const challengeTopicCache = new Map<string, string>();

    const getMarksPct = (attempt: any): number | undefined => {
      if (
        attempt.marksAwarded !== undefined &&
        attempt.marksAvailable !== undefined &&
        attempt.marksAvailable > 0
      ) {
        return attempt.marksAwarded / attempt.marksAvailable;
      }
      if (attempt.accuracy !== undefined) return attempt.accuracy;
      return undefined;
    };

    const daysUntil = (timestamp: number | undefined): number | null => {
      if (!timestamp || timestamp <= 0) return null;
      return Math.ceil((timestamp - now) / DAY_MS);
    };

    for (const target of gcseTargets) {
      const attempts = await ctx.db
        .query("challengeAttempts")
        .withIndex("by_user_id_and_exam_target_id_and_created_at", (q) =>
          q.eq("userId", userId).eq("examTargetId", target._id)
        )
        .collect();

      let totalAttempts = 0;
      let completedAttempts = 0;
      let totalStudySeconds = 0;
      let lastAttemptedAt = 0;
      let accuracySum = 0;
      let accuracyCount = 0;
      let marksPctSum = 0;
      let marksPctCount = 0;
      let bestMarksPct = 0;
      const reasonCounts = new Map<string, number>();
      const topicLastAttemptAt = new Map<string, number>();

      const topicAgg = new Map<string, { attempts: number; marksSum: number; marksCount: number }>();

      for (const attempt of attempts) {
        totalAttempts += 1;
        if (attempt.completed) completedAttempts += 1;
        totalStudySeconds += attempt.timeTakenSeconds ?? 0;
        if ((attempt.createdAt ?? 0) > lastAttemptedAt) {
          lastAttemptedAt = attempt.createdAt ?? 0;
        }

        if ((attempt.createdAt ?? 0) >= trailingStart) {
          const dayStart =
            Math.floor((attempt.createdAt ?? 0) / DAY_MS) * DAY_MS;
          const secs = Math.max(0, attempt.timeTakenSeconds ?? 0);
          recentDailySeconds.set(dayStart, (recentDailySeconds.get(dayStart) ?? 0) + secs);
          recentAttemptCount += 1;
        }

        if (attempt.accuracy !== undefined) {
          accuracySum += attempt.accuracy;
          accuracyCount += 1;
        }

        if (Array.isArray(attempt.answers)) {
          for (const answer of attempt.answers) {
            const reasonCode = String(answer?.reasonCode ?? "")
              .trim()
              .toLowerCase();
            if (!reasonCode) continue;
            reasonCounts.set(reasonCode, (reasonCounts.get(reasonCode) ?? 0) + 1);
          }
        }

        const marksPct = getMarksPct(attempt);
        if (marksPct !== undefined) {
          marksPctSum += marksPct;
          marksPctCount += 1;
          if (marksPct > bestMarksPct) bestMarksPct = marksPct;
        }

        const challengeId = attempt.challengeId?.toString();
        if (!challengeId) continue;

        let topicName = challengeTopicCache.get(challengeId);
        if (!topicName) {
          const challenge = await ctx.db.get(attempt.challengeId);
          if (challenge?.topic && challenge.topic.trim().length > 0) {
            topicName = challenge.topic.trim();
          } else if (challenge?.topicId) {
            const topic = await ctx.db.get(challenge.topicId);
            if (topic?.name) topicName = topic.name;
          }
          if (!topicName) topicName = "General";
          challengeTopicCache.set(challengeId, topicName);
        }

        const existing = topicAgg.get(topicName) ?? {
          attempts: 0,
          marksSum: 0,
          marksCount: 0,
        };
        existing.attempts += 1;
        if (marksPct !== undefined) {
          existing.marksSum += marksPct;
          existing.marksCount += 1;
        }
        topicAgg.set(topicName, existing);
        const attemptedAt = attempt.createdAt ?? 0;
        if (attemptedAt > 0) {
          topicLastAttemptAt.set(
            topicName,
            Math.max(topicLastAttemptAt.get(topicName) ?? 0, attemptedAt)
          );
        }
      }

      const avgMarksPct = marksPctCount > 0 ? marksPctSum / marksPctCount : 0;
      const projectedGrade =
        marksPctCount > 0 ? estimateGcseGrade(avgMarksPct) : 0;
      const targetGradeNumber = Number.parseInt(
        String(target.targetGrade ?? ""),
        10
      );
      const hasTargetGrade =
        Number.isFinite(targetGradeNumber) && targetGradeNumber > 0;
      const gradeGapToTarget =
        hasTargetGrade && projectedGrade > 0
          ? Math.max(0, targetGradeNumber - projectedGrade)
          : 0;

      let gradeStatus = "no_target";
      if (hasTargetGrade) {
        if (projectedGrade >= targetGradeNumber) {
          gradeStatus = "on_track";
        } else if (projectedGrade + 1 >= targetGradeNumber) {
          gradeStatus = "close";
        } else {
          gradeStatus = "at_risk";
        }
      }

      const weakTopics = Array.from(topicAgg.entries())
        .map(([topic, agg]) => ({
          topic,
          attempts: agg.attempts,
          avgMarksPct: agg.marksCount > 0 ? agg.marksSum / agg.marksCount : 0,
        }))
        .filter((row) => row.attempts > 0)
        .sort((a, b) => {
          if (a.avgMarksPct !== b.avgMarksPct) {
            return a.avgMarksPct - b.avgMarksPct;
          }
          return b.attempts - a.attempts;
        })
        .slice(0, 5);
      const topReasonCodes = Array.from(reasonCounts.entries())
        .sort(
          (a, b) =>
            b[1] * reasonSeverity(b[0]) - a[1] * reasonSeverity(a[0])
        )
        .map(([code]) => code)
        .slice(0, 2);
      const dominantReasonSeverity =
        topReasonCodes.length > 0 ? reasonSeverity(topReasonCodes[0]) : 0;

      const daysSinceLast =
        lastAttemptedAt > 0 ? Math.max(0, Math.floor((now - lastAttemptedAt) / DAY_MS)) : 365;

      const mockDateAt =
        typeof target.mockDateAt === "number" && target.mockDateAt > 0
          ? target.mockDateAt
          : undefined;
      const examDateAt =
        typeof target.examDateAt === "number" && target.examDateAt > 0
          ? target.examDateAt
          : undefined;
      const mockInDays = daysUntil(mockDateAt);
      const examInDays = daysUntil(examDateAt);
      const relevantDeadlines = [mockInDays, examInDays].filter(
        (days): days is number => typeof days === "number" && days >= 0
      );
      const nearestDeadlineInDays =
        relevantDeadlines.length > 0 ? Math.min(...relevantDeadlines) : null;
      const examUrgencyScore =
        nearestDeadlineInDays === null
          ? 0
          : Math.max(0, Math.min(1, 1 - nearestDeadlineInDays / 90));

      if (mockInDays === null && examInDays === null) {
        missingDateCount += 1;
      }
      if (mockInDays !== null) {
        nearestMockInDays =
          nearestMockInDays === null
            ? mockInDays
            : Math.min(nearestMockInDays, mockInDays);
      }
      if (examInDays !== null) {
        nearestGcseInDays =
          nearestGcseInDays === null
            ? examInDays
            : Math.min(nearestGcseInDays, examInDays);
      }

      if (gradeStatus === "at_risk") atRiskCount += 1;
      else if (gradeStatus === "close") closeCount += 1;
      else if (gradeStatus === "on_track") onTrackCount += 1;

      const targetTimetableMode =
        typeof target.timetableMode === "string"
          ? target.timetableMode.trim()
          : "";
      if (targetTimetableMode) timetableMode = targetTimetableMode;

      const targetWeeklyMinutes =
        typeof target.weeklyStudyMinutes === "number"
          ? Math.max(0, Math.floor(target.weeklyStudyMinutes))
          : 0;
      if (targetWeeklyMinutes > 0) weeklyStudyMinutes = targetWeeklyMinutes;

      const targetWeeklySessions =
        typeof target.weeklySessionsTarget === "number"
          ? Math.max(0, Math.floor(target.weeklySessionsTarget))
          : 0;
      if (targetWeeklySessions > 0) {
        weeklySessionsTarget = targetWeeklySessions;
      }

      subjectProgress.push({
        targetId: target._id,
        subject: target.subject ?? "Subject",
        board: target.board ?? "",
        totalAttempts,
        avgMarksPct,
        lastAttemptedAt,
        daysSinceLast,
        gradeStatus,
        gradeGapToTarget,
        mockDateAt: mockDateAt ?? null,
        examDateAt: examDateAt ?? null,
        mockInDays,
        examInDays,
        topReasonCodes,
        topReasonLabels: examReasonLabelsFromCodes(topReasonCodes),
      });

      if (weakTopics.length === 0) {
        if (totalAttempts === 0) {
          const reasonCodes = ["baseline_needed"];
          const reasonLabels = examReasonLabelsFromCodes(reasonCodes);
          const estimatedMinutes = 30;
          const sessionType = "baseline";
          const topic = "Baseline diagnostic";
          reviseToday.push({
            targetId: target._id,
            subject: target.subject ?? "Subject",
            topic,
            avgMarksPct: 0,
            attempts: 0,
            daysSinceLast,
            dueScore: 0.58 + examUrgencyScore * 0.18,
            estimatedMinutes,
            effortLabel: effortLabelFromMinutes(estimatedMinutes),
            sessionType,
            actionLabel: actionLabelForSession(sessionType, topic),
            reasonCodes,
            reasonLabels,
            whyNow: whyNowForSession(reasonLabels),
            expectedGain: expectedGainForSession(
              sessionType,
              String(target.subject ?? "this subject"),
              reasonCodes
            ),
            learningMethods: learningMethodsForSession(sessionType, reasonCodes),
            completedToday: false,
            confidence: 0.95,
            quizPreset: buildExamSessionPreset({
              sessionType,
              recentMarks: 0,
              questionCount: 24,
              includeHints: true,
            }),
          });
        } else if (daysSinceLast >= 5) {
          const reasonCodes = [
            ...(daysSinceLast >= 5 ? ["recency_gap"] : []),
            "maintain_momentum",
            ...(gradeGapToTarget > 0 ? ["target_gap"] : []),
            ...(examUrgencyScore > 0.4 ? ["exam_soon"] : []),
          ];
          const reasonLabels = examReasonLabelsFromCodes(reasonCodes);
          const estimatedMinutes = 25;
          const sessionType = "mixed_practice";
          const topic = "Timed mixed practice";
          reviseToday.push({
            targetId: target._id,
            subject: target.subject ?? "Subject",
            topic,
            avgMarksPct,
            attempts: totalAttempts,
            daysSinceLast,
            dueScore:
              0.5 +
              Math.min(1, daysSinceLast / 10) * 0.25 +
              examUrgencyScore * 0.15 +
              Math.min(1, gradeGapToTarget / 3) * 0.1 +
              dominantReasonSeverity * 0.06,
            estimatedMinutes,
            effortLabel: effortLabelFromMinutes(estimatedMinutes),
            sessionType,
            actionLabel: actionLabelForSession(sessionType, topic),
            reasonCodes,
            reasonLabels,
            whyNow: whyNowForSession(reasonLabels),
            expectedGain: expectedGainForSession(
              sessionType,
              String(target.subject ?? "this subject"),
              reasonCodes
            ),
            learningMethods: learningMethodsForSession(
              sessionType,
              reasonCodes
            ),
            completedToday: false,
            confidence: 0.72,
            quizPreset: buildExamSessionPreset({
              sessionType,
              recentMarks: avgMarksPct,
              questionCount: 12,
              includeHints: avgMarksPct < 0.55,
            }),
          });
        }
      }

      if (totalAttempts > 0 && avgMarksPct < 0.65) {
        needsWork.push({
          targetId: target._id,
          subject: target.subject ?? "Subject",
          topic: "Mixed paper questions",
          avgMarksPct,
          attempts: totalAttempts,
          daysSinceLast,
          dueScore: Math.max(0, Math.min(1, 1 - avgMarksPct)),
        });
      }

      for (const weak of weakTopics) {
        const topic = String(weak.topic ?? "").trim();
        if (!topic) continue;
        const topicMarks =
          typeof weak.avgMarksPct === "number" ? weak.avgMarksPct : avgMarksPct;
        const topicAttempts =
          typeof weak.attempts === "number" ? weak.attempts : 0;
        const weaknessScore = Math.max(0, Math.min(1, 1 - topicMarks));
        const recencyScore = Math.max(0, Math.min(1, daysSinceLast / 10));
        const targetGapScore = Math.max(0, Math.min(1, gradeGapToTarget / 3));
        const dueScore =
          weaknessScore * 0.56 +
          recencyScore * 0.18 +
          examUrgencyScore * 0.16 +
          targetGapScore * 0.1 +
          (topicAttempts <= 1 ? 0.04 : 0) +
          dominantReasonSeverity * 0.06;

        const reasonCodes = [
          ...(weaknessScore >= 0.35 ? ["weak_topic"] : []),
          ...(recencyScore >= 0.45 ? ["recency_gap"] : []),
          ...(examUrgencyScore >= 0.4 ? ["exam_soon"] : []),
          ...(targetGapScore > 0 ? ["target_gap"] : []),
          ...(topicAttempts <= 1 ? ["build_evidence"] : []),
          ...(topReasonCodes.length > 0 ? [topReasonCodes[0]] : []),
        ];
        if (reasonCodes.length === 0) reasonCodes.push("maintain_momentum");
        const estimatedMinutes =
          topicAttempts <= 2 ? 24 : weaknessScore >= 0.5 ? 28 : 22;
        const reasonLabels = examReasonLabelsFromCodes(reasonCodes);
        const topicLastAttempt = topicLastAttemptAt.get(topic) ?? 0;
        const completedToday =
          topicLastAttempt > 0 &&
          Math.floor((now - topicLastAttempt) / DAY_MS) <= 0;
        const sessionType = "weak_focus";

        const item = {
          targetId: target._id,
          subject: target.subject ?? "Subject",
          topic,
          avgMarksPct: topicMarks,
          attempts: topicAttempts,
          daysSinceLast,
          dueScore,
          estimatedMinutes,
          effortLabel: effortLabelFromMinutes(estimatedMinutes),
          sessionType,
          actionLabel: actionLabelForSession(sessionType, topic),
          reasonCodes,
          reasonLabels,
          whyNow: whyNowForSession(reasonLabels),
          expectedGain: expectedGainForSession(sessionType, topic, reasonCodes),
          learningMethods: learningMethodsForSession(sessionType, reasonCodes),
          completedToday,
          reasonSeverity: dominantReasonSeverity,
          confidence: Math.max(0.6, Math.min(0.92, 0.6 + Math.min(topicAttempts, 4) * 0.08)),
          quizPreset: buildExamSessionPreset({
            sessionType: "weak_focus",
            recentMarks: topicMarks,
            questionCount: topicMarks < 0.45 ? 14 : 12,
            includeHints: topicMarks < 0.6,
          }),
        };
        reviseToday.push(item);
        needsWork.push(item);
      }
    }

    const dedupeByTargetTopic = (items: Array<Record<string, any>>) => {
      const seen = new Set<string>();
      const out: Array<Record<string, any>> = [];
      for (const item of items) {
        const targetId = String(item.targetId ?? "");
        const topic = String(item.topic ?? "").trim().toLowerCase();
        const key = `${targetId}::${topic}`;
        if (!topic || seen.has(key)) continue;
        seen.add(key);
        out.push(item);
      }
      return out;
    };

    const dedupedReviseToday = dedupeByTargetTopic(reviseToday).sort((a, b) => {
      const scoreCmp = Number(b.dueScore ?? 0) - Number(a.dueScore ?? 0);
      if (scoreCmp !== 0) return scoreCmp;
      return Number(a.avgMarksPct ?? 1) - Number(b.avgMarksPct ?? 1);
    });

    const dedupedNeedsWork = dedupeByTargetTopic(needsWork).sort((a, b) => {
      const marksCmp = Number(a.avgMarksPct ?? 1) - Number(b.avgMarksPct ?? 1);
      if (marksCmp !== 0) return marksCmp;
      return Number(b.attempts ?? 0) - Number(a.attempts ?? 0);
    });

    const configuredDailyMinutes =
      weeklyStudyMinutes > 0 ? Math.round(weeklyStudyMinutes / 7) : 45;
    const activeDays14d = recentDailySeconds.size;
    const totalRecentSeconds = Array.from(recentDailySeconds.values()).reduce(
      (sum, value) => sum + value,
      0
    );
    const actualDailyMinutes14d =
      totalRecentSeconds > 0 ? totalRecentSeconds / trailingDays / 60 : 0;
    const actualActiveDayMinutes14d =
      activeDays14d > 0 ? totalRecentSeconds / activeDays14d / 60 : 0;
    const configuredDailySessions =
      weeklySessionsTarget > 0 ? weeklySessionsTarget / 7 : 1;
    const actualDailySessions14d = recentAttemptCount / trailingDays;

    let adaptiveDailyMinutes = configuredDailyMinutes;
    if (activeDays14d >= 3 && actualDailyMinutes14d >= 8) {
      adaptiveDailyMinutes = Math.round(
        configuredDailyMinutes * 0.35 + actualDailyMinutes14d * 0.65
      );
    }
    adaptiveDailyMinutes = Math.max(15, Math.min(180, adaptiveDailyMinutes));

    let adaptiveDailySessions = Math.round(configuredDailySessions);
    if (recentAttemptCount >= 4) {
      adaptiveDailySessions = Math.round(
        configuredDailySessions * 0.4 + actualDailySessions14d * 0.6
      );
    }
    adaptiveDailySessions = Math.max(1, Math.min(4, adaptiveDailySessions));

    const dailyStudyMinutes = adaptiveDailyMinutes;
    const dailySessionBudget = adaptiveDailySessions;
    const missionSessions: Array<Record<string, any>> = [];
    let plannedMinutes = 0;

    for (const item of dedupedReviseToday) {
      const estimatedMinutes = Math.max(
        10,
        Math.floor(Number(item.estimatedMinutes ?? 0))
      );
      const nextSessionCount = missionSessions.length + 1;
      const nextMinutes = plannedMinutes + estimatedMinutes;
      const withinSessionBudget = nextSessionCount <= dailySessionBudget;
      const withinTimeBudget = nextMinutes <= Math.max(dailyStudyMinutes, 25);
      if (withinSessionBudget && withinTimeBudget) {
        missionSessions.push(item);
        plannedMinutes = nextMinutes;
        continue;
      }
      if (missionSessions.length === 0) {
        missionSessions.push(item);
        plannedMinutes = estimatedMinutes;
      }
      if (missionSessions.length >= dailySessionBudget) {
        break;
      }
    }

    const missionHeadline =
      missionSessions.length === 0
        ? "Complete one session to unlock a personalized mission."
        : missionSessions.length === 1
        ? "One high-impact session is ready."
        : "Start the primary mission, then run the backup if you still have energy.";
    const primaryCompletedToday =
      missionSessions.length > 0 && missionSessions[0].completedToday === true;

    return {
      targets: gcseTargets,
      reviseToday: dedupedReviseToday.slice(0, 8),
      needsWork: dedupedNeedsWork.slice(0, 8),
      subjectProgress,
      todayMission: {
        headline: missionHeadline,
        primaryCompletedToday,
        dailyMinutesBudget: dailyStudyMinutes,
        configuredDailyMinutes,
        actualDailyMinutes14d,
        actualActiveDayMinutes14d,
        budgetMode: activeDays14d >= 3 ? "adaptive" : "configured",
        plannedMinutes,
        plannedSessions: missionSessions.length,
        sessions: missionSessions,
      },
      revisionIntelligence: {
        subjectCount: gcseTargets.length,
        mocksInDays: nearestMockInDays,
        gcsesInDays: nearestGcseInDays,
        atRiskCount,
        closeCount,
        onTrackCount,
        missingDateCount,
        timetableMode,
        dailyStudyMinutes,
        configuredDailyMinutes,
        adaptiveDailyMinutes,
        actualDailyMinutes14d,
        actualActiveDayMinutes14d,
        activeDays14d,
        actualDailySessions14d,
        weeklyStudyMinutes,
        weeklySessionsTarget,
      },
    };
  },
});
