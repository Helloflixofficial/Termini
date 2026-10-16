import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getMessaging } from "firebase-admin/messaging";

let cachedMessaging: ReturnType<typeof getMessaging> | undefined;

function getFirebaseMessaging() {
  if (cachedMessaging) return cachedMessaging;

  const encodedCredentials = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;
  if (!encodedCredentials) return null;

  const credentials = JSON.parse(
    Buffer.from(encodedCredentials, "base64").toString("utf8"),
  );
  if (
    !credentials.project_id ||
    !credentials.client_email ||
    !credentials.private_key
  ) {
    throw new Error("Firebase service-account configuration is incomplete");
  }

  const appName = `termini-${credentials.project_id}`;
  const app =
    getApps().find((candidate) => candidate.name === appName) ??
    initializeApp({ credential: cert(credentials) }, appName);
  cachedMessaging = getMessaging(app);
  return cachedMessaging;
}

export async function sendCommunityPostPush(post: { id: string }) {
  const messaging = getFirebaseMessaging();
  if (!messaging) return false;

  await messaging.send({
    topic: "community_students",
    notification: {
      title: "New post from Termini",
      body: "A teacher shared a new post in Community. Open Termini to read it.",
    },
    data: {
      type: "community_post",
      postId: post.id,
      route: "/notifications",
    },
    android: {
      priority: "high",
      notification: { channelId: "community_posts" },
    },
  });
  return true;
}
