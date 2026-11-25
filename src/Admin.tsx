import { FormEvent, useEffect, useState } from 'react';
import type { SupabaseClient } from '@supabase/supabase-js';

type Menu = { id: string; menu_date: string; breakfast: string; lunch: string; snacks: string; dinner: string };
type Notice = { id: string; title: string; body: string; category: string; priority: string; published_at: string; expires_at: string | null };

export function AdminMenus({ db }: { db: SupabaseClient }) {
  const [items, setItems] = useState<Menu[]>([]);
  const [editing, setEditing] = useState<Menu | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  async function load() {
    const result = await db.from('food_menus').select('*').order('menu_date', { ascending: false });
    if (result.error) setError(result.error.message); else setItems(result.data || []);
    setLoading(false);
  }
  useEffect(() => { void load(); }, [db]);
  async function save(e: FormEvent<HTMLFormElement>) {
    e.preventDefault(); setError(''); setBusy(true);
    const form = e.currentTarget; const f = new FormData(form);
    const row = { menu_date: String(f.get('menu_date')), breakfast: String(f.get('breakfast')).trim(), lunch: String(f.get('lunch')).trim(), snacks: String(f.get('snacks')).trim(), dinner: String(f.get('dinner')).trim() };
    const result = editing ? await db.from('food_menus').update(row).eq('id', editing.id).select('id').single() : await db.from('food_menus').insert(row).select('id').single();
    if (result.error) setError(result.error.message); else { setEditing(null); form.reset(); await load(); }
    setBusy(false);
  }
  async function remove(id: string) {
    if (!window.confirm('Delete this menu?')) return;
    setError(''); const result = await db.from('food_menus').delete().eq('id', id).select('id').single();
    if (result.error) setError(result.error.message); else { if (editing?.id === id) setEditing(null); await load(); }
  }
  return <section className="panel"><h2>Manage menus</h2><p>Publish a menu for a date or edit an existing one.</p>
    <form key={editing?.id || 'new'} onSubmit={save} className="form">
      <label>Date<input name="menu_date" type="date" required defaultValue={editing?.menu_date}/></label>
      {(['breakfast', 'lunch', 'snacks', 'dinner'] as const).map(meal => <label key={meal}>{meal}<input name={meal} maxLength={500} required defaultValue={editing?.[meal]}/></label>)}
      <div><button disabled={busy}>{busy ? 'Saving…' : editing ? 'Save changes' : 'Add menu'}</button>{editing && <button type="button" className="secondary" onClick={() => setEditing(null)}>Cancel edit</button>}</div>
    </form>{error && <p className="error" role="alert">{error}</p>}
    {loading ? <p>Loading menus…</p> : items.length === 0 ? <p>No menus have been published.</p> : items.map(item => <div className="menuitem" key={item.id}><b>{item.menu_date}</b><p>{item.breakfast} · {item.lunch} · {item.snacks} · {item.dinner}</p><button type="button" className="secondary" onClick={() => setEditing(item)}>Edit</button> <button type="button" className="secondary" onClick={() => void remove(item.id)}>Delete</button></div>)}
  </section>;
}

function localDateTime(value: string | null) {
  if (!value) return '';
  const date = new Date(value);
  return new Date(date.getTime() - date.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
}
export function AdminNotices({ db }: { db: SupabaseClient }) {
  const [items, setItems] = useState<Notice[]>([]);
  const [editing, setEditing] = useState<Notice | null>(null);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  async function load() {
    const result = await db.from('notices').select('*').order('published_at', { ascending: false });
    if (result.error) setError(result.error.message); else setItems(result.data || []);
    setLoading(false);
  }
  useEffect(() => { void load(); }, [db]);
  async function save(e: FormEvent<HTMLFormElement>) {
    e.preventDefault(); setError(''); setBusy(true);
    const form = e.currentTarget; const f = new FormData(form);
    const expiry = String(f.get('expires_at') || '');
    const row = { title: String(f.get('title')).trim(), body: String(f.get('body')).trim(), category: String(f.get('category')), priority: String(f.get('priority')), published_at: new Date(String(f.get('published_at'))).toISOString(), expires_at: expiry ? new Date(expiry).toISOString() : null };
    if (row.expires_at && row.expires_at <= row.published_at) { setError('Expiry must be after the publish time.'); setBusy(false); return; }
    const result = editing ? await db.from('notices').update(row).eq('id', editing.id).select('id').single() : await db.from('notices').insert(row).select('id').single();
    if (result.error) setError(result.error.message); else { setEditing(null); form.reset(); await load(); }
    setBusy(false);
  }
  async function remove(id: string) {
    if (!window.confirm('Delete this notice?')) return;
    setError(''); const result = await db.from('notices').delete().eq('id', id).select('id').single();
    if (result.error) setError(result.error.message); else { if (editing?.id === id) setEditing(null); await load(); }
  }
  return <section className="panel"><h2>Manage notices</h2><p>Create, schedule, and update announcements.</p>
    <form key={editing?.id || 'new'} onSubmit={save} className="form">
      <label>Title<input name="title" required maxLength={150} defaultValue={editing?.title}/></label>
      <label>Category<select name="category" defaultValue={editing?.category || 'general'}>{['general', 'maintenance', 'food', 'events', 'rules', 'safety'].map(c => <option key={c}>{c}</option>)}</select></label>
      <label>Priority<select name="priority" defaultValue={editing?.priority || 'normal'}><option>normal</option><option>important</option><option>urgent</option></select></label>
      <label>Publish at<input type="datetime-local" name="published_at" required defaultValue={localDateTime(editing?.published_at || new Date().toISOString())}/></label>
      <label>Expires at (optional)<input type="datetime-local" name="expires_at" defaultValue={localDateTime(editing?.expires_at || null)}/></label>
      <label className="wide">Message<textarea name="body" required maxLength={5000} defaultValue={editing?.body}/></label>
      <div><button disabled={busy}>{busy ? 'Saving…' : editing ? 'Save changes' : 'Publish notice'}</button>{editing && <button type="button" className="secondary" onClick={() => setEditing(null)}>Cancel edit</button>}</div>
    </form>{error && <p className="error" role="alert">{error}</p>}
    {loading ? <p>Loading notices…</p> : items.length === 0 ? <p>No notices have been created.</p> : items.map(item => <div className="notice" key={item.id}><b>{item.title}</b><p>{item.category} · {item.priority} · {new Date(item.published_at).toLocaleString()}</p><button type="button" className="secondary" onClick={() => setEditing(item)}>Edit</button> <button type="button" className="secondary" onClick={() => void remove(item.id)}>Delete</button></div>)}
  </section>;
}
