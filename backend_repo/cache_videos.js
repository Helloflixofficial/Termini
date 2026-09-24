const fs = require('fs');
const path = require('path');
const https = require('https');

const videoDir = path.join(__dirname, 'public', 'videos');
if (!fs.existsSync(videoDir)) {
  fs.mkdirSync(videoDir, { recursive: true });
}

const videos = [
  {
    id: 'b9040e16-bcc8-414a-a91d-c33775f0bcdc',
    url: 'https://utfs.io/f/e54dfcd7-d52d-41a1-8142-ad9f779193d8-fp40ow.mp4',
    name: 'Baisc'
  },
  {
    id: '3bc63c4f-9cba-4611-a475-319fa72c789d',
    url: 'https://utfs.io/f/cf875875-1cf2-482e-ada7-f248acf1a5c5-ue5agp.mp4',
    name: 'Full Video'
  },
  {
    id: 'a07db4e1-48ae-4e5c-ac9d-23f0f9c23544',
    url: 'https://utfs.io/f/3cc5d0ca-01ca-4963-850d-47ed30347583-udiazf.mp4',
    name: 'basic'
  }
];

function downloadVideo(v) {
  return new Promise((resolve, reject) => {
    const dest = path.join(videoDir, `${v.id}.mp4`);
    if (fs.existsSync(dest) && fs.statSync(dest).size > 1000000) {
      console.log(`[Cache] Already cached: ${v.name} (${fs.statSync(dest).size} bytes)`);
      return resolve(dest);
    }
    console.log(`[Cache] Downloading ${v.name} (${v.url})...`);
    const file = fs.createWriteStream(dest);
    https.get(v.url, res => {
      if (res.statusCode !== 200) {
        return reject(new Error(`Failed to download ${v.name}: ${res.statusCode}`));
      }
      res.pipe(file);
      file.on('finish', () => {
        file.close(() => {
          console.log(`[Cache] Downloaded ${v.name} successfully (${fs.statSync(dest).size} bytes)`);
          resolve(dest);
        });
      });
    }).on('error', err => {
      fs.unlink(dest, () => {});
      reject(err);
    });
  });
}

async function run() {
  for (const v of videos) {
    try {
      await downloadVideo(v);
    } catch (e) {
      console.error(e.message);
    }
  }
  console.log('All videos cached successfully!');
}

run();
