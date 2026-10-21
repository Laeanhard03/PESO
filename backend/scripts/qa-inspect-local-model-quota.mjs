// Read-only diagnostic for the isolated PESO QA database; never Atlas.
import { MongoClient } from 'mongodb';
const uri = 'mongodb://127.0.0.1:27117/?directConnection=true';
const database = 'peso_e2e_browser_20261020';
const client = new MongoClient(uri, {serverSelectionTimeoutMS:3000});
try {
  await client.connect();
  const db = client.db(database);
  const rows = await db.collection('geminiModelQuotas')
    .find({}, {projection:{_id:1,until:1,scope:1,metric:1,observedAt:1}})
    .limit(30).toArray();
  const now = new Date();
  console.log(JSON.stringify({environment:'QA_LOCAL_ONLY',database,
    now:now.toISOString(),modelQuotas:rows.map(x=>({
      model:String(x._id),scope:x.scope||null,metric:x.metric||null,
      active: x.until instanceof Date && x.until>now,
      retryAfterSeconds:x.until instanceof Date && x.until>now
        ? Math.ceil((x.until-now)/1000) : 0,
      until:x.until instanceof Date ? x.until.toISOString() : null,
      observedAt:x.observedAt instanceof Date?x.observedAt.toISOString():null
    }))},null,2));
} finally { await client.close(); }
