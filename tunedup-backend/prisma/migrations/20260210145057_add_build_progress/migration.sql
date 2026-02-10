-- CreateTable
CREATE TABLE "build_progress" (
    "id" TEXT NOT NULL,
    "buildId" TEXT NOT NULL,
    "modId" TEXT NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "purchasedAt" TIMESTAMP(3),
    "installedAt" TIMESTAMP(3),
    "notes" TEXT,

    CONSTRAINT "build_progress_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "build_progress_buildId_idx" ON "build_progress"("buildId");

-- CreateIndex
CREATE UNIQUE INDEX "build_progress_buildId_modId_key" ON "build_progress"("buildId", "modId");

-- AddForeignKey
ALTER TABLE "build_progress" ADD CONSTRAINT "build_progress_buildId_fkey" FOREIGN KEY ("buildId") REFERENCES "builds"("id") ON DELETE CASCADE ON UPDATE CASCADE;
