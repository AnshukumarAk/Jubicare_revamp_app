const https = require('https');

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, data: JSON.parse(body) });
        } catch (_) {
          resolve({ status: res.statusCode, headers: res.headers, raw: body });
        }
      });
    });
    req.on('error', reject);
    if (data) {
      req.write(typeof data === 'string' ? data : JSON.stringify(data));
    }
    req.end();
  });
}

async function main() {
  const loginRes = await request({
    hostname: 'revamp-back2.indevconsultancy.in',
    path: '/api/m/auth/login',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    }
  }, {
    username: 'con_test1',
    password: 'Contest@123'
  });

  const token = loginRes.data?.access_token;

  const res = await request({
    hostname: 'revamp-back2.indevconsultancy.in',
    path: '/api/m/camps?limit=4',
    method: 'GET',
    headers: {
      'Accept': 'application/json',
      'Authorization': 'Bearer ' + token
    }
  });

  console.log('Top 4 camps:', JSON.stringify(res.data, null, 2));
}

main().catch(console.error);
