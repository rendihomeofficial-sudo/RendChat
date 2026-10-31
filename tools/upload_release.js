const fs = require('fs');
const path = require('path');
const https = require('https');
const { execSync } = require('child_process');

function getGitToken() {
  try {
    const input = 'protocol=https\nhost=github.com\n\n';
    const out = execSync('git credential fill', { input, encoding: 'utf8' });
    for (const line of out.split('\n')) {
      if (line.startsWith('password=')) return line.substring(9).trim();
    }
  } catch (e) {
    console.error('Failed to get token from git credential:', e.message);
  }
  return process.env.GITHUB_TOKEN || '';
}

function request(options, data) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', chunk => body += chunk);
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : {};
          resolve({ status: res.statusCode, headers: res.headers, body: parsed, raw: body });
        } catch (e) {
          resolve({ status: res.statusCode, headers: res.headers, raw: body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function uploadRelease() {
  const token = getGitToken();
  if (!token) {
    console.error('No GitHub token found!');
    process.exit(1);
  }

  const owner = 'rendihomeofficial-sudo';
  const repo = 'RendChat';
  const tag = process.argv[2] || ('v' + manifest.version);

  // Target signed APK
  const targetApk = path.join(__dirname, '..', 'build', 'app', 'outputs', 'flutter-apk', 'RenChat.apk');
  const fallbackApk = path.join(__dirname, '..', 'RenChat.apk');

  let chosenApk = targetApk;
  if (!fs.existsSync(chosenApk)) {
    if (fs.existsSync(fallbackApk)) {
      chosenApk = fallbackApk;
    } else {
      console.error('RenChat.apk not found!');
      process.exit(1);
    }
  }

  const apkStats = fs.statSync(chosenApk);
  console.log(`Using signed APK: ${chosenApk}`);
  console.log(`APK Size: ${(apkStats.size / (1024 * 1024)).toFixed(2)} MB`);

  const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'version.json'), 'utf8'));

  // 1. Get or create release
  console.log(`Checking release for tag ${tag}...`);
  let releaseRes = await request({
    hostname: 'api.github.com',
    path: `/repos/${owner}/${repo}/releases/tags/${tag}`,
    method: 'GET',
    headers: {
      'User-Agent': 'RenChat-Deployer',
      'Authorization': `Bearer ${token}`,
      'Accept': 'application/vnd.github.v3+json',
    }
  });

  let release = releaseRes.body;
  if (releaseRes.status === 404) {
    console.log(`Release ${tag} does not exist. Creating...`);
    const createRes = await request({
      hostname: 'api.github.com',
      path: `/repos/${owner}/${repo}/releases`,
      method: 'POST',
      headers: {
        'User-Agent': 'RenChat-Deployer',
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github.v3+json',
      }
    }, JSON.stringify({
      tag_name: tag,
      target_commitish: 'main',
      name: manifest.title,
      body: manifest.release_notes,
      draft: false,
      prerelease: false,
    }));

    if (createRes.status !== 201) {
      console.error('Failed to create release:', createRes.status, createRes.raw);
      process.exit(1);
    }
    release = createRes.body;
    console.log(`Release created! ID: ${release.id}`);
  } else if (releaseRes.status === 200) {
    console.log(`Release exists! ID: ${release.id}`);
    // Check if asset already exists
    if (Array.isArray(release.assets)) {
      for (const asset of release.assets) {
        if (asset.name === 'RenChat.apk') {
          console.log(`Deleting old asset ${asset.name} (id: ${asset.id})...`);
          await request({
            hostname: 'api.github.com',
            path: `/repos/${owner}/${repo}/releases/assets/${asset.id}`,
            method: 'DELETE',
            headers: {
              'User-Agent': 'RenChat-Deployer',
              'Authorization': `Bearer ${token}`,
            }
          });
        }
      }
    }
  }

  // 2. Upload asset
  console.log('Uploading RenChat.apk to release...');
  const uploadUrl = release.upload_url.replace(/\{(\?.*)?\}$/, '');
  const parsedUrl = new URL(uploadUrl);

  const fileStream = fs.createReadStream(chosenApk);
  const uploadReq = https.request({
    hostname: parsedUrl.hostname,
    path: `${parsedUrl.pathname}?name=RenChat.apk`,
    method: 'POST',
    headers: {
      'User-Agent': 'RenChat-Deployer',
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/vnd.android.package-archive',
      'Content-Length': apkStats.size,
    }
  }, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => {
      console.log('Upload response status:', res.statusCode);
      if (res.statusCode === 201) {
        console.log('SUCCESS: RenChat.apk uploaded to GitHub Release!');
        console.log(`Download URL: https://github.com/${owner}/${repo}/releases/download/${tag}/RenChat.apk`);
      } else {
        console.error('Failed to upload asset:', body);
      }
    });
  });

  uploadReq.on('error', (err) => {
    console.error('Upload error:', err);
  });

  fileStream.pipe(uploadReq);
}

uploadRelease().catch(console.error);
