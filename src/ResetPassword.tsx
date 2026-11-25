import { FormEvent, useEffect, useState } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';

/** Handles the Supabase recovery redirect without placing passwords in URLs or logs. */
export default function ResetPassword({ client }: { client: SupabaseClient }) {
  const [checking, setChecking] = useState(true);
  const [ready, setReady] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [done, setDone] = useState(false);

  useEffect(() => {
    let mounted = true;
    const params = new URLSearchParams(window.location.hash.slice(1));
    const query = new URLSearchParams(window.location.search);
    const linkError = params.get('error_description') || query.get('error_description');
    if (linkError) {
      setError('This reset link is invalid or has expired. Request a new link from the sign-in page.');
      setChecking(false);
      return () => { mounted = false; };
    }
    const { data: { subscription } } = client.auth.onAuthStateChange((event, session) => {
      if (mounted && (event === 'PASSWORD_RECOVERY' || event === 'INITIAL_SESSION')) {
        setReady(!!session);
        setChecking(false);
      }
    });
    // getSession waits for Supabase's URL/session initialization, including PKCE exchange.
    void client.auth.getSession().then(({ data, error: sessionError }) => {
      if (!mounted) return;
      setReady(!!data.session);
      setChecking(false);
      if (sessionError) setError('Could not verify the reset link. Request a new link and try again.');
    }).catch(() => { if (mounted) { setChecking(false); setError('Could not verify the reset link. Check your connection and try again.'); } });
    return () => { mounted = false; subscription.unsubscribe(); };
  }, [client]);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const values = new FormData(event.currentTarget);
    const password = String(values.get('password') || '');
    if (password !== String(values.get('confirm') || '')) { setError('Passwords do not match.'); return; }
    setBusy(true); setError('');
    try {
      const { error: updateError } = await client.auth.updateUser({ password });
      if (updateError) { setError(updateError.message); return; }
      await client.auth.signOut();
      setDone(true);
    } catch {
      setError('Could not update your password. Check your connection and try again.');
    } finally { setBusy(false); }
  }

  return <main className="auth"><section><div className="logo">U</div><span className="eyebrow">UniFlow Hostel</span><h1>Choose a new password</h1>
    {checking ? <p>Checking your reset link…</p> : done ? <><p>Your password has been updated. Sign in with your new password.</p><a href="/">Back to sign in</a></> : ready ? <><p>Use at least eight characters for your new password.</p><form onSubmit={submit}>
      <label>New password<input name="password" type="password" minLength={8} required autoComplete="new-password" /></label>
      <label>Confirm password<input name="confirm" type="password" minLength={8} required autoComplete="new-password" /></label>
      <button disabled={busy}>{busy ? 'Updating…' : 'Update password'}</button>
    </form></> : <p>Your reset link is missing, invalid, or expired. Request another from the sign-in page.</p>}
    {error && <p className="error" role="alert">{error}</p>}
    {!done && !checking && !ready && <a href="/">Back to sign in</a>}
  </section></main>;
}
