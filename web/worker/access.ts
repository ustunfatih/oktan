import { createRemoteJWKSet, jwtVerify } from "jose";
import type { MiddlewareHandler } from "hono";
import type { Env } from "./env";

type Vars = { email: string };

const jwksByTeam = new Map<string, ReturnType<typeof createRemoteJWKSet>>();

function jwks(teamDomain: string) {
  let set = jwksByTeam.get(teamDomain);
  if (!set) {
    set = createRemoteJWKSet(new URL(`https://${teamDomain}/cdn-cgi/access/certs`));
    jwksByTeam.set(teamDomain, set);
  }
  return set;
}

const isLocalhost = (url: string) => {
  const { hostname } = new URL(url);
  return hostname === "localhost" || hostname === "127.0.0.1";
};

/**
 * Second line of defence behind Cloudflare Access: every API request must carry a valid
 * Access JWT for this application, issued to the one allowed email address.
 */
export const requireAccess: MiddlewareHandler<{ Bindings: Env; Variables: Vars }> = async (c, next) => {
  const allowed = c.env.ALLOWED_EMAIL.toLowerCase();

  if (c.env.DEV_EMAIL && isLocalhost(c.req.url)) {
    c.set("email", c.env.DEV_EMAIL.toLowerCase());
    return next();
  }

  const token = c.req.header("Cf-Access-Jwt-Assertion");
  if (!token) return c.json({ error: "Not signed in" }, 401);

  try {
    const { payload } = await jwtVerify(token, jwks(c.env.ACCESS_TEAM_DOMAIN), {
      issuer: `https://${c.env.ACCESS_TEAM_DOMAIN}`,
      audience: c.env.ACCESS_AUD,
    });
    const email = typeof payload.email === "string" ? payload.email.toLowerCase() : "";
    if (email !== allowed) return c.json({ error: "This account is not allowed" }, 403);
    c.set("email", email);
  } catch {
    return c.json({ error: "Invalid sign-in token" }, 401);
  }
  return next();
};
