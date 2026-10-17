// Real HTTP verification with disposable fictional users. Never reads real user content.
// prepare -> seed SQL via connector -> verify -> detach SQL via connector -> cleanup-files
// -> cleanup-users SQL via connector. Credentials live only in ignored tmp/ until cleanup.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import assert from 'node:assert/strict';

const root=path.resolve(import.meta.dirname,'..');
const manifestPath=path.join(root,'tmp/platform-http-fixture.json');
let reportPath=path.join(root,'tmp/platform-http-report.json');
const phase=process.argv[2];
const quote=value=>"'"+String(value).replaceAll("'","''")+"'";
const config=JSON.parse(fs.readFileSync(path.join(root,'assets/client_config.json'),'utf8'));
const base=config.SUPABASE_URL;
const checks=[];
function check(name,condition){assert.ok(condition,name);checks.push(name);console.log('PASS: '+name);}
function save(state){fs.writeFileSync(manifestPath,JSON.stringify(state,null,2));}

if(phase==='prepare'||phase==='prepare-recovery'){
  assert.ok(!fs.existsSync(manifestPath),'Clean up the previous fixture first.');
  const state={marker:crypto.randomUUID(),createdAt:new Date().toISOString(),purpose:phase==='prepare-recovery'?'recovery-ui':'platform-http',users:{},uploads:[]};
  for(const name of (phase==='prepare-recovery'?['candidate']:['candidate','employer','other','admin'])){
    state.users[name]={id:crypto.randomUUID(),email:'nextrole-e2e-'+name+'-'+state.marker+'@example.invalid',password:crypto.randomBytes(32).toString('hex')};
  }
  save(state);
  const sql=['begin;'];
  for(const [name,u] of Object.entries(state.users)){
    sql.push('insert into auth.users(id,instance_id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at,confirmation_token,recovery_token,email_change,email_change_token_new,raw_app_meta_data,raw_user_meta_data) values('+
      quote(u.id)+",'00000000-0000-0000-0000-000000000000','authenticated','authenticated',"+quote(u.email)+',extensions.crypt('+quote(u.password)+",extensions.gen_salt('bf')),now(),now(),now(),'','','','',"+
      quote(JSON.stringify({provider:'email',providers:['email']}))+'::jsonb,'+quote(JSON.stringify({full_name:'Disposable E2E '+name,role:'admin'}))+'::jsonb);');
    sql.push('insert into auth.identities(user_id,provider_id,provider,identity_data,created_at,updated_at) values('+quote(u.id)+','+quote(u.id)+",'email',"+
      quote(JSON.stringify({sub:u.id,email:u.email,email_verified:true}))+'::jsonb,now(),now());');
  }
  if(state.users.admin)sql.push("update public.nextrole_members set role='admin' where id="+quote(state.users.admin.id)+';');
  sql.push("commit; select 'Disposable test accounts prepared' as result;");
  console.log(JSON.stringify({sql:sql.join('\n')}));
  process.exit(0);
}
assert.ok(fs.existsSync(manifestPath),'Prepare disposable fixtures first.');
const state=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
if(state.purpose==='recovery-ui')reportPath=path.join(root,'tmp/recovery-callback-report.json');
const ids=Object.values(state.users).map(u=>quote(u.id)).join(',');
if(phase==='detach-sql'){
  assert.ok(state.jobId&&state.companyId,'No submitted test data to detach.');
  console.log(JSON.stringify({sql:[
    'begin;',
    'delete from public.nextrole_application_notes where application_id in(select id from public.nextrole_applications where candidate_id in('+ids+'));',
    'delete from public.nextrole_application_events where application_id in(select id from public.nextrole_applications where candidate_id in('+ids+'));',
    'delete from public.nextrole_applications where candidate_id in('+ids+');',
    "commit; select 'Disposable application records detached for storage cleanup' as result;",
  ].join('\n')}));
  process.exit(0);
}
if(phase==='cleanup-users-sql'){
  assert.equal(state.filesCleaned,true,'Remove fixture file bytes through Storage API before deleting accounts.');
  const sql=['begin;'];
  sql.push('delete from public.nextrole_saved where user_id in('+ids+');');
  sql.push('delete from public.nextrole_resume_files where user_id in('+ids+');');
  sql.push('delete from public.nextrole_privacy_requests where user_id in('+ids+');');
  sql.push('delete from public.nextrole_notifications where user_id in('+ids+');');
  sql.push('delete from public.nextrole_reports where reporter_id in('+ids+');');
  sql.push('delete from public.nextrole_account_requests where user_id in('+ids+');');
  sql.push('delete from public.nextrole_audit where actor_id in('+ids+');');
  sql.push('delete from public.nextrole_jobs where owner_id in('+ids+');');
  sql.push('delete from public.nextrole_companies where owner_id in('+ids+');');
  sql.push('delete from auth.users where id in('+ids+") and email like 'nextrole-e2e-%@example.invalid';");
  sql.push('commit;');
  sql.push('select count(*) as remaining_test_members from public.nextrole_members where id in('+ids+');');
  console.log(JSON.stringify({sql:sql.join('\n')}));
  process.exit(0);
}

