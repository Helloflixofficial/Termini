const Mux = require('@mux/mux-node');
const { PrismaClient } = require('@prisma/client');

const required = ['DATABASE_URL', 'MUX_TOKEN_ID', 'MUX_TOKEN_SECRET'];
const missing = required.filter((name) => !process.env[name]);
if (missing.length) {
  console.error(`Missing required environment variables: ${missing.join(', ')}`);
  process.exit(1);
}

const prisma = new PrismaClient();
const mux = new Mux(process.env.MUX_TOKEN_ID, process.env.MUX_TOKEN_SECRET);

async function main() {
  const rows = await prisma.muxData.findMany({ select: { id: true, assetId: true, chapterId: true } });
  let changed = 0;
  for (const row of rows) {
    const asset = await mux.Video.Assets.get(row.assetId);
    let signed = asset.playback_ids?.find((playback) => playback.policy === 'signed');
    if (!signed) signed = await mux.Video.Assets.createPlaybackId(row.assetId, { policy: 'signed' });

    // Store the signed ID first so a retry can resume safely.
    await prisma.muxData.update({ where: { id: row.id }, data: { playbackId: signed.id } });
    const oldPublicIds = (asset.playback_ids ?? [])
      .filter((playback) => playback.policy === 'public' && playback.id !== signed.id);
    for (const playback of oldPublicIds) {
      await mux.Video.Assets.deletePlaybackId(row.assetId, playback.id);
    }
    changed += 1;
    console.log(`Secured Mux playback for chapter ${row.chapterId}`);
  }
  console.log(`Secured ${changed} Mux chapter assets and revoked their public playback IDs.`);
}

main()
  .catch((error) => {
    console.error('Mux playback migration failed:', error?.status || error?.name || 'unknown error');
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
