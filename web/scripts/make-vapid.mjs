// Makes the key pair that signs fill-up reminders (web push). Run it once, or again when rotating.
//
//   node scripts/make-vapid.mjs /path/to/private-key.jwk.json
//
// The private key goes to a file you then load as a Worker secret (never commit it). The public key is
// printed: put it in wrangler.jsonc as VAPID_PUBLIC_KEY, then deploy. Nothing is sent anywhere.
import { writeFileSync } from "node:fs";

const out = process.argv[2];
if (!out) {
  console.error("Usage: node scripts/make-vapid.mjs /path/to/private-key.jwk.json");
  process.exit(1);
}

const { privateKey, publicKey } = await crypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
const jwk = await crypto.subtle.exportKey("jwk", privateKey);
const raw = new Uint8Array(await crypto.subtle.exportKey("raw", publicKey));

writeFileSync(out, JSON.stringify({ kty: "EC", crv: "P-256", d: jwk.d, x: jwk.x, y: jwk.y }), { mode: 0o600 });
console.log(`Private key written to ${out}. Keep it secret.`);
console.log(`Public key (VAPID_PUBLIC_KEY in wrangler.jsonc):\n${Buffer.from(raw).toString("base64url")}`);
console.log("Next: npx wrangler secret put VAPID_PRIVATE_JWK < <that file>, then delete the file.");
