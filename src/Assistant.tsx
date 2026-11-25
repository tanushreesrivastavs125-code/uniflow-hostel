import {FormEvent, useEffect, useState} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';
import {requestAssistant} from './assistant-api.js';

type Message={role:'user'|'assistant';content:string};
export function Assistant({db}:{db:SupabaseClient}) {
  const [messages,setMessages]=useState<Message[]>([]), [text,setText]=useState(''), [busy,setBusy]=useState(false), [loading,setLoading]=useState(true), [error,setError]=useState('');
  useEffect(()=>{let active=true;void db.from('ai_conversations').select('role,content').order('created_at',{ascending:true}).then(({data,error})=>{if(!active)return;if(error)setError('Could not load conversation history. You can still ask a question.');else setMessages((data||[]) as Message[]);setLoading(false)});return()=>{active=false}},[db]);
  async function send(event:FormEvent<HTMLFormElement>){event.preventDefault();const message=text.trim();if(!message||busy)return;setBusy(true);setError('');try{const answer=await requestAssistant(db,message);setMessages(previous=>[...previous,{role:'user',content:message},{role:'assistant',content:answer}]);setText('')}catch(cause){setError(cause instanceof Error?cause.message:'Unable to reach UniFlow AI. Please try again.')}finally{setBusy(false)}}
  return <section className="panel chat"><div className="chatlog" aria-live="polite">{loading?<p className="empty">Loading conversation…</p>:messages.length===0?<p className="empty">Ask a hostel question. UniFlow only treats verified knowledge-base records as official information.</p>:messages.map((m,i)=><p className={m.role} key={i}>{m.content}</p>)}</div>{error&&<p className="error" role="alert">{error}</p>}<form onSubmit={send}><input value={text} onChange={event=>setText(event.target.value)} placeholder="Ask UniFlow AI…" aria-label="Ask UniFlow AI" maxLength={2000} required/><button disabled={busy||loading}>{busy?'Thinking…':'Send'}</button></form></section>;
}
