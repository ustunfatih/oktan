import { importPKCS8, SignJWT } from "jose";

const TOKEN_URL = "https://oauth2.googleapis.com/token";
const SCOPE = "https://www.googleapis.com/auth/spreadsheets";

interface ServiceAccountKey {
  client_email: string;
  private_key: string;
}

export class GoogleAuthError extends Error {}

let cached: { token: string; expiresAt: number; keyEmail: string } | null = null;

function parseKey(raw: string | undefined): ServiceAccountKey {
  if (!raw) throw new GoogleAuthError("GOOGLE_SA_KEY secret is not set");
  let key: Partial<ServiceAccountKey>;
  try {
    key = JSON.parse(raw);
  } catch {
    throw new GoogleAuthError("GOOGLE_SA_KEY is not valid JSON");
  }
  if (!key.client_email || !key.private_key) {
    throw new GoogleAuthError("GOOGLE_SA_KEY is missing client_email or private_key");
  }
  return key as ServiceAccountKey;
}

/** OAuth access token for the service account, cached until a minute before it expires. */
export async function getAccessToken(rawKey: string | undefined): Promise<string> {
  const key = parseKey(rawKey);
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.keyEmail === key.client_email && cached.expiresAt - 60 > now) return cached.token;

  const privateKey = await importPKCS8(key.private_key, "RS256");
  const assertion = await new SignJWT({ scope: SCOPE })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(key.client_email)
    .setAudience(TOKEN_URL)
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(privateKey);

  const res = await fetch(TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  if (!res.ok) throw new GoogleAuthError(`Google token request failed (${res.status}): ${await res.text()}`);
  const body = (await res.json()) as { access_token: string; expires_in: number };
  cached = { token: body.access_token, expiresAt: now + body.expires_in, keyEmail: key.client_email };
  return body.access_token;
}
