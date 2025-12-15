const jwt = require('jsonwebtoken');

// Your Apple Developer details
const TEAM_ID = 'FNMT325P7M';
const KEY_ID = 'UV59ZZPNW5';
const SERVICE_ID = 'com.darshsenthil.graceai.signin';

// Your private key (the .p8 file content)
const PRIVATE_KEY = `-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgzS5Q23dWKyOTZxd4
MYJnLzaEB3HwzjjDqTdmyvRFxFegCgYIKoZIzj0DAQehRANCAASyUcVhfUNl1jKF
iTq1PLHwDWuKc3pZ2sKF9KMLJ0YgNfvdsAhw26R3pwgQ72/Iwashp2aBv1ZiuEoy
V+F9oBmc
-----END PRIVATE KEY-----`;

// Create the JWT
const token = jwt.sign(
  {
    iss: TEAM_ID,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 86400 * 180, // 6 months from now
    aud: 'https://appleid.apple.com',
    sub: SERVICE_ID
  },
  PRIVATE_KEY,
  {
    algorithm: 'ES256', // Apple uses ES256, not RS256
    header: {
      kid: KEY_ID,
      alg: 'ES256'
    }
  }
);

console.log('\n🎉 Generated JWT Token:\n');
console.log(token);
console.log('\n📋 Copy the token above and paste it into Supabase as your Secret Key!\n');

