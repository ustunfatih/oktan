import { useEffect, useState } from "react";
import { api, type WriteError } from "../data";
import { needsHomeScreen, pushSupported, currentSubscription, subscribeThisPhone, unsubscribeThisPhone } from "../push";

interface PushState {
  publicKey: string | null;
  configured: boolean;
  subscriptions: number;
  afterDays: number;
}

/** Fill-up reminders on this phone. The Worker keeps the subscriptions and sends the notifications daily. */
export function RemindersSection() {
  const supported = pushSupported();
  const [server, setServer] = useState<PushState | null>(null);
  const [here, setHere] = useState<boolean | null>(null);
  const [days, setDays] = useState("10");
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<{ text: string; tone: "good" | "bad" } | null>(null);

  const reload = async () => {
    const s = await api<PushState>("/api/push");
    setServer(s);
    setDays(String(s.afterDays));
    setHere(supported ? !!(await currentSubscription()) : false);
  };

  useEffect(() => {
    reload().catch((e: WriteError) => setNotice({ text: e.message, tone: "bad" }));
  }, []);

  const turnOn = async () => {
    if (!server?.publicKey) return;
    setBusy(true);
    setNotice(null);
    try {
      const sub = await subscribeThisPhone(server.publicKey);
      await api("/api/push/subscribe", { method: "POST", body: { subscription: sub.toJSON() } });
      setNotice({ text: "Reminders are on for this phone.", tone: "good" });
      await reload();
    } catch (e) {
      setNotice({ text: e instanceof Error ? e.message : (e as WriteError).message, tone: "bad" });
    } finally {
      setBusy(false);
    }
  };

  const turnOff = async () => {
    setBusy(true);
    setNotice(null);
    try {
      const endpoint = await unsubscribeThisPhone();
      if (endpoint) await api("/api/push/subscribe", { method: "DELETE", body: { endpoint } });
      setNotice({ text: "Reminders are off for this phone.", tone: "good" });
      await reload();
    } catch (e) {
      setNotice({ text: (e as WriteError).message, tone: "bad" });
    } finally {
      setBusy(false);
    }
  };

  const saveDays = async () => {
    setBusy(true);
    setNotice(null);
    try {
      await api("/api/push/prefs", { method: "PUT", body: { afterDays: Number(days) } });
      setNotice({ text: `We'll remind you after ${days} days without a fill-up.`, tone: "good" });
      await reload();
    } catch (e) {
      setNotice({ text: (e as WriteError).message, tone: "bad" });
    } finally {
      setBusy(false);
    }
  };

  const test = async () => {
    setBusy(true);
    try {
      const r = await api<{ sent: number; failed: number }>("/api/push/test", { method: "POST", body: {} });
      setNotice(
        r.sent > 0
          ? { text: "Test sent. You should see it in a moment.", tone: "good" }
          : { text: "The test didn't reach your phone. Turn reminders off and on again, then retry.", tone: "bad" },
      );
    } catch (e) {
      setNotice({ text: (e as WriteError).message, tone: "bad" });
    } finally {
      setBusy(false);
    }
  };

  const daysValid = /^\d+$/.test(days) && Number(days) >= 1 && Number(days) <= 60;

  return (
    <section className="panel reminders">
      <div className="panel-head">
        <h2>Fill-up reminders</h2>
        <span className="label">On this phone</span>
      </div>

      {!supported ? (
        <p className="muted">This browser can't show notifications. Open Oktan in Safari or Chrome on your phone.</p>
      ) : needsHomeScreen() ? (
        <p className="banner banner--test" role="status">
          On iPhone, reminders work only once Oktan is on your Home Screen. Tap Share → Add to Home Screen, open Oktan from there, then come back here.
        </p>
      ) : server && !server.configured ? (
        <p className="muted">Reminders aren't set up on the Worker yet. The owner needs to add the VAPID key (see the README).</p>
      ) : (
        <>
          <p className="muted small">
            When it's been a while since your last fill-up, your phone gets a notification. Checked once a day at 08:00 Qatar time.
          </p>
          <div className="form-actions form-actions--start">
            {here ? (
              <button type="button" className="btn btn--ghost" disabled={busy} onClick={turnOff}>
                Turn reminders off on this phone
              </button>
            ) : (
              <button type="button" className="btn" disabled={busy || !server?.publicKey} onClick={turnOn}>
                Turn reminders on for this phone
              </button>
            )}
            {here && (
              <button type="button" className="btn btn--ghost" disabled={busy} onClick={test}>
                Send a test
              </button>
            )}
          </div>
          <div className="form-grid">
            <label className="field">
              <span className="field__label">Remind me after · days without a fill-up</span>
              <input type="text" inputMode="numeric" value={days} onChange={(e) => setDays(e.target.value)} aria-invalid={!daysValid} aria-describedby="days-err" />
              {!daysValid && (
                <span className="field__err" id="days-err">
                  Enter a whole number from 1 to 60.
                </span>
              )}
            </label>
          </div>
          <div className="form-actions form-actions--start">
            <button type="button" className="btn btn--small" disabled={busy || !daysValid || server?.afterDays === Number(days)} onClick={saveDays}>
              Save days
            </button>
          </div>
        </>
      )}

      {notice && (
        <p className={notice.tone === "bad" ? "form-error" : "muted"} role={notice.tone === "bad" ? "alert" : "status"}>
          {notice.text}
        </p>
      )}
    </section>
  );
}
