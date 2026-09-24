const https = require('https');
const urls = [
  'https://utfs.io/f/e54dfcd7-d52d-41a1-8142-ad9f779193d8-fp40ow.mp4',
  'https://utfs.io/f/3cc5d0ca-01ca-4963-850d-47ed30347583-udiazf.mp4',
  'https://utfs.io/f/cf875875-1cf2-482e-ada7-f248acf1a5c5-ue5agp.mp4'
];

urls.forEach(url => {
  const req = https.request(url, { method: 'HEAD' }, res => {
    console.log(url, '=> Status:', res.statusCode, 'Length:', res.headers['content-length'], 'Type:', res.headers['content-type']);
  });
  req.on('error', err => console.error(url, err.message));
  req.end();
});
