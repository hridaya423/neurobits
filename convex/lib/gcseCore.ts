export const GCSE_CORE_BOARD_BY_SUBJECT: Record<string, string> = {
  Mathematics: "Pearson Edexcel",
  "English Language": "AQA",
  "English Literature": "AQA",
  Biology: "AQA",
  Chemistry: "AQA",
  Physics: "AQA",
};

export const GCSE_CORE_SUBJECTS = Object.keys(GCSE_CORE_BOARD_BY_SUBJECT);

export function gcsePreferredBoardForSubject(
  subject: string | undefined | null
): string | undefined {
  if (!subject) return undefined;
  const normalized = subject.trim().toLowerCase();
  for (const [name, board] of Object.entries(GCSE_CORE_BOARD_BY_SUBJECT)) {
    if (name.toLowerCase() == normalized) {
      return board;
    }
  }
  return undefined;
}

export function isGcseCoreSubject(subject: string | undefined | null): boolean {
  return gcsePreferredBoardForSubject(subject) !== undefined;
}
