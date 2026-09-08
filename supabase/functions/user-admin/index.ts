import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import {createClient} from 'npm:@supabase/supabase-js@2';

const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type','Access-Control-Allow-Methods':'POST, OPTIONS'};
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}});

type Role='OWNER'|'MANAGER'|'STAFF';
function secretKey(){const modern=Deno.env.get('SUPABASE_SECRET_KEYS');if(modern){try{const parsed=JSON.parse(modern);if(parsed?.default)return String(parsed.default)}catch{/* fallback below */}}return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')??''}

Deno.serve(async(req:Request)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
 if(req.method!=='POST')return json({error:'Method not allowed'},405);
 try{
  const url=Deno.env.get('SUPABASE_URL')??'';const publishableKeys=Deno.env.get('SUPABASE_PUBLISHABLE_KEYS');let publicKey=Deno.env.get('SUPABASE_ANON_KEY')??'';if(publishableKeys){try{const parsed=JSON.parse(publishableKeys);publicKey=String(parsed?.default??publicKey)}catch{/* legacy fallback */}}
  const secret=secretKey();const authHeader=req.headers.get('Authorization')??'';if(!url||!publicKey||!secret||!authHeader.startsWith('Bearer '))return json({error:'Server authentication is not configured'},500);
  const callerClient=createClient(url,publicKey,{global:{headers:{Authorization:authHeader}},auth:{persistSession:false}});const token=authHeader.replace('Bearer ','');const{data:userData,error:userError}=await callerClient.auth.getUser(token);if(userError||!userData.user)return json({error:'Unauthorized'},401);
  const admin=createClient(url,secret,{auth:{persistSession:false,autoRefreshToken:false}});const{data:profile,error:profileError}=await admin.from('profiles').select('role,is_active').eq('id',userData.user.id).maybeSingle();if(profileError||!profile||profile.role!=='OWNER'||!profile.is_active)return json({error:'OWNER access required'},403);
  const body=await req.json();const action=String(body?.action??'');
  if(action==='list'){
   const{data:list,error}=await admin.auth.admin.listUsers({page:1,perPage:1000});if(error)throw error;const ids=list.users.map(u=>u.id);const{data:profiles,error:pError}=ids.length?await admin.from('profiles').select('id,full_name,display_name,role,is_active').in('id',ids):{data:[],error:null};if(pError)throw pError;const map=new Map((profiles??[]).map(p=>[p.id,p]));return json({users:list.users.map(u=>{const p=map.get(u.id);return{id:u.id,email:u.email??'',full_name:p?.full_name??null,display_name:p?.display_name??null,role:(p?.role??'STAFF') as Role,is_active:p?.is_active??true,last_sign_in_at:u.last_sign_in_at??null,created_at:u.created_at??null}})});
  }
  if(action==='create'){
   const email=String(body.email??'').trim().toLowerCase();const password=String(body.password??'');const fullName=String(body.full_name??'').trim();const role=String(body.role??'STAFF').toUpperCase() as Role;if(!email||password.length<8||!fullName||!['OWNER','MANAGER','STAFF'].includes(role))return json({error:'Invalid user details'},400);
   const{data:created,error}=await admin.auth.admin.createUser({email,password,email_confirm:true,app_metadata:{role},user_metadata:{full_name:fullName}});if(error)throw error;if(!created.user)throw new Error('User was not created');const{error:insertError}=await admin.from('profiles').upsert({id:created.user.id,full_name:fullName,display_name:fullName,role,is_active:true});if(insertError){await admin.auth.admin.deleteUser(created.user.id);throw insertError}return json({user_id:created.user.id});
  }
  const target=String(body.user_id??'');if(!target)return json({error:'user_id is required'},400);
  if(action==='update_role'){
   const role=String(body.role??'').toUpperCase() as Role;if(!['OWNER','MANAGER','STAFF'].includes(role))return json({error:'Invalid role'},400);if(target===userData.user.id&&role!=='OWNER')return json({error:'You cannot remove your own OWNER role'},400);const{error:pError}=await admin.from('profiles').update({role}).eq('id',target);if(pError)throw pError;const{error:aError}=await admin.auth.admin.updateUserById(target,{app_metadata:{role}});if(aError)throw aError;return json({ok:true});
  }
  if(action==='reset_password'){
   const password=String(body.password??'');if(password.length<8)return json({error:'Password must be at least 8 characters'},400);const{error}=await admin.auth.admin.updateUserById(target,{password});if(error)throw error;return json({ok:true});
  }
  if(action==='set_active'){
   const active=Boolean(body.is_active);if(target===userData.user.id&&!active)return json({error:'You cannot deactivate your own account'},400);const{error:pError}=await admin.from('profiles').update({is_active:active}).eq('id',target);if(pError)throw pError;const{error:aError}=await admin.auth.admin.updateUserById(target,{ban_duration:active?'none':'876000h'});if(aError)throw aError;return json({ok:true});
  }
  return json({error:'Unknown action'},400);
 }catch(error){console.error(error);return json({error:error instanceof Error?error.message:'Unexpected error'},400)}
});
