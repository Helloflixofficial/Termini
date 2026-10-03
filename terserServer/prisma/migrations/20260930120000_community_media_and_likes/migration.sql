-- Align the community schema with the fields used by the mobile/server API.
-- IF NOT EXISTS keeps this migration safe for databases where these columns
-- were added manually before the migration was checked in.
ALTER TABLE "CommunityPost"
    ADD COLUMN IF NOT EXISTS "mediaUrl" TEXT,
    ADD COLUMN IF NOT EXISTS "mediaType" TEXT,
    ADD COLUMN IF NOT EXISTS "linkUrl" TEXT,
    ADD COLUMN IF NOT EXISTS "linkTitle" TEXT,
    ADD COLUMN IF NOT EXISTS "authorName" TEXT,
    ADD COLUMN IF NOT EXISTS "authorImageUrl" TEXT;

ALTER TABLE "CommunityComment"
    ADD COLUMN IF NOT EXISTS "authorName" TEXT,
    ADD COLUMN IF NOT EXISTS "authorImageUrl" TEXT;

CREATE TABLE IF NOT EXISTS "CommunityLike" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "ownerId" TEXT NOT NULL,
    "postId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "CommunityLike_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "CommunityLike_userId_postId_key"
    ON "CommunityLike"("userId", "postId");
CREATE INDEX IF NOT EXISTS "CommunityLike_ownerId_postId_idx"
    ON "CommunityLike"("ownerId", "postId");
CREATE INDEX IF NOT EXISTS "CommunityLike_postId_createdAt_idx"
    ON "CommunityLike"("postId", "createdAt");

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'CommunityLike_postId_fkey'
    ) THEN
        ALTER TABLE "CommunityLike"
            ADD CONSTRAINT "CommunityLike_postId_fkey"
            FOREIGN KEY ("postId") REFERENCES "CommunityPost"("id")
            ON DELETE CASCADE ON UPDATE CASCADE;
    END IF;
END $$;