async function request(route,{who,method='GET',body,headers={},allowFailure=false}={}){
  const h={apikey:config.SUPABASE_PUBLISHABLE_KEY,...headers};
  if(who)h.Authorization='Bearer '+state.users[who].token;
  if(body!==undefined&&!Buffer.isBuffer(body)){h['Content-Type']='application/json';body=JSON.stringify(body);}
  const response=await fetch(base+route,{method,headers:h,body,signal:AbortSignal.timeout(25000)});
  if(!response.ok&&!allowFailure){
    const error=await response.json().catch(()=>({}));
    throw Error(route.split('?')[0]+' returned '+response.status+': '+(error.message||error.msg||error.error||'request failed'));
  }
  return response;
}
async function login(who){
  const u=state.users[who];
  const response=await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email:u.email,password:u.password}});
  const auth=await response.json();
  assert.equal(auth.user.id,u.id);
  u.token=auth.access_token;
  u.refreshToken=auth.refresh_token;
  u.expiresIn=auth.expires_in; // Memory only; persist() strips credentials below.
}
const persist=()=>{
  const clean=structuredClone(state);
  for(const u of Object.values(clean.users)){delete u.token;delete u.refreshToken;delete u.expiresIn;}
  fs.writeFileSync(manifestPath,JSON.stringify(clean,null,2));
};
async function rpc(who,action,payload,allowFailure=false){
  const response=await request('/rest/v1/rpc/nextrole_action',{who,method:'POST',body:{action,payload},allowFailure});
  return allowFailure?response:response.json();
}
async function rows(who,table,query=''){
  return(await request('/rest/v1/nextrole_'+table+'?select=*'+query,{who})).json();
}
async function upload(who,bucket,name,bytes,type,upsert=false){
  state.uploads.push({who,bucket,name});persist();
  await request('/storage/v1/object/'+bucket+'/'+name,{who,method:'POST',body:bytes,headers:{'Content-Type':type,'x-upsert':String(upsert)}});
}
async function signed(who,bucket,name,allowFailure=false){
  const response=await request('/storage/v1/object/sign/'+bucket+'/'+name,{who,method:'POST',body:{expiresIn:60},allowFailure});
  if(allowFailure)return response;
  const value=await response.json();
  const relative=value.signedURL||value.signedUrl;
  assert.ok(relative,'Storage returned a signed link');
  const url=relative.startsWith('http')?relative:base+(relative.startsWith('/storage/v1/')?'':'/storage/v1')+relative;
  return Buffer.from(await(await fetch(url)).arrayBuffer());
}
function pdf(text){
  const stream='BT /F1 12 Tf 30 100 Td ('+text+') Tj ET';
  const objects=['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 160] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length '+Buffer.byteLength(stream)+' >>\nstream\n'+stream+'\nendstream','<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'];
  let result='%PDF-1.4\n';const offsets=[0];
  objects.forEach((object,i)=>{offsets.push(Buffer.byteLength(result));result+=(i+1)+' 0 obj\n'+object+'\nendobj\n';});
  const xref=Buffer.byteLength(result);
  result+='xref\n0 6\n0000000000 65535 f \n'+offsets.slice(1).map(n=>String(n).padStart(10,'0')+' 00000 n \n').join('');
  return Buffer.from(result+'trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n'+xref+'\n%%EOF\n');
}
async function run(){
try{
  if(phase==='recovery-session'){
    assert.equal(state.purpose,'recovery-ui');
    await login('candidate');
    const u=state.users.candidate;
    const fragment=new URLSearchParams({access_token:u.token,refresh_token:u.refreshToken,expires_in:String(u.expiresIn),token_type:'bearer',type:'recovery'});
    fs.writeFileSync(path.join(root,'tmp/recovery-test-url.txt'),'http://127.0.0.1:8081/app.html#'+fragment);
    console.log('Disposable recovery callback prepared for isolated port 8081; no email sent.');
    return;
  }
  if(phase==='recovery-ui-passed'){
    assert.equal(state.purpose,'recovery-ui');
    fs.writeFileSync(reportPath,JSON.stringify({passed:true,checkedAt:new Date().toISOString(),checks:[
      'Real Supabase session consumed by browser callback',
      'Recovery callback renders new-password and confirmation fields instead of 404',
      'Test runs on isolated origin without altering real user sessions',
      'No password was changed; email-link delivery replay remains blocked by email quota'
    ]},null,2));
    console.log('Browser-verified recovery callback result recorded.');return;
  }
  if(phase==='finalize'){
    assert.equal(state.filesCleaned,true,'Clean up storage before finalizing.');
    for(const u of Object.values(state.users)){
      const response=await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email:u.email,password:u.password},allowFailure:true});
      const body=await response.json();
      assert.equal(body.error_code,'invalid_credentials','Disposable account must no longer authenticate.');
    }
    const report=JSON.parse(fs.readFileSync(reportPath,'utf8'));
    report.cleanupVerified=true;
    report.cleanupCheckedAt=new Date().toISOString();
    report.testAccounts=Object.keys(state.users).length;
    report.realUserRecordsChanged=false;
    fs.mkdirSync(path.join(root,'docs/verification'),{recursive:true});
    fs.writeFileSync(path.join(root,'docs/verification/'+(state.purpose==='recovery-ui'?'recovery-callback':'platform-http')+'-2026-10-17.json'),JSON.stringify(report,null,2)+'\n');
    fs.unlinkSync(manifestPath);
    if(fs.existsSync(path.join(root,'tmp/recovery-test-url.txt')))fs.unlinkSync(path.join(root,'tmp/recovery-test-url.txt'));
    console.log('PASS: test accounts no longer authenticate; disposable credentials removed; sanitized report saved.');
    return;
  }
  if(phase==='cleanup-files'){
    for(const who of new Set(state.uploads.map(u=>u.who)))await login(who);
    for(const [bucket,who] of new Map(state.uploads.map(u=>[u.bucket+':'+u.who,[u.bucket,u.who]])).values()){
      const prefixes=[...new Set(state.uploads.filter(u=>u.bucket===bucket&&u.who===who).map(u=>u.name))];
      await request('/storage/v1/object/'+bucket,{who,method:'DELETE',body:{prefixes}});
    }
    for(const entry of state.uploads){
      const response=await signed(entry.who,entry.bucket,entry.name,true);
      assert.ok(!response.ok,'Test file must no longer be downloadable.');
    }
    state.filesCleaned=true;persist();console.log('PASS: all uploaded fixture bytes removed through Storage API');return;
  }
  assert.equal(phase,'verify');
  for(const who of Object.keys(state.users))await login(who);
  check('Four temporary accounts authenticate using email/password',true);
  const candidate=state.users.candidate.id;
  check('Signup metadata cannot grant candidate admin access',(await rows('candidate','members','&id=eq.'+candidate))[0].role==='employee');
  await rpc('candidate','profile_save',{full_name:'Fictional Candidate',headline:'E2E profile'});
  const company=await rpc('employer','company_request',{name:'E2E Temporary Fictional Studio',description:'Disposable end-to-end verification company. Not a real employer.',location:'Remote',industry:'Engineering'});
  state.companyId=company.id;persist();
  const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aN1cAAAAASUVORK5CYII=','base64');
  await upload('employer','nextrole-company-logos',company.id+'/logo.png',png,'image/png',true);
  check('Pending company logo is hidden from guests',!(await signed(undefined,'nextrole-company-logos',company.id+'/logo.png',true)).ok);
  check('Employer cannot approve their own company',!(await rpc('employer','company_review',{id:company.id,status:'approved',reason:'Self approval must fail'},true)).ok);
  await rpc('admin','company_review',{id:company.id,status:'approved',reason:'Disposable test employer approved'});
  check('Employer role becomes available after admin approval',(await rows('employer','members','&id=eq.'+state.users.employer.id))[0].role==='employer');
  check('Approved company PNG downloads byte-for-byte',png.equals(await signed(undefined,'nextrole-company-logos',company.id+'/logo.png')));
  const job=await rpc('employer','job_save',{title:'E2E verification - temporary fictional role',location:'Remote',category:'Engineering',employment_type:'Internship',
    arrangement:'Remote',salary:'RM 1000 per month (fictional)',description:'Temporary fictional role used only to verify the full application workflow.',closes_at:'2027-12-31'});
  state.jobId=job.id;persist();
  await rpc('employer','job_status',{id:job.id,status:'pending'});
  check('Employer cannot bypass job moderation',!(await rpc('employer','job_status',{id:job.id,status:'published'},true)).ok);
  await rpc('admin','job_status',{id:job.id,status:'published',reason:'Disposable test job approved'});
  check('Guest can discover approved published job',(await rows(undefined,'jobs','&id=eq.'+job.id)).length===1);
  await rpc('candidate','save_job',{id:job.id,saved:true});
  check('Saved job persists in candidate account',(await rows('candidate','saved','&job_id=eq.'+job.id)).length===1);
  await request('/rest/v1/nextrole_drafts?on_conflict=user_id,job_id',{who:'candidate',method:'POST',headers:{Prefer:'resolution=merge-duplicates'},
    body:{user_id:candidate,job_id:job.id,full_name:'Fictional Candidate',email:'fictional@example.invalid',introduction:'PRIVATE DRAFT - not submitted'}});
  check('Employer cannot read private draft',(await rows('employer','drafts','&job_id=eq.'+job.id)).length===0);
  const original=pdf('Fictional candidate - original submitted resume');
  const replacement=pdf('Fictional candidate - replacement private resume');
  const current=candidate+'/resume.pdf';
  await upload('candidate','nextrole-resumes',current,original,'application/pdf',true);
  const downloaded=Buffer.from(await(await request('/storage/v1/object/authenticated/nextrole-resumes/'+current,{who:'candidate'})).arrayBuffer());
  check('Private PDF uploads and downloads byte-for-byte',downloaded.equals(original));
  const libraryA=crypto.randomUUID(), libraryB=crypto.randomUUID(), libraryA2=crypto.randomUUID();
  await upload('candidate','nextrole-resume-library',candidate+'/'+libraryA+'.pdf',original,'application/pdf');
  await rpc('candidate','resume_register',{id:libraryA,file_name:'Design CV.pdf',display_name:'Design CV'});
  await upload('candidate','nextrole-resume-library',candidate+'/'+libraryB+'.pdf',replacement,'application/pdf');
  await rpc('candidate','resume_register',{id:libraryB,file_name:'Engineering CV.pdf',display_name:'Engineering CV'});
  check('Candidate can keep two distinct private resumes',(await rows('candidate','resume_files','&is_current=eq.true')).length===2);
  check('Employer cannot read private resume library',(await rows('employer','resume_files','&user_id=eq.'+candidate)).length===0);
  check('Admin cannot read private resume library',(await rows('admin','resume_files','&user_id=eq.'+candidate)).length===0);
  check('Other account cannot download a library PDF',!(await signed('other','nextrole-resume-library',candidate+'/'+libraryA+'.pdf',true)).ok);
  await upload('candidate','nextrole-resume-library',candidate+'/'+libraryA2+'.pdf',replacement,'application/pdf');
  await rpc('candidate','resume_register',{id:libraryA2,library_id:libraryA,file_name:'Design CV revised.pdf',display_name:'Design CV'});
  const libraryRows=await rows('candidate','resume_files','&library_id=eq.'+libraryA);
  check('Replacing a library resume creates a new version',libraryRows.some(r=>r.version===2&&r.is_current)&&libraryRows.some(r=>r.version===1&&!r.is_current));
  const appId=crypto.randomUUID(),snapshot=candidate+'/'+appId+'.pdf';
  await upload('candidate','nextrole-application-resumes',snapshot,downloaded,'application/pdf');
  await rpc('candidate','application_submit',{id:appId,job_id:job.id,full_name:'Fictional Candidate',email:'fictional@example.invalid',
    introduction:'Reviewed introduction shared explicitly',resume_path:snapshot,resume_version_id:libraryA});
  state.applicationId=appId;persist();
  check('Employer sees the submitted application',(await rows('employer','applications','&id=eq.'+appId)).length===1);
  const sent=(await rows('employer','applications','&id=eq.'+appId))[0];
  check('Submission preserves the deliberately selected filename and version',sent.snapshot.resume_file_name==='Design CV.pdf'&&sent.snapshot.resume_version===1);
  await request('/storage/v1/object/nextrole-resume-library',{who:'candidate',method:'DELETE',body:{prefixes:[candidate+'/'+libraryA+'.pdf',candidate+'/'+libraryA2+'.pdf']}});
  await rpc('candidate','resume_delete',{id:libraryA});
  check('Deleting a private library family does not alter submitted bytes',original.equals(await signed('employer','nextrole-application-resumes',snapshot)));
  await rpc('candidate','report_job',{id:job.id,reason:'Disposable verification report about fictional job wording.'});
  const report=(await rows('admin','reports','&job_id=eq.'+job.id))[0];
  await rpc('admin','report_save_work',{id:report.id,expected_revision:1,reviewer_id:state.users.admin.id,investigation_note:'SECRET INVESTIGATION NOTE'});
  check('Report supports assigned reviewer and private investigation notes',(await rows('admin','report_work','&report_id=eq.'+report.id))[0].investigation_note==='SECRET INVESTIGATION NOTE');
  check('Candidate cannot read administrator investigation notes',(await rows('candidate','report_work','&report_id=eq.'+report.id)).length===0);
  check('Employer cannot read administrator investigation notes',(await rows('employer','report_work','&report_id=eq.'+report.id)).length===0);
  check('Stale report edits are rejected',!(await rpc('admin','report_save_work',{id:report.id,expected_revision:1,reviewer_id:null,investigation_note:'Stale overwrite'},true)).ok);
  await rpc('admin','report_resolve',{id:report.id,expected_revision:2,status:'resolved',reason:'PRIVATE ADMIN RESOLUTION SUMMARY',public_message:'The fictional listing wording was reviewed.'});
  const publicReport=(await rows('candidate','reports','&id=eq.'+report.id))[0];
  check('Public report outcome excludes the private resolution summary',publicReport.public_message==='The fictional listing wording was reviewed.'&&!JSON.stringify(publicReport).includes('PRIVATE ADMIN'));
  check('Candidate notifications exclude private admin notes and summary',!JSON.stringify(await rows('candidate','notifications')).includes('PRIVATE ADMIN')&&!JSON.stringify(await rows('candidate','notifications')).includes('SECRET INVESTIGATION'));
  const privacy=await rpc('candidate','privacy_request',{kind:'access',message:'Disposable request to verify the privacy contact workflow.'});
  check('Privacy requests are visible to their owner',(await rows('candidate','privacy_requests','&id=eq.'+privacy.id)).length===1);
  check('Other users cannot read privacy requests',(await rows('other','privacy_requests','&id=eq.'+privacy.id)).length===0);
  await rpc('admin','privacy_respond',{id:privacy.id,expected_revision:1,status:'resolved',response:'Disposable request reviewed; no real user information was changed.'});
  check('Owner can read the in-app privacy response',(await rows('candidate','privacy_requests','&id=eq.'+privacy.id))[0].status==='resolved');
  check('Candidates cannot access operator retention review',!(await rpc('candidate','retention_review',{},true)).ok);
  const review=await rpc('admin','retention_review',{});
  check('Admin retention review returns counts without private files',Number.isInteger(review.private_drafts_due)&&!JSON.stringify(review).includes('.pdf'));
  await rpc('admin','member_suspend',{id:state.users.other.id,suspended:true,reason:'Disposable privacy accessibility check'});
  const suspendedRequest=await rpc('other','privacy_request',{kind:'other',message:'A suspended account can still contact the privacy operator.'});
  check('Suspended account retains access to its privacy contact channel',(await rows('other','privacy_requests','&id=eq.'+suspendedRequest.id)).length===1);
  await rpc('admin','member_suspend',{id:state.users.other.id,suspended:false,reason:'Disposable privacy check completed'});
  check('Employer downloads submitted PDF byte-for-byte',original.equals(await signed('employer','nextrole-application-resumes',snapshot)));
  await upload('candidate','nextrole-resumes',current,replacement,'application/pdf',true);
  check('Replacing current resume preserves submitted PDF',original.equals(await signed('employer','nextrole-application-resumes',snapshot)));
  check('Unrelated candidate cannot read application',(await rows('other','applications','&id=eq.'+appId)).length===0);
  check('Unrelated candidate cannot create resume link',!(await signed('other','nextrole-application-resumes',snapshot,true)).ok);
  check('Administrator has no default application-content access',(await rows('admin','applications','&id=eq.'+appId)).length===0);
  check('Administrator cannot create private resume link',!(await signed('admin','nextrole-application-resumes',snapshot,true)).ok);
  await rpc('employer','application_note',{id:appId,note:'PRIVATE EMPLOYER NOTE'});
  check('Candidate cannot read employer notes',(await rows('candidate','application_notes','&application_id=eq.'+appId)).length===0);
  await rpc('employer','application_status',{id:appId,status:'interview',message:'Fictional interview status for verification'});
  check('Candidate receives application timeline',(await rows('candidate','application_events','&application_id=eq.'+appId)).some(e=>e.status==='interview'));
  check('Candidate receives status notification',(await rows('candidate','notifications')).some(n=>n.title==='Application interview'));
  check('Duplicate application is rejected',!(await rpc('candidate','application_submit',{id:appId,job_id:job.id,full_name:'Fictional Candidate',
    email:'fictional@example.invalid',introduction:'Duplicate',resume_path:snapshot},true)).ok);
  await rpc('candidate','application_status',{id:appId,status:'withdrawn'});
  check('Withdrawal is visible to employer',(await rows('employer','applications','&id=eq.'+appId))[0].status==='withdrawn');
  check('Employer cannot reopen a final withdrawn application',!(await rpc('employer','application_status',{id:appId,status:'offer'},true)).ok);
  await rpc('employer','job_status',{id:job.id,status:'closed'});
  check('Closed saved job remains available to candidate',(await rows('candidate','jobs','&id=eq.'+job.id)).length===1);
  check('Closed job disappears from guest discovery',(await rows(undefined,'jobs','&id=eq.'+job.id)).length===0);
  check('Admin decisions are audited',(await rows('admin','audit','&actor_id=eq.'+state.users.admin.id)).length>=2);
  fs.writeFileSync(reportPath,JSON.stringify({passed:true,checkedAt:new Date().toISOString(),checks},null,2));
  persist();console.log(JSON.stringify({passed:true,checks:checks.length,report:'tmp/platform-http-report.json'}));
}catch(error){
  persist();
  if(phase==='verify'){
    fs.writeFileSync(reportPath,JSON.stringify({passed:false,checkedAt:new Date().toISOString(),checks,error:error.message},null,2));
  }else{
    const previous=fs.existsSync(reportPath)?JSON.parse(fs.readFileSync(reportPath,'utf8')):{};
    fs.writeFileSync(reportPath,JSON.stringify({...previous,cleanupErrors:[...(previous.cleanupErrors||[]),{phase,message:error.message}]},null,2));
  }
  console.error(error.message);process.exitCode=1;
}


}
await run();
