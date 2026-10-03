import Mux from '@mux/mux-node';

/** Signs playback for Mux assets migrated to a signed playback policy. */
export function createMuxPlaybackToken(playbackId: string) {
  const keyId = process.env.MUX_SIGNING_KEY_ID;
  const encodedPrivateKey = process.env.MUX_PRIVATE_KEY;
  if (!keyId || !encodedPrivateKey) throw new Error('Mux signed playback is not configured');
  const privateKey = Buffer.from(encodedPrivateKey, 'base64');
  return Mux.JWT.signPlaybackId(playbackId, {
    keyId,
    keySecret: privateKey.toString('utf8'),
    expiration: '4h',
  });
}
