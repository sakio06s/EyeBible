const fs=require('node:fs'),path=require('node:path');
const allowed=new Set(['/cloud/config.js','/cloud/core.js','/cloud/account.js','/cloud/groups.js','/cloud/vendor/supabase-2.119.0.js','/assets/eyebible.png']);
module.exports=(req,res)=>{const pathname=req.url.split('?')[0];if(!allowed.has(pathname))return false;res.setHeader('Content-Type',pathname.endsWith('.js')?'text/javascript':'image/png');res.end(fs.readFileSync(path.join(__dirname,'..',pathname)));return true};
