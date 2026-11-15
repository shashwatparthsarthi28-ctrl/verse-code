// Grants the `admin` custom claim so a user can open the Admin dashboard and
// call adminStats / adminSetConfig. Usage (from functions/):
//   GOOGLE_APPLICATION_CREDENTIALS=serviceAccount.json node ../scripts/set_admin.js user@example.com
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
initializeApp();
(async () => {
  const email = process.argv[2];
  if (!email) throw new Error('Usage: node set_admin.js <email>');
  const u = await getAuth().getUserByEmail(email);
  await getAuth().setCustomUserClaims(u.uid, { admin: true });
  console.log(`admin claim set for ${email}. Sign out and back in to refresh the token.`);
})().catch((e) => { console.error(e.message); process.exit(1); });
