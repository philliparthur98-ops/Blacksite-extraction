(() => {
'use strict';
if (window.__BLACKSITE_POLISH__) return;
window.__BLACKSITE_POLISH__ = true;
const $ = (s, p=document) => p.querySelector(s);
const $$ = (s, p=document) => Array.from(p.querySelectorAll(s));
const PROFILE_KEY = 'BLACKSITE_POLISH_PROFILE_V2';
const CATALOG = {
  m4:{name:'M4A1 SOPMOD',type:'PRIMARY WEAPON',kind:'weapon',rarity:'rare',value:1850,condition:92,stat1:'5.56×45',stat2:'30+1',desc:'Short-stroke tactical carbine configured for Harbor Yard. Rail optic, weapon light and 30-round magazine.'},
  g17:{name:'G17 Duty',type:'SIDEARM',kind:'pistol',rarity:'common',value:540,condition:88,stat1:'9×19',stat2:'17+1',desc:'Compact polymer service pistol carried as an emergency secondary.'},
  carrier:{name:'Aegis Plate Carrier',type:'ARMOR',kind:'armor',rarity:'uncommon',value:2280,condition:76,stat1:'CLASS IV',stat2:'60 ARM',desc:'Low-profile carrier with ceramic front and rear plates. Balanced protection and mobility.'},
  ammo556:{name:'M855A1 5.56',type:'AMMUNITION',kind:'ammo',rarity:'uncommon',value:420,condition:100,stat1:'120 RDS',stat2:'AP',desc:'Enhanced penetration 5.56×45 ammunition packed in four magazines.'},
  ifak:{name:'IFAK Trauma Kit',type:'MEDICAL',kind:'med',rarity:'uncommon',value:310,condition:84,stat1:'4 USE',stat2:'FIELD',desc:'Compact individual first aid kit with pressure dressing, gauze and hemostatic supplies.'},
  gpu:{name:'Industrial GPU',type:'VALUABLE',kind:'gpu',rarity:'legendary',value:2450,condition:71,stat1:'TECH',stat2:'1.8 KG',desc:'High-value compute module recovered from industrial control equipment.'},
  ssd:{name:'Encrypted SSD',type:'INTELLIGENCE',kind:'ssd',rarity:'rare',value:980,condition:94,stat1:'DATA',stat2:'0.1 KG',desc:'Rugged solid-state drive. Contents are encrypted and valuable to brokers.'},
  radio:{name:'Military Radio',type:'ELECTRONICS',kind:'radio',rarity:'rare',value:1320,condition:68,stat1:'VHF/UHF',stat2:'1.2 KG',desc:'Field transceiver with hardened case and frequency-hopping module.'},
  gold:{name:'Gold Chain',type:'VALUABLE',kind:'gold',rarity:'epic',value:1620,condition:100,stat1:'14K',stat2:'0.2 KG',desc:'Unmarked heavy gold chain. Easy to fence and difficult to trace.'},
  intel:{name:'Contractor Intel',type:'INTELLIGENCE',kind:'intel',rarity:'epic',value:1980,condition:100,stat1:'CLASSIFIED',stat2:'PAPER',desc:'Stamped contractor folder containing route schedules and access codes.'},
  plate:{name:'Ceramic Plate',type:'ARMOR PART',kind:'plate',rarity:'uncommon',value:860,condition:81,stat1:'CLASS IV',stat2:'2.6 KG',desc:'Standalone ceramic rifle plate. Chipped edges, but still serviceable.'},
  tools:{name:'Precision Tool Set',type:'BARTER',kind:'tool',rarity:'common',value:460,condition:79,stat1:'18 PC',stat2:'2.1 KG',desc:'Compact gunsmith and electronics tool roll with hardened bits.'},
  salewa:{name:'Field Med Bag',type:'MEDICAL',kind:'med',rarity:'rare',value:690,condition:91,stat1:'8 USE',stat2:'FIELD',desc:'Expanded medical pouch with splints, bandages and trauma supplies.'}
};
const DEFAULT_STASH = ['m4','g17','carrier','ammo556','ifak','gpu','ssd','radio','plate','tools','salewa'];
function loadProfile(){
  try { const p=JSON.parse(localStorage.getItem(PROFILE_KEY)||'null'); if(p&&Array.isArray(p.stash)) return p; } catch(_){}
  return {stash:DEFAULT_STASH.slice(),cash:14820,extractions:0,deaths:0,lootValue:0};
}
let profile=loadProfile(), raidLoot=[], raidSettled=false, filter='ALL';
const save=()=>{try{localStorage.setItem(PROFILE_KEY,JSON.stringify(profile))}catch(_){}};
const rarityColor=r=>({common:'#91a7b0',uncommon:'#78ce72',rare:'#58bfe9',epic:'#b986ff',legendary:'#f1b85b'}[r]||'#91a7b0');
const money=n=>'$ '+Math.round(n).toLocaleString('en-US');
function stashValue(){return profile.stash.reduce((n,id)=>n+(CATALOG[id.split(':')[0]]?.value||0),0)}
function addNav(){
  const top=$('.topbar>div:first-child'); if(!top||$('.terminal-nav'))return;
  const n=document.createElement('div');n.className='terminal-nav';n.innerHTML='<button class="active">DEPLOY</button><button>LOADOUT</button><button>STASH</button><button>CONTRACTS</button><button>HIDEOUT</button>';top.appendChild(n);
}
function addContracts(){
  const dep=$('.deployment'); const first=dep&&$('.section-label',dep); if(!dep||!first||$('.contract-strip',dep))return;
  const row=document.createElement('div');row.className='contract-strip';row.innerHTML='<div class="contract-chip accent"><small>ACTIVE CONTRACT</small><b>BLACK TIDE · Secure Drive</b></div><div class="contract-chip"><small>THREAT</small><b>5 CONTACTS</b></div><div class="contract-chip"><small>FORECAST</small><b>CLEAR · 17°C</b></div>';first.before(row);
}
function upgradeLoadout(){
  const slots=$$('.loadout-slot');
  const info=[['PRIMARY','M4A1 · M855A1','92%'],['SIDEARM','G17 · FMJ','88%'],['ARMOR','Aegis IV · 60','76%'],['RIG','Mk2 Chest Rig','100%'],['PACK','Assault 24L','93%'],['MEDICAL','IFAK · 4 USE','84%']];
  slots.forEach((s,i)=>{if(!info[i])return;const b=$('b',s),sm=$('small',s);if(b)b.textContent=info[i][0];if(sm)sm.textContent=info[i][1];if(!$('.condition',s)){const e=document.createElement('i');e.className='condition';e.textContent=info[i][2];s.appendChild(e)}});
  const grid=$('#loadout-grid'); if(grid&&!$('.kit-readiness')){const r=document.createElement('div');r.className='kit-readiness';r.innerHTML='<div class="kit-copy"><small>RAID READINESS</small><b>COMBAT EFFECTIVE · 18.4 KG</b></div><div class="kit-meter"><span></span></div>';grid.before(r)}
  if(grid&&!$('.gear-value-row')){const r=document.createElement('div');r.className='gear-value-row';r.innerHTML='<span>INSURED <b>PRIMARY · ARMOR</b></span><span>GEAR VALUE <b>$ 6,740</b></span>';grid.after(r)}
}
function operatorStats(){
  const panel=$('.operator-panel'); if(!panel||$('.operator-badges',panel))return;
  const b=document.createElement('div');b.className='operator-badges';b.innerHTML=`<div><b>${profile.extractions}</b><small>EXTRACTS</small></div><div><b>${profile.deaths}</b><small>LOSSES</small></div><div><b>${money(stashValue()).replace('$ ','$')}</b><small>STASH</small></div>`;panel.appendChild(b);
}
function itemCard(rawId){
  const id=rawId.split(':')[0],it=CATALOG[id]||CATALOG.tools;return `<button class="stash-item rarity-${it.rarity}" data-item="${id}"><span class="rarity-tick"></span><span class="item-condition">${it.condition}%</span><span class="loot-art ${it.kind}"></span><span class="item-title">${it.name}</span><span class="item-sub"><span>${it.type}</span><span class="item-price">${money(it.value)}</span></span></button>`;
}
function ensureInspector(){
  const stash=$('.stash'); if(!stash||$('.item-inspector',stash))return;
  const i=document.createElement('div');i.className='item-inspector';i.innerHTML='<div class="inspect-top"><div><div class="inspect-type"></div><h4></h4></div><button class="inspect-close" aria-label="Close">×</button></div><p class="inspect-desc"></p><div class="inspect-stats"><div><small>SPEC</small><b data-stat="1"></b></div><div><small>DETAIL</small><b data-stat="2"></b></div><div><small>CONDITION</small><b data-stat="3"></b></div></div><div class="inspect-footer"><span class="inspect-value"></span><span class="inspect-badge"></span></div>';stash.appendChild(i);$('.inspect-close',i).addEventListener('click',e=>{e.stopPropagation();i.classList.remove('open')});
}
function inspectItem(id){
  const it=CATALOG[id]; const pane=$('.item-inspector'); if(!it||!pane)return;
  pane.style.setProperty('--inspect-color',rarityColor(it.rarity));$('.inspect-type',pane).textContent=it.type;$('.inspect-top h4',pane).textContent=it.name;$('.inspect-desc',pane).textContent=it.desc;$('[data-stat="1"]',pane).textContent=it.stat1;$('[data-stat="2"]',pane).textContent=it.stat2;$('[data-stat="3"]',pane).textContent=it.condition+'%';$('.inspect-value',pane).textContent=money(it.value);$('.inspect-badge',pane).textContent=it.rarity.toUpperCase();pane.classList.add('open');
}
function rebuildStash(){
  const stash=$('.stash'),grid=stash&&$('.stash-grid',stash),head=stash&&$('.stash-head>span',stash);if(!stash||!grid)return;
  let ids=profile.stash.slice();if(filter!=='ALL')ids=ids.filter(raw=>{const i=CATALOG[raw.split(':')[0]];return i&&(filter==='GEAR'?['weapon','pistol','armor'].includes(i.kind):filter==='MEDS'?i.kind==='med':filter==='VALUABLES'?['gpu','ssd','radio','gold','intel'].includes(i.kind):true)});
  grid.innerHTML=ids.map(itemCard).join('');if(head)head.textContent=`${profile.stash.length} / 60 · ${money(stashValue())}`;
  $$('.stash-item',grid).forEach(b=>b.addEventListener('click',()=>inspectItem(b.dataset.item)));
  const cash=$('.wallet span:nth-child(2)');if(cash)cash.textContent=money(profile.cash);
}
function stashToolbar(){
  const stash=$('.stash'),head=stash&&$('.stash-head',stash);if(!stash||!head||$('.stash-toolbar',stash))return;
  const bar=document.createElement('div');bar.className='stash-toolbar';bar.innerHTML='<button class="active" data-f="ALL">ALL</button><button data-f="GEAR">GEAR</button><button data-f="MEDS">MEDS</button><button data-f="VALUABLES">VALUABLES</button><button class="stash-value" disabled>EXTRACTED LOOT</button>';head.after(bar);
  $$('button[data-f]',bar).forEach(b=>b.addEventListener('click',()=>{filter=b.dataset.f;$$('button[data-f]',bar).forEach(x=>x.classList.toggle('active',x===b));rebuildStash()}));
}
function decorateMenu(){addNav();addContracts();upgradeLoadout();stashToolbar();ensureInspector();rebuildStash();operatorStats();}

let app=null,player=null,lootEntries=[];
function pcMat(name,rgb,metal=.05,gloss=.35,emissive=null){const m=new pc.StandardMaterial();m.name=name;m.diffuse=new pc.Color(...rgb);m.metalness=metal;m.gloss=gloss;m.useMetalness=true;if(emissive){m.emissive=new pc.Color(...emissive);m.emissiveIntensity=1.7}m.update();return m}
function addPart(parent,name,type,pos,scale,material,rot){const e=new pc.Entity(name);e.addComponent('render',{type,castShadows:true,receiveShadows:true});e.render.material=material;e.setLocalPosition(...pos);e.setLocalScale(...scale);if(rot)e.setLocalEulerAngles(...rot);parent.addChild(e);return e}
function enhanceWeapon(M){
  const wr=app.root.findByName('WeaponRoot');if(!wr||wr.findByName('PolishAttachments'))return;
  const r=new pc.Entity('PolishAttachments');wr.addChild(r);
  addPart(r,'LPVO base','box',[0,.145,-.24],[.16,.035,.28],M.gun);
  addPart(r,'optic tube','cylinder',[0,.205,-.26],[.07,.28,.07],M.gun,[90,0,0]);
  addPart(r,'optic glass','cylinder',[0,.205,-.41],[.061,.012,.061],M.lens,[90,0,0]);
  addPart(r,'weapon light','cylinder',[-.13,-.01,-.64],[.042,.31,.042],M.gun,[90,0,0]);
  addPart(r,'light lens','cylinder',[-.13,-.01,-.805],[.039,.015,.039],M.lens,[90,0,0]);
  addPart(r,'foregrip','box',[.02,-.16,-.55],[.075,.26,.085],M.poly,[7,0,0]);
  addPart(r,'suppressor','cylinder',[0,.018,-1.22],[.061,.36,.061],M.gun,[90,0,0]);
  addPart(r,'stock cheek','box',[0,.055,.36],[.21,.075,.31],M.poly);
}
function enhanceEnemies(M){
  const palettes=[[M.olive,M.dark],[M.tan,M.dark],[M.dark,M.olive],[M.rust,M.dark],[M.bluegrey,M.dark]];
  for(let i=1;i<=5;i++){
    const root=app.root.findByName('Raider '+i);if(!root||root.findByName('PolishKit'))continue;const kit=new pc.Entity('PolishKit');root.addChild(kit);const [cloth,hard]=palettes[i-1];
    addPart(kit,'helmet','sphere',[0,2.19,0],[.50,.31,.49],hard);
    addPart(kit,'helmet brim','box',[0,2.13,-.27],[.42,.055,.18],hard);
    addPart(kit,'goggles','box',[0,2.09,-.405],[.31,.075,.045],M.lens);
    addPart(kit,'face wrap','box',[0,1.94,-.36],[.29,.16,.08],cloth);
    addPart(kit,'chest plate','box',[0,1.48,-.31],[.58,.58,.13],hard);
    for(const x of[-.22,0,.22])addPart(kit,'mag pouch','box',[x,1.30,-.405],[.16,.25,.11],cloth);
    addPart(kit,'shoulder L','sphere',[-.43,1.57,-.02],[.18,.15,.18],hard);addPart(kit,'shoulder R','sphere',[.43,1.57,-.02],[.18,.15,.18],hard);
    addPart(kit,'knee L','box',[-.17,.52,-.17],[.19,.16,.08],hard,[8,0,0]);addPart(kit,'knee R','box',[.17,.52,-.17],[.19,.16,.08],hard,[8,0,0]);
    addPart(kit,'pack','box',[0,1.42,.31],[.48,.58,.22],cloth);
    const gun=new pc.Entity('Enemy rifle');kit.addChild(gun);gun.setLocalPosition(.29,1.38,-.52);gun.setLocalEulerAngles(2,0,-7);addPart(gun,'receiver','box',[0,0,0],[.55,.09,.10],M.gun);addPart(gun,'barrel','cylinder',[.41,0,0],[.025,.45,.025],M.gun,[0,0,90]);addPart(gun,'mag','box',[-.05,-.11,.01],[.11,.24,.08],M.gun,[0,0,7]);
    if(i===2||i===4){addPart(kit,'side pouch', 'box',[.53,1.15,.08],[.20,.34,.24],cloth);addPart(kit,'neck guard','box',[0,1.88,.08],[.38,.16,.18],hard)}
  }
}
function makeLootVisual(root,id,M){
  const it=CATALOG[id];const color=rarityColor(it.rarity);const glow=pcMat('loot glow '+id,[.10,.45,.52],.1,.8,[.05,.35,.5]);
  if(it.kind==='gpu'){addPart(root,'gpu body','box',[0,.16,0],[.56,.32,.08],M.gun);for(const x of[-.17,.17])addPart(root,'fan','cylinder',[x,.17,-.06],[.095,.025,.095],M.steel,[90,0,0]);}
  else if(it.kind==='radio'){addPart(root,'radio','box',[0,.20,0],[.34,.40,.20],M.olive);addPart(root,'antenna','cylinder',[.12,.52,0],[.018,.42,.018],M.gun);addPart(root,'dial','cylinder',[-.08,.28,-.11],[.045,.025,.045],M.steel,[90,0,0]);}
  else if(it.kind==='med'){addPart(root,'med bag','box',[0,.18,0],[.44,.30,.26],M.med);addPart(root,'crossH','box',[0,.18,-.14],[.20,.055,.02],M.white);addPart(root,'crossV','box',[0,.18,-.14],[.055,.20,.02],M.white);}
  else if(it.kind==='plate'){addPart(root,'plate','box',[0,.23,0],[.38,.46,.09],M.steel,[0,0,0]);}
  else if(it.kind==='intel'){addPart(root,'folder','box',[0,.05,0],[.52,.05,.38],M.tan,[0,18,0]);addPart(root,'tab','box',[-.14,.08,-.12],[.18,.025,.08],M.tan);}
  else if(it.kind==='ssd'){addPart(root,'ssd','box',[0,.10,0],[.42,.18,.08],M.steel);addPart(root,'edge','box',[0,.10,-.05],[.31,.10,.018],M.gun);}
  else if(it.kind==='gold'){for(let a=0;a<Math.PI*2;a+=Math.PI/7)addPart(root,'chain','sphere',[Math.cos(a)*.20,.16,Math.sin(a)*.20],[.055,.055,.055],M.gold);}
  else {addPart(root,'loot case','box',[0,.17,0],[.42,.30,.28],M.tan);}
  const beacon=addPart(root,'loot beacon','sphere',[0,.52,0],[.055,.055,.055],glow);beacon.render.castShadows=false;
  const base=addPart(root,'loot marker','cylinder',[0,.012,0],[.28,.018,.28],glow);base.render.castShadows=false;
  root.__lootColor=color;
}
function spawnLoot(M){
  if(app.root.findByName('PolishLootRoot'))return;const group=new pc.Entity('PolishLootRoot');app.root.addChild(group);
  const defs=[['ssd',-14,10],['gold',15,13],['radio',22,6],['plate',7,-13],['salewa',-5,-10],['intel',3,18],['gpu',20,-13]];
  defs.forEach(([id,x,z],idx)=>{const root=new pc.Entity('Loot '+id);root.setPosition(x,.05,z);group.addChild(root);makeLootVisual(root,id,M);lootEntries.push({id,root,baseY:.05,phase:idx*.8,collected:false})});
}
function hudLootUI(){
  const hud=$('#hud');if(!hud)return;if(!$('#raid-loot-strip')){const e=document.createElement('div');e.id='raid-loot-strip';e.className='raid-loot-strip';e.innerHTML='<span>FIELD LOOT</span><b id="raid-loot-value">0 ITEMS · $0</b>';hud.appendChild(e)}if(!$('#loot-ping')){const e=document.createElement('div');e.id='loot-ping';e.className='loot-ping hidden';hud.appendChild(e)}
}
function updateLootHud(){const e=$('#raid-loot-value');if(e)e.textContent=`${raidLoot.length} ITEM${raidLoot.length===1?'':'S'} · ${money(raidLoot.reduce((n,id)=>n+(CATALOG[id]?.value||0),0))}`}
function raidActive(){return !$('#hud')?.classList.contains('hidden')&&!$('#result')?.classList.contains('screen-on')}
function nearestLoot(){if(!raidActive()||!player)return null;const p=player.getPosition();let best=null,bd=1.75;for(const l of lootEntries){if(l.collected||!l.root.enabled)continue;const q=l.root.getPosition(),d=Math.hypot(p.x-q.x,p.z-q.z);if(d<bd){bd=d;best=l}}return best}
let nearLoot=null;
function pickupLoot(){if(!nearLoot)return false;const l=nearLoot,it=CATALOG[l.id];l.collected=true;l.root.enabled=false;raidLoot.push(l.id);updateLootHud();const toast=$('#toast');if(toast){toast.textContent=`LOOTED · ${it.name} · ${money(it.value)}`;toast.classList.remove('on');void toast.offsetWidth;toast.classList.add('on')}nearLoot=null;return true}
function resetWorldLoot(){raidLoot=[];raidSettled=false;lootEntries.forEach(l=>{l.collected=false;l.root.enabled=true});updateLootHud()}
function settleRaid(){if(raidSettled)return;const res=$('#result');if(!res?.classList.contains('screen-on'))return;raidSettled=true;const ok=($('#result-title')?.textContent||'').includes('SUCCESS');const card=$('.brief-card',res);if(ok){profile.extractions++;profile.cash+=Math.round(raidLoot.reduce((n,id)=>n+(CATALOG[id]?.value||0),0)*.15);profile.lootValue+=raidLoot.reduce((n,id)=>n+(CATALOG[id]?.value||0),0);raidLoot.forEach((id,i)=>profile.stash.push(id+':'+Date.now()+':'+i));save()}else profile.deaths++;
  save();if(card){$('.result-loot',card)?.remove();const p=document.createElement('div');p.className='result-loot';const val=raidLoot.reduce((n,id)=>n+(CATALOG[id]?.value||0),0);p.innerHTML=`<div class="result-loot-head"><span>${ok?'RECOVERED LOOT':'LOOT LOST'}</span><b>${money(val)}</b></div><div class="result-loot-items">${raidLoot.length?raidLoot.map(id=>`<span>${CATALOG[id].name}</span>`).join(''):'<span>NO OPTIONAL LOOT</span>'}</div>`;$('#return-btn',card)?.before(p)}
}
function enhanceWorld(){
  if(!window.pc)return;app=window.__BLACKSITE_APP__||(pc.Application.getApplication?pc.Application.getApplication():pc.app);if(!app)return;player=app.root.findByName('Player');if(!player)return;
  const M={gun:pcMat('polish gun',[.09,.11,.12],.72,.43),poly:pcMat('polish polymer',[.07,.085,.088],.05,.19),lens:pcMat('polish lens',[.055,.18,.22],.18,.92,[.02,.10,.14]),steel:pcMat('loot steel',[.32,.36,.36],.58,.42),olive:pcMat('loot olive',[.19,.27,.18],.05,.16),dark:pcMat('enemy dark',[.09,.11,.105],.06,.16),tan:pcMat('enemy tan',[.38,.30,.20],.04,.15),rust:pcMat('enemy rust',[.29,.16,.10],.10,.16),bluegrey:pcMat('enemy bluegrey',[.16,.22,.24],.05,.18),med:pcMat('med green',[.12,.29,.18],.02,.16),white:pcMat('med white',[.75,.80,.76],0,.22),gold:pcMat('gold',[.68,.46,.13],.75,.72)};
  enhanceWeapon(M);enhanceEnemies(M);spawnLoot(M);hudLootUI();updateLootHud();
  app.on('update',dt=>{if(!raidActive())return;const t=performance.now()*.001;lootEntries.forEach(l=>{if(l.collected||!l.root.enabled)return;l.root.setEulerAngles(0,(t*24+l.phase*18)%360,0);l.root.setPosition(l.root.getPosition().x,l.baseY+Math.sin(t*2+l.phase)*.035,l.root.getPosition().z)});nearLoot=nearestLoot();const ping=$('#loot-ping');if(nearLoot&&ping){const it=CATALOG[nearLoot.id];ping.style.setProperty('--loot-color',rarityColor(it.rarity));ping.innerHTML=`USE · ${it.name.toUpperCase()} <small>${money(it.value)}</small>`;ping.classList.remove('hidden');$('#use-btn')?.classList.add('active')}else{ping?.classList.add('hidden');if(!$('#interact-prompt')||$('#interact-prompt').classList.contains('hidden'))$('#use-btn')?.classList.remove('active')}});
  $('#use-btn')?.addEventListener('pointerdown',()=>pickupLoot());
  $('#begin-btn')?.addEventListener('click',()=>setTimeout(resetWorldLoot,0));
  const mo=new MutationObserver(()=>settleRaid());mo.observe($('#result'),{attributes:true,subtree:true,childList:true,characterData:true});
  $('#return-btn')?.addEventListener('click',()=>setTimeout(()=>{rebuildStash();const panel=$('.operator-badges');if(panel)panel.remove();operatorStats()},0));
}
function boot(){decorateMenu();const wait=()=>{if(window.__BLACKSITE_READY__&&window.pc){enhanceWorld();return}setTimeout(wait,120)};wait()}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot);else boot();
})();
