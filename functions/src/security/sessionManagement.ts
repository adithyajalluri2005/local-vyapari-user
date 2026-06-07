import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

/**
 * Computes a stable SHA-256 device ID based on the client's User-Agent string.
 */
function getDeviceId(userAgent: string): string {
  return crypto.createHash("sha256").update(userAgent || "unknown").digest("hex");
}

/**
 * Validates a user's session role, registers/updates their device session in RTDB,
 * and synchronizes Firebase Auth custom claims based on roles defined in the database.
 */
export const validateSession = onCall(
  { region: "asia-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to validate session.");
    }

    const uid = request.auth.uid;
    const targetRole = request.data?.targetRole || "customer";
    const userAgent = request.rawRequest.headers["user-agent"] || "Unknown Platform";
    const deviceId = getDeviceId(userAgent);

    const db = admin.database();

    // 1. Check if the device session is blacklisted/revoked
    const deviceRef = db.ref(`/users_devices/${uid}/devices/${deviceId}`);
    const deviceSnap = await deviceRef.get();
    if (deviceSnap.exists()) {
      const dev = deviceSnap.val();
      if (dev && dev.revoked === true) {
        return { success: false, error: "Session revoked." };
      }
    }

    // 2. Fetch user roles from RTDB
    const rolesRef = db.ref(`/users/${uid}/roles`);
    const rolesSnap = await rolesRef.get();
    let roles = rolesSnap.val() as Record<string, boolean> | null;

    if (!roles) {
      // Initialize default customer role if none exist
      roles = { customer: true };
      await rolesRef.set(roles);
    }

    // Check targetRole authorization
    if (roles[targetRole] !== true) {
      return { success: false, error: "Unauthorized role access." };
    }

    // 3. Register or update the device record
    const now = Date.now();
    await deviceRef.update({
      id: deviceId,
      userAgent: userAgent,
      lastSeen: now,
      firstSeen: deviceSnap.exists() ? (deviceSnap.val().firstSeen || now) : now,
      revoked: false,
    });

    // 4. Update Firebase Auth Custom Claims
    await admin.auth().setCustomUserClaims(uid, { roles });

    return { success: true };
  }
);

/**
 * Lists all active (non-revoked) device sessions for the authenticated user.
 */
export const listMyDevices = onCall(
  { region: "asia-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to list devices.");
    }

    const uid = request.auth.uid;
    const devicesRef = admin.database().ref(`/users_devices/${uid}/devices`);
    const snap = await devicesRef.get();

    const devices: Array<{ id: string; userAgent: string; firstSeen: number | null; lastSeen: number | null }> = [];

    if (snap.exists()) {
      const val = snap.val() as Record<string, Record<string, unknown>>;
      for (const key of Object.keys(val)) {
        const dev = val[key];
        if (dev && dev.revoked !== true) {
          devices.push({
            id: String(dev.id || key),
            userAgent: String(dev.userAgent || "Unknown Device"),
            firstSeen: typeof dev.firstSeen === "number" ? dev.firstSeen : null,
            lastSeen: typeof dev.lastSeen === "number" ? dev.lastSeen : null,
          });
        }
      }
    }

    return { devices };
  }
);

/**
 * Revokes a specific device session by marking its revoked state in RTDB.
 */
export const revokeDevice = onCall(
  { region: "asia-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to revoke a device.");
    }

    const deviceId = request.data?.deviceId;
    if (!deviceId || typeof deviceId !== "string") {
      throw new HttpsError("invalid-argument", "deviceId is required and must be a string.");
    }

    const uid = request.auth.uid;
    const deviceRef = admin.database().ref(`/users_devices/${uid}/devices/${deviceId}`);
    
    // Set revoked status to true in RTDB
    await deviceRef.update({ revoked: true });
    
    return { success: true };
  }
);

/**
 * Signs out all other sessions by revoking refresh tokens in Auth and marking
 * all device IDs except the current request's ID as revoked in RTDB.
 */
export const signOutEverywhere = onCall(
  { region: "asia-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const uid = request.auth.uid;
    const userAgent = request.rawRequest.headers["user-agent"] || "Unknown Platform";
    const currentDeviceId = getDeviceId(userAgent);

    const db = admin.database();
    const devicesRef = db.ref(`/users_devices/${uid}/devices`);
    const snap = await devicesRef.get();

    if (snap.exists()) {
      const val = snap.val() as Record<string, Record<string, unknown>>;
      const updates: Record<string, unknown> = {};
      
      for (const key of Object.keys(val)) {
        if (key !== currentDeviceId) {
          updates[`${key}/revoked`] = true;
        }
      }
      
      if (Object.keys(updates).length > 0) {
        await devicesRef.update(updates);
      }
    }

    // Revoke refresh tokens in Firebase Auth (invalidates active sessions upon next ID token refresh)
    await admin.auth().revokeRefreshTokens(uid);

    return { success: true };
  }
);

/**
 * Asserts whether the user's last authentication time is within a specified age threshold.
 * Uses the cryptographically verified `auth_time` claim in the ID token.
 */
export const assertRecentAuth = onCall(
  { region: "asia-south1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in to verify recent auth.");
    }

    const authTime = request.auth.token.auth_time;
    if (!authTime) {
      return { ok: false };
    }

    const maxAgeSeconds = Number(request.data?.maxAgeSeconds || 300);
    const currentTimeSeconds = Math.floor(Date.now() / 1000);
    const ageSeconds = currentTimeSeconds - authTime;

    return { ok: ageSeconds <= maxAgeSeconds };
  }
);

/**
 * Public resolver endpoint to get the login email associated with a phone number.
 */
export const resolvePhoneLoginEmail = onCall(
  { region: "asia-south1" },
  async (request) => {
    const phone = request.data?.phone;
    if (!phone || typeof phone !== "string") {
      throw new HttpsError("invalid-argument", "phone is required and must be a string.");
    }

    const db = admin.database();
    
    // Look up the uid mapped to this phone
    const phoneSnap = await db.ref(`phones/${phone.trim()}`).get();
    if (!phoneSnap.exists()) {
      throw new HttpsError("not-found", "Phone number is not registered.");
    }

    const uid = phoneSnap.val();
    
    // Retrieve the user email
    const emailSnap = await db.ref(`users/${uid}/email`).get();
    if (!emailSnap.exists()) {
      throw new HttpsError("not-found", "No email linked to this phone number.");
    }

    return { email: String(emailSnap.val()) };
  }
);
