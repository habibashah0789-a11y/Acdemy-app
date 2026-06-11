// Usage (PowerShell):
// $env:SERVICE_ACCOUNT_PATH='path/to/serviceAccount.json'; $env:ADMIN_EMAIL='admin@example.com'; $env:ADMIN_PASSWORD='ChangeMe!123'; node tool/seed_admin.js

const admin = require('firebase-admin');
const path = require('path');

const serviceAccountPath = process.env.SERVICE_ACCOUNT_PATH;
const email = process.env.ADMIN_EMAIL;
const password = process.env.ADMIN_PASSWORD;

if (!serviceAccountPath || !email || !password) {
  console.error('Missing env vars. Set SERVICE_ACCOUNT_PATH, ADMIN_EMAIL, ADMIN_PASSWORD');
  process.exit(1);
}

const serviceAccount = require(path.resolve(serviceAccountPath));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const auth = admin.auth();
const firestore = admin.firestore();

(async () => {
  try {
    const user = await auth.createUser({
      email: email,
      password: password,
    });

    await auth.setCustomUserClaims(user.uid, { admin: true });
    await firestore.collection('admins').doc(user.uid).set({ admin: true, email });

    console.log('Created admin user:', user.uid);
  } catch (err) {
    console.error('Error creating admin:', err);
    process.exit(1);
  }
})();
