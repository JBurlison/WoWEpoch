// Deterministic texture-format export only. Artwork is authored by image_gen.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const sharp=require(require.resolve('sharp',{paths:[process.cwd(),'C:/Users/JBurl/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules']}));
const root=path.resolve(__dirname,'..');
async function exportTexture(source,name,width,height){
 const {data,info}=await sharp(path.join(root,source)).resize(width,height,{fit:'contain',background:'#e5c18a'}).removeAlpha().toColourspace('srgb').raw().toBuffer({resolveWithObject:true});
 if(info.channels!==3)throw Error('Expected RGB export');
 const header=Buffer.alloc(18);header[2]=2;header.writeUInt16LE(width,12);header.writeUInt16LE(height,14);header[16]=24;
 const pixels=Buffer.alloc(data.length);
 for(let y=0;y<height;y++)for(let x=0;x<width;x++){
  const a=(y*width+x)*3,b=((height-1-y)*width+x)*3;
  pixels[b]=data[a+2];pixels[b+1]=data[a+1];pixels[b+2]=data[a];
 }
 const relative=`Media/Illustrations/${name}.tga`,destination=path.join(root,'MyEpoch',relative);
 fs.mkdirSync(path.dirname(destination),{recursive:true});const file=Buffer.concat([header,pixels]);fs.writeFileSync(destination,file);
 // A PNG of the same resized pixels supports host-side visual review.
 await sharp(data,{raw:{width,height,channels:3}}).png().toFile(path.join(root,`design/illustrations/generated/${name}-export.png`));
 return {path:relative,width,height,bytes:file.length,sha256:crypto.createHash('sha256').update(file).digest('hex')};
}
(async()=>{
 const registry=JSON.parse(fs.readFileSync(path.join(root,'design/generated-art.json'),'utf8'));
 const requested=process.argv.slice(2);
 if(new Set(registry.map(a=>a.id)).size!==registry.length)throw Error('Duplicate generated-art ID');
 for(const id of requested)if(!registry.some(a=>a.id===id))throw Error('Unknown generated artwork: '+id);
 const selected=requested.length?registry.filter(a=>requested.includes(a.id)):registry;
 // Preflight every input before changing any existing exports.
 for(const asset of selected){
  if(!/^[a-z0-9-]+$/.test(asset.id))throw Error('Invalid asset ID');
  const relative=path.relative(path.join(root,'design/illustrations/generated'),path.resolve(root,'design',asset.src));
  if(relative.startsWith('..')||path.isAbsolute(relative)||!relative.endsWith('.png'))throw Error('Source must stay within generated illustrations');
  if(!fs.existsSync(path.resolve(root,'design',asset.src)))throw Error('Missing generated artwork: '+asset.id);
 }
 const manifestPath=path.join(root,'design/art-exports.json');const manifest=fs.existsSync(manifestPath)?JSON.parse(fs.readFileSync(manifestPath,'utf8')):{};
 for(const asset of selected)if(manifest[asset.id]?.profile==='blp2-bc1-1024')throw Error('Preserve the selected BLP profile; use tools/export_art_blp.py for '+asset.id);
 for(const asset of selected){
  const id=asset.id,source='design/'+asset.src;
  const image=await exportTexture(source,id,512,256),thumbnail=await exportTexture(source,id+'-thumb',256,128);
  manifest[id]={source,sourceSHA256:crypto.createHash('sha256').update(fs.readFileSync(path.join(root,source))).digest('hex'),image,thumbnail,stage:'Development texture; client review pending'};
 }
 fs.writeFileSync(manifestPath,JSON.stringify(manifest,null,2)+'\n');console.log('Exported '+selected.length+' development illustrations and thumbnails.');
})().catch(e=>{console.error(e);process.exit(1)});
