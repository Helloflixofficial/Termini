export const isTeacher = (userId?: string | null) => {
  if (!userId) return false;

  // Keep the admin allow-list server-side authoritative. Supporting a
  // comma-separated value makes it possible to have more than one admin
  // without weakening the check for ordinary signed-in users.
  const adminIds = (process.env.TEACHER_IDS || "")
    .split(",")
    .map((id) => id.trim())
    .filter(Boolean);

  return adminIds.includes(userId);
}
