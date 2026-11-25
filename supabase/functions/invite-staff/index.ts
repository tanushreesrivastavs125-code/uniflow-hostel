import { createClient } from 'npm:@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type'};
Deno.serve(async req=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:cors});
 if(req.method!=='POST') return Response.json({error:'Method not allowed'},{status:405,headers:cors});
 try {
  const authorization=req.headers.get('Authorization');
  if(!authorization) return Response.json({error:'Unauthorized'},{status:401,headers:cors});
  const url=Deno.env.get('SUPABASE_URL')!;
  const userDb=createClient(url,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:authorization}}});
  const {data:{user},error:authError}=await userDb.auth.getUser();
  if(authError||!user) return Response.json({error:'Unauthorized'},{status:401,headers:cors});
  const {data:profile,error:profileError}=await userDb.from('profiles').select('role').eq('id',user.id).single();
  if(profileError||profile?.role!=='admin') return Response.json({error:'Forbidden'},{status:403,headers:cors});
  const input=await req.json();
  const email=typeof input.email==='string'?input.email.trim().toLowerCase():'';
  const name=typeof input.name==='string'?input.name.trim():'';
  const department=typeof input.department==='string'?input.department.trim():'';
  if(email.length>254||!/^\S+@\S+\.\S+$/.test(email)||name.length<2||name.length>120||department.length<2||department.length>100)
    return Response.json({error:'Enter a valid email, name, and department.'},{status:400,headers:cors});
  const redirectTo=Deno.env.get('STAFF_INVITE_REDIRECT_URL');
  if(!redirectTo) return Response.json({error:'Staff invitations are not configured. Set STAFF_INVITE_REDIRECT_URL in the function secrets.'},{status:503,headers:cors});
  const server=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false}});
  const {data,error}=await server.auth.admin.inviteUserByEmail(email,{data:{full_name:name},redirectTo});
  if(error||!data.user) return Response.json({error:error?.message||'Invitation failed.'},{status:400,headers:cors});
  const {error:staffError}=await server.from('staff').insert({id:data.user.id,department,active:true});
  if(staffError) {console.error('Invited account needs staff setup',data.user.id,staffError);return Response.json({error:'The invitation was sent, but account setup failed. Ask a database administrator to finish setup before the invitee signs in.'},{status:500,headers:cors})}
  const {error:roleError}=await server.from('profiles').update({role:'staff'}).eq('id',data.user.id);
  if(roleError) {console.error('Invited account needs role setup',data.user.id,roleError);return Response.json({error:'The invitation was sent, but role setup failed. Ask a database administrator to finish setup before the invitee signs in.'},{status:500,headers:cors})}
  return Response.json({ok:true},{headers:cors});
 } catch(error){console.error('Staff invitation failed',error);return Response.json({error:'Staff invitation failed.'},{status:500,headers:cors})}
});
