// Reproducible, text-free UI graphics translated from design/scrapbook.css.
const fs=require('node:fs'),path=require('node:path');
const sharp=require(require.resolve('sharp',{paths:[process.cwd(),'C:/Users/JBurl/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules']}));
const root=path.resolve(__dirname,'..'),out=path.join(root,'MyEpoch/Media/Book'),source=path.join(root,'design/native-skin');
fs.mkdirSync(out,{recursive:true});fs.mkdirSync(source,{recursive:true});
const gradient=(id,a,b)=>`<linearGradient id="${id}" x2="0" y2="1"><stop stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient>`;
let built=0;
async function asset(name,w,h,body,tw=w,th=h){
 const markup=`<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}">${body}</svg>`;
 fs.writeFileSync(path.join(source,name+'.svg'),markup);
 // The texture is stretched back to the logical rectangle by WoW; never crop it.
 const data=await sharp(Buffer.from(markup)).resize(tw,th,{fit:'fill'}).ensureAlpha().raw().toBuffer();
 const header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(tw,12);header.writeUInt16LE(th,14);header[16]=32;header[17]=8;
 const pixels=Buffer.alloc(data.length);for(let y=0;y<th;y++)for(let x=0;x<tw;x++){
  const a=(y*tw+x)*4,b=((th-1-y)*tw+x)*4;pixels[b]=data[a+2];pixels[b+1]=data[a+1];pixels[b+2]=data[a];pixels[b+3]=data[a+3];
 }
 fs.writeFileSync(path.join(out,name+'.tga'),Buffer.concat([header,pixels]));
 await sharp(data,{raw:{width:tw,height:th,channels:4}}).png().toFile(path.join(source,name+'.png'));
 built++;
}
(async()=>{
 const corners=[[12,144],[1722,144],[12,908],[1722,908]].map(([x,y])=>`<g transform="translate(${x} ${y})"><rect width="26" height="26" rx="4" fill="url(#brass)" stroke="#bc9153" stroke-width="2"/><rect x="3" y="3" width="20" height="20" rx="2" fill="none" stroke="#5c4026"/><path d="M13 8l4 5-4 5-4-5z" fill="#dfbc77"/></g>`).join('');
 await asset('book-v1',1760,940,`<defs>
 ${gradient('night','#30322c','#151a19')}${gradient('leather','#65462d','#3e2a1e')}${gradient('brass','#a88047','#513820')}${gradient('tools','#d9c08d','#cdb17a')}
 <linearGradient id="paper"><stop stop-color="#dec58e"/><stop offset=".23" stop-color="#efddb4"/><stop offset=".67" stop-color="#efdfb9"/><stop offset="1" stop-color="#ddc28b"/></linearGradient>
 <linearGradient id="fold"><stop stop-color="#6c4b2d" stop-opacity="0"/><stop offset=".46" stop-color="#5a3919" stop-opacity=".3"/><stop offset=".52" stop-color="#f8e5b8" stop-opacity=".6"/><stop offset="1" stop-color="#b38b44" stop-opacity="0"/></linearGradient>
 <radialGradient id="stain"><stop stop-color="#a57b37" stop-opacity=".15"/><stop offset="1" stop-color="#a57b37" stop-opacity="0"/></radialGradient>
 <pattern id="grain" width="7" height="8" patternUnits="userSpaceOnUse"><path d="M0 1L7 0M0 5L7 6" stroke="#937b45" stroke-opacity=".07" stroke-width=".7"/></pattern>
 <pattern id="binding" width="7" height="6" patternUnits="userSpaceOnUse"><path d="M1 0L0 6M5 0L4 6" stroke="#d4a969" stroke-opacity=".13" stroke-width="1"/></pattern></defs>
 <rect width="1760" height="940" rx="7" fill="url(#night)"/>
 <rect x="12" y="144" width="1736" height="790" rx="7" fill="url(#leather)" stroke="#856341" stroke-width="2"/>
 <rect x="17" y="149" width="1726" height="780" rx="4" fill="url(#binding)" stroke="#271b13" stroke-width="3"/>
 <rect x="20" y="152" width="1720" height="774" rx="3" fill="none" stroke="#8b653e" stroke-width="2"/>
 <rect x="25" y="157" width="1710" height="764" fill="none" stroke="#b38950" stroke-opacity=".65" stroke-dasharray="2 3"/>
 <rect x="32" y="164" width="1696" height="47" fill="url(#tools)" stroke="#ad8957"/><path d="M33 165h1694" stroke="#f5dfb4"/>
 <rect x="32" y="211" width="848" height="683" fill="url(#paper)"/><rect x="880" y="211" width="848" height="683" fill="url(#paper)"/>
 <ellipse cx="160" cy="440" rx="400" ry="330" fill="url(#stain)"/><ellipse cx="1560" cy="858" rx="420" ry="190" fill="url(#stain)"/>
 <rect x="32" y="211" width="1696" height="683" fill="url(#grain)"/><path d="M33 213V893H1727V213" fill="none" stroke="#9a793f" stroke-opacity=".3" stroke-width="3"/>
 <rect x="864" y="211" width="32" height="683" fill="url(#fold)"/>
 <rect x="32" y="894" width="1696" height="25" fill="#d9bf8d"/><path d="M32 894h1696" stroke="#b39662"/>${corners}`,2048,1024);
 await asset('button-v1',256,64,`<defs>${gradient('face','#f2dfb7','#ddc18e')}</defs><rect x="1" y="1" width="254" height="62" rx="4" fill="url(#face)" stroke="#9d7a49" stroke-width="2"/><path d="M5 4h246" stroke="#fff6d7"/>`);
 for(const active of [false,true])await asset(active?'tab-active-v1':'tab-v1',256,64,`<defs>${gradient('face',active?'#8c3529':'#51422e',active?'#61251f':'#33291f')}</defs><path d="M1 64V${active?6:14}q0-5 5-5h244q5 0 5 5V64" fill="url(#face)" stroke="${active?'#b1804a':'#896942'}" stroke-width="2"/>${active?'<path d="M128 6l4 5-4 5-4-5z" fill="#d4aa63"/>':''}`);
 await asset('crest-v1',128,128,`<defs>${gradient('face','#733e2b','#3e241b')}</defs><path d="M15 3h98v96l-49 27-49-27z" fill="url(#face)" stroke="#967b4c" stroke-width="3"/>`);
 await asset('ribbon-v1',512,64,'<path d="M0 3H512L492 32l20 29H0l20-29z" fill="#7c3327"/><path d="M8 5h496" stroke="#b36a43"/>');
 for(const active of [false,true])await asset(active?'seal-active-v1':'seal-v1',64,64,`<circle cx="32" cy="32" r="29" fill="${active?'#7e3627':'#edd6a6'}" stroke="#ad854d" stroke-width="2"/><path d="M32 16q2 13 16 16-14 3-16 16-3-14-16-16 13-3 16-16z" fill="${active?'#f2d69e':'#8b3e28'}"/>`);
 await asset('photo-v1',1024,512,'<path d="M5 12h1014v496H5z" fill="#5d4528" opacity=".2"/><path d="M0 4h1018v496H0z" fill="#f0dfba"/><path d="M13 16h992v460H13z" fill="#bcaa79" stroke="#8c7952" stroke-width="2"/><path d="M25 8l60-8 5 22-60 9zM936 0l64 17-7 22-62-20z" fill="#c8ae76" opacity=".65"/>');
 for(const selected of [false,true])await asset(selected?'calendar-day-selected-v1':'calendar-day-v1',256,128,`<rect x="2" y="2" width="252" height="124" rx="3" fill="${selected?'#f3dfb4':'#e8d3a9'}" stroke="${selected?'#843c2b':'#c5aa78'}" stroke-width="${selected?5:2}"/>`);
 await asset('diary-v1',1024,128,'<rect width="1024" height="128" fill="#f2e2bf"/><rect width="4" height="128" fill="#a98245"/>');
 await asset('filter-active-v1',256,64,'<rect x="1" y="1" width="254" height="62" rx="3" fill="#705536" stroke="#9d7a49" stroke-width="2"/>');
 await asset('invoice-v1',1024,256,`<defs>${gradient('paper','#f5e8c9','#e4cca0')}<radialGradient id="water"><stop stop-color="#936332" stop-opacity=".13"/><stop offset="1" stop-color="#936332" stop-opacity="0"/></radialGradient><pattern id="fibre" width="9" height="7" patternUnits="userSpaceOnUse"><path d="M0 2l9 1M2 6l5-1" stroke="#80623d" stroke-opacity=".06"/></pattern></defs><path d="M3 8L70 5l77 3 85-5 120 4 113-4 103 5 118-4 102 4 100-3 130 4-3 241-130-3-106 4-109-4-118 4-118-3-110 4-112-4-107 3-110-4z" fill="url(#paper)" stroke="#b28d56" stroke-width="2"/><path d="M18 19H1006V236H18z" fill="url(#fibre)" stroke="#9b7745" stroke-opacity=".5"/><path d="M25 27H999M25 229H999" stroke="#9b7745" stroke-opacity=".6"/><ellipse cx="910" cy="10" rx="230" ry="90" fill="url(#water)"/><ellipse cx="90" cy="240" rx="250" ry="100" fill="url(#water)"/><path d="M32 35h24m-12-12v24M968 211h24m-12-12v24" stroke="#967349" stroke-opacity=".7"/>`);
 await asset('ledger-line-v1',1024,128,`<defs>${gradient('paper','#f5e8cb','#ead5ad')}</defs><rect x="2" y="2" width="1020" height="124" rx="3" fill="url(#paper)" stroke="#b1976b" stroke-width="2"/><rect x="7" y="7" width="1010" height="114" rx="2" fill="none" stroke="#d8bc88"/><path d="M92 12v104" stroke="#b99a62" stroke-opacity=".6"/>`);
 for(const [name,light,dark]of [['gold','#ffe59a','#b07819'],['silver','#f3f1e5','#7c8989'],['copper','#efbd91','#9e4e2d']])await asset('coin-'+name+'-v1',32,32,`<defs>${gradient('metal',light,dark)}</defs><circle cx="16" cy="17" r="14" fill="#3b2a17" opacity=".3"/><circle cx="16" cy="15" r="13" fill="url(#metal)" stroke="${dark}" stroke-width="2"/><circle cx="16" cy="15" r="9" fill="none" stroke="${light}" stroke-opacity=".8"/><path d="M16 8l3 5 5 2-5 2-3 5-3-5-5-2 5-2z" fill="${dark}" opacity=".7"/>`);
 await asset('invoice-seal-v1',128,128,`<defs><radialGradient id="wax" cx=".35" cy=".25" r=".75"><stop stop-color="#b75a40"/><stop offset=".55" stop-color="#8a332b"/><stop offset="1" stop-color="#4e211f"/></radialGradient><linearGradient id="pressed" x2=".8" y2="1"><stop stop-color="#55221f"/><stop offset="1" stop-color="#ac4d35"/></linearGradient></defs><path d="M64 8l12 4 14-1 8 10 13 5 2 14 8 10-4 14 3 13-10 10-3 14-14 4-9 10-14-3-13 4-11-8-14-1-6-13-11-7 1-14-6-12 7-12 1-14 13-6 8-11 14 1z" fill="#342016" opacity=".25" transform="translate(2 5)"/><path d="M64 8l12 4 14-1 8 10 13 5 2 14 8 10-4 14 3 13-10 10-3 14-14 4-9 10-14-3-13 4-11-8-14-1-6-13-11-7 1-14-6-12 7-12 1-14 13-6 8-11 14 1z" fill="url(#wax)" stroke="#642a20" stroke-width="2"/><circle cx="64" cy="61" r="36" fill="url(#pressed)" stroke="#b56548" stroke-width="2"/><circle cx="64" cy="61" r="30" fill="none" stroke="#47221d" stroke-opacity=".5"/><path d="M63 35q4 21 25 26-21 4-25 26-4-22-25-26 21-5 25-26z" fill="#e0b46d" stroke="#5c2c1e" stroke-width="2"/><path d="M27 38q7-13 21-17M93 93l9-10" fill="none" stroke="#d98058" stroke-opacity=".65" stroke-width="3"/>`);
 console.log('Built '+built+' native scrapbook skin textures from editable SVG sources.');
})().catch(e=>{console.error(e);process.exit(1)});
