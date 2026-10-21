// Isolated QA fixture. The API points ONLY at the local sandbox on port 3003.
import assert from 'node:assert/strict';
const ROOT = 'http://127.0.0.1:3003';
const AUTH = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/';
const email='qa-persisted-applicant@example.test';
const password='QA-Fictional-Only-42!';
async function credentials(path,body) {
 const res=await fetch(AUTH+path+'?key=qa-local',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(body)});
 return {status:res.status,body:await res.json()};
}
let auth=await credentials('accounts:signUp',{email,password,returnSecureToken:true});
if(auth.status===400) auth=await credentials('accounts:signInWithPassword',{email,password,returnSecureToken:true});
assert.equal(auth.status,200,'Firebase emulator fixture login');
// QA-only email verification is mandatory before the backend permits writes.
// Complete the local Firebase Auth emulator flow; never use production tokens.
const tokenClaims = JSON.parse(Buffer.from(auth.body.idToken.split('.')[1], 'base64url').toString('utf8'));
if (!tokenClaims.email_verified) {
  const sent = await credentials('accounts:sendOobCode', {
    requestType: 'VERIFY_EMAIL', idToken: auth.body.idToken,
  });
  assert.equal(sent.status, 200, 'QA emulator send verification');
  const codes = await (await fetch(
    'http://127.0.0.1:9099/emulator/v1/projects/capstone-4th-year-peso-ai/oobCodes',
  )).json();
  const code = (codes.oobCodes || []).filter(row =>
    row.email === email && row.requestType === 'VERIFY_EMAIL').at(-1)?.oobCode;
  assert.ok(code, 'QA email verification code');
  const verified = await credentials('accounts:update', { oobCode: code });
  assert.equal(verified.status, 200, 'QA emulator apply verification');
  auth = await credentials('accounts:signInWithPassword', {
    email, password, returnSecureToken: true,
  });
  assert.equal(auth.status, 200, 'QA verified token refresh');
}
const bearer=auth.body.idToken;
async function request(path,method='GET',body) {
 const res=await fetch(ROOT+path,{method,headers:{authorization:'Bearer '+bearer, 'content-type':'application/json'},
 body: body===undefined?undefined:JSON.stringify(body)});
 const json=await res.json();
 assert.equal(res.status,200,path+': '+res.status+' '+String(json.error||json.message||'').slice(0,100));
 return json;
}
await request('/api/profile/ensure','POST',{firstName:'QA',lastName:'Persisted Applicant',displayName:'QA Persisted Applicant'});
await request('/api/profile/onboarding','PATCH',{
 resumeData:{fullName:'QA Persisted Applicant',fileName:'qa_fictional_resume.pdf',plainText:'Fictional QA resume MS Excel and Data Entry',fields:[{label:'Full Name',value:'QA Persisted Applicant'},{label:'Skills',value:'MS Excel, Data Entry'}]},
 pesoFormData:{documentType:'nsrp_form',entries:[{index:1,label:'First Name',value:'QA'},{index:2,label:'Surname',value:'Persisted Applicant'},{index:3,label:'Municipality/City',value:'Rodriguez'}]},
 onboardingText:'I completed Senior High School and know MS Excel, Data Entry. This is a fictional QA sample.'
});
const extracted=await request('/api/ai/profile','POST',{
 rawText:'Fictional QA: Senior High School education and MS Excel / Data Entry skills. No real qualifications or personal data.'
});
assert.equal(extracted.saved,true);
await request('/api/profile/preferences','PATCH',{preferences:{language:'English',emailNotifications:true,appNotifications:true}});
const profile=await request('/api/profile');
assert.equal(profile.profile?.resumeData?.fullName,'QA Persisted Applicant');
// Attach one clearly fictional PDF so the signed-in viewer can test GridFS.
const files=await request('/api/artifacts');
if (!files.artifacts?.some((item)=>item.category==='resume_upload')) {
 const fs=await import('node:fs/promises');
 const bytes=await fs.readFile(new URL('../../docs/qa_browser/qa_fictional_resume.pdf',import.meta.url));
 const upload=await fetch(ROOT+'/api/artifacts',{method:'POST',headers:{
  authorization:'Bearer '+bearer,'content-type':'application/json'
 },body:JSON.stringify({category:'resume_upload',mimeType:'application/pdf',
  fileName:'qa_fictional_resume.pdf',base64:bytes.toString('base64')})});
 assert.equal(upload.status,201,'QA fictional PDF upload');
}
console.log(JSON.stringify({ok:true,case:'fictional applicant fixture',api:ROOT,
 createdIn:'local MongoDB + Firebase Auth emulator',email,
 persistedResume:true,extractionSaved:extracted.saved,jobMatch:extracted.jobMatching?.status,
 preferences:profile.profile?.preferences?.language,liveRecordsUnaffected:true}));
