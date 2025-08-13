#\!/usr/bin/env node
const fs=require('fs'), path=require('path');
const ROOT=process.cwd(), DOCS=path.join(ROOT,'docs-site','docs');
let changed=0, scanned=0;
function walk(d){
  for(const f of fs.readdirSync(d)){
    const p=path.join(d,f);
    const st=fs.statSync(p);
    if(st.isDirectory()) walk(p);
    else if(/\.(md|mdx)$/i.test(f)){
      scanned++;
      let s=fs.readFileSync(p,'utf8'), b=s;
      // normalize typical wrong prefixes to the canonical /diagrams/*
      s=s.replace(/\((?:\.\/)?docs\/assets\/diagrams\/([^)]+)\)/g,'(/diagrams/$1)')
         .replace(/\((?:\.\/)?assets\/diagrams\/([^)]+)\)/g,'(/diagrams/$1)')
         .replace(/\((?:\.\/)?docs\/assets\/images\/diagrams\/([^)]+)\)/g,'(/diagrams/$1)');
      if(s\!==b){ fs.writeFileSync(p,s,'utf8'); changed++; }
    }
  }
}
if (fs.existsSync(DOCS)) walk(DOCS);
console.log(JSON.stringify({scanned, changed}));
