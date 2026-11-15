import { AccessToken, RoomServiceClient, TrackSource } from 'livekit-server-sdk';

export const liveKitRoomName = (callId) => `metagym-call-${callId}`;

export function createLiveKitFromEnv(env = process.env) {
  const { LIVEKIT_URL: url, LIVEKIT_API_KEY: key, LIVEKIT_API_SECRET: secret } = env;
  if (!url && !key && !secret) return undefined;
  if (!url || !key || !secret || new URL(url).protocol !== 'wss:') {
    throw new Error('Configure LIVEKIT_URL (wss://), LIVEKIT_API_KEY and LIVEKIT_API_SECRET.');
  }
  const rooms = new RoomServiceClient(url.replace(/^wss:/, 'https:'), key, secret, {
    requestTimeout: 4,
  });
  return {
    url,
    async issueToken({ callId, userId, callType }) {
      const room = liveKitRoomName(callId);
      const token = new AccessToken(key, secret, { identity: userId, ttl: '5m' });
      token.addGrant({
        roomJoin: true, room, canPublish: true, canSubscribe: true, canPublishData: false,
        canPublishSources: callType === 'VIDEO'
          ? [TrackSource.MICROPHONE, TrackSource.CAMERA] : [TrackSource.MICROPHONE],
      });
      const accessToken = await token.toJwt();
      const { exp } = JSON.parse(Buffer.from(accessToken.split('.')[1], 'base64url'));
      return { accessToken, providerCallId: room, channelId: room,
        expiresAt: new Date(exp * 1000).toISOString() };
    },
    async closeRoom(room, participants) {
      // Revoke join tokens even if the participant has already left.
      const results = await Promise.allSettled(
        participants.map((id) => rooms.removeParticipant(room, id)),
      );
      await rooms.deleteRoom(room).catch((error) => {
        if (error.status !== 404) throw error;
      });
      if (results.some((result) => result.status === 'rejected' && result.reason.status !== 404)) {
        throw new Error('Could not revoke a LiveKit participant token');
      }
    },
  };
}
