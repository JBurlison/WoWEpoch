// Editable vector artwork for the accepted bookmark-layout.html design.
const fs=require('node:fs'),path=require('node:path');
const sharp=require(require.resolve('sharp',{paths:[process.cwd(),'C:/Users/JBurl/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules']}));
const root=path.resolve(__dirname,'..'),out=path.join(root,'MyEpoch/Media/Book'),src=path.join(root,'design/native-skin');
async function asset(name,w,h,body,tw=w,th=h){
 const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
 fs.writeFileSync(path.join(src,name+'.svg'),svg);
 const data=await sharp(Buffer.from(svg)).resize(tw,th,{fit:'fill'}).ensureAlpha().raw().toBuffer();
 const header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(tw,12);header.writeUInt16LE(th,14);header[16]=32;header[17]=8;
 const pixels=Buffer.alloc(data.length);for(let y=0;y<th;y++)for(let x=0;x<tw;x++){const a=(y*tw+x)*4,b=((th-1-y)*tw+x)*4;pixels[b]=data[a+2];pixels[b+1]=data[a+1];pixels[b+2]=data[a];pixels[b+3]=data[a+3];}
 fs.writeFileSync(path.join(out,name+'.tga'),Buffer.concat([header,pixels]));
 await sharp(data,{raw:{width:tw,height:th,channels:4}}).png().toFile(path.join(src,name+'.png'));
}
(async()=>{
 await asset('window-v2',1760,940,`<defs><linearGradient id="bg" x2="0" y2="1"><stop stop-color="#211b15"/><stop offset=".15" stop-color="#393022"/><stop offset="1" stop-color="#231c16"/></linearGradient><linearGradient id="title" x2="0" y2="1"><stop stop-color="#302519"/><stop offset=".54" stop-color="#100d0a"/><stop offset="1" stop-color="#201a12"/></linearGradient><pattern id="grain" width="6" height="6" patternUnits="userSpaceOnUse"><path d="M0 0l6 6" stroke="#755936" stroke-opacity=".1"/></pattern></defs><rect x="2" y="2" width="1756" height="936" rx="9" fill="url(#bg)" stroke="#332719" stroke-width="4"/><rect x="5" y="5" width="1750" height="930" rx="6" fill="url(#grain)" stroke="#ae8b51" stroke-width="2"/><rect x="8" y="8" width="1744" height="924" rx="4" fill="none" stroke="#5d482b" stroke-width="3"/><path d="M10 10H1750V42H10Z" fill="url(#title)"/><path d="M10 42H1750M10 124H1750" stroke="#937541"/><circle cx="39" cy="35" r="33" fill="#302218" stroke="#17110c" stroke-width="7"/><circle cx="39" cy="35" r="31" fill="none" stroke="#b39456" stroke-width="3"/>`,2048,1024);
 const old=fs.readFileSync(path.join(src,'book-v1.svg'),'utf8');
 const defs=old.match(/<defs>([\s\S]*?)<\/defs>/)[1];
 const corners=[[0,0],[1472,0],[0,764],[1472,764]].map(([x,y])=>`<g transform="translate(${x} ${y})"><rect x="1" y="1" width="26" height="26" rx="4" fill="url(#brass)" stroke="#bc9153" stroke-width="2"/><rect x="4" y="4" width="20" height="20" rx="2" fill="none" stroke="#5c4026"/><path d="M14 9l4 5-4 5-4-5z" fill="#dfbc77"/></g>`).join('');
 await asset('binding-v2',1500,792,`<defs>${defs}</defs><rect x="1" y="1" width="1498" height="790" rx="6" fill="url(#leather)" stroke="#896541" stroke-width="2"/><rect x="6" y="6" width="1488" height="780" rx="3" fill="url(#binding)" stroke="#271b13" stroke-width="3"/><rect x="9" y="9" width="1482" height="774" fill="none" stroke="#aa824e"/><rect x="13" y="13" width="1474" height="766" fill="none" stroke="#b38950" stroke-opacity=".65" stroke-dasharray="2 3"/>${corners}`,2048,1024);
 for(const active of [false,true])await asset(active?'bookmark-active-v2':'bookmark-v2',256,48,`<defs><linearGradient id="face"><stop stop-color="${active?'#8b372b':'#493824'}"/><stop offset="1" stop-color="${active?'#53251e':'#2e251b'}"/></linearGradient></defs><path d="M0 0H256L244 24 256 48H0Z" fill="url(#face)"/><path d="M0 1H254" stroke="#88683c"/><path d="M0 47H254" stroke="#100e0b"/><path d="M2 1V47" stroke="${active?'#d0ac65':'#9f7e45'}" stroke-width="3"/>`,512,128);
 const icons=fs.readFileSync(path.join(root,'design/bookmark-icons.svg'),'utf8');
 for(const match of icons.matchAll(/<symbol id="([^"]+)"[^>]*>([\s\S]*?)<\/symbol>/g))await asset('icon-'+match[1]+'-v2',24,24,`<g fill="none" stroke="#d4b777" stroke-width="1.55" stroke-linecap="round" stroke-linejoin="round">${match[2]}</g>`,64,64);
 console.log('Built bookmark window, binding, ribbons and chapter icon textures.');
})().catch(e=>{console.error(e);process.exit(1)});
