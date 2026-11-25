import test from 'node:test';
import assert from 'node:assert/strict';
import {requestAssistant} from '../src/assistant-api.js';

test('returns an answer and sends the question to the named function', async()=>{
 let call;
 const db={functions:{invoke:async(name,options)=>{call={name,options};return {data:{answer:'Contact maintenance.'},error:null}}}};
 assert.equal(await requestAssistant(db,'The water is off'), 'Contact maintenance.');
 assert.deepEqual(call,{name:'uniflow-ai',options:{body:{message:'The water is off'}}});
});
test('surfaces a meaningful server response instead of displaying a false answer',async()=>{
 const db={functions:{invoke:async()=>({data:null,error:{context:{json:async()=>({error:'Please wait before sending more messages.'})}}})}};
 await assert.rejects(requestAssistant(db,'Hello'),/Please wait/);
});
test('handles offline and malformed responses',async()=>{
 const offline={functions:{invoke:async()=>{throw new Error('network')}}};
 const malformed={functions:{invoke:async()=>({data:{answer:''},error:null})}};
 await assert.rejects(requestAssistant(offline,'Hello'),/connection/);
 await assert.rejects(requestAssistant(malformed,'Hello'),/invalid response/);
});
