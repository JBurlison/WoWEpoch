// Deterministic export pixels only; never authors or changes the source artwork.
const fs=require('node:fs'),path=require('node:path');
const sharp=require(require.resolve('sharp',{paths:[process.cwd(),'C:/Users/JBurl/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules']}));
(async()=>{
 const [source,destination,w,h]=process.argv.slice(2),width=Number(w),height=Number(h);
 if(!source||!destination||!Number.isInteger(width)||!Number.isInteger(height)||width<1||height<1||width>4096||height>4096)throw Error('Invalid export dimensions');
 const {data,info}=await sharp(source).resize(width,height,{fit:'contain',background:'#e5c18a'}).removeAlpha().toColourspace('srgb').raw().toBuffer({resolveWithObject:true});
 if(info.channels!==3)throw Error('Expected opaque RGB pixels');
 fs.mkdirSync(path.dirname(destination),{recursive:true});
 await sharp(data,{raw:{width,height,channels:3}}).png().toFile(destination);
 console.log(JSON.stringify({sharp:sharp.versions.sharp,width,height}));
})().catch(e=>{console.error(e);process.exit(1)});
