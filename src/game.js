(() => {
  'use strict';
  const $ = (s) => document.querySelector(s);
  const canvas = $('#application');
  const boot = $('#boot');
  const menu = $('#menu');
  const brief = $('#brief');
  const hud = $('#hud');
  const controls = $('#mobile-controls');
  const result = $('#result');
  const bootCopy = $('#boot-copy');

  const app = new pc.Application(canvas, {
    mouse: new pc.Mouse(canvas),
    touch: pc.platform.touch ? new pc.TouchDevice(canvas) : undefined,
    keyboard: new pc.Keyboard(window)
  });
  app.graphicsDevice.maxPixelRatio = Math.min(window.devicePixelRatio || 1, 1.5);
  app.setCanvasFillMode(pc.FILLMODE_FILL_WINDOW);
  app.setCanvasResolution(pc.RESOLUTION_AUTO);
  app.start();
  window.addEventListener('resize', () => app.resizeCanvas());
  document.addEventListener('contextmenu', (e) => e.preventDefault());

  app.scene.ambientLight = new pc.Color(0.22, 0.29, 0.34);
  app.scene.fog = pc.FOG_LINEAR;
  app.scene.fogColor = new pc.Color(0.31, 0.43, 0.5);
  app.scene.fogStart = 34;
  app.scene.fogEnd = 92;
  app.scene.gammaCorrection = pc.GAMMA_SRGB;
  app.scene.toneMapping = pc.TONEMAP_FILMIC;
  app.scene.exposure = 1.05;

  const state = { mode:'menu', hp:100, armor:60, stamina:100, ammo:30, reserve:90, reload:0, raidTime:900, shield:0, ads:false, firing:false, fireCooldown:0, yaw:0, pitch:0, moveX:0, moveY:0, objectiveSecured:false, kills:0, damageFlash:0 };

  const player = new pc.Entity('Player'); app.root.addChild(player); player.setPosition(0,0,24);
  const camera = new pc.Entity('Camera');
  camera.addComponent('camera',{clearColor:new pc.Color(.26,.4,.5),fov:72,nearClip:.05,farClip:140});
  player.addChild(camera); camera.setLocalPosition(0,1.63,0);

  const sun = new pc.Entity('Sun');
  sun.addComponent('light',{type:'directional',color:new pc.Color(1,.86,.7),intensity:2.25,castShadows:true,shadowBias:.23,normalOffsetBias:.04,shadowResolution:1024});
  sun.setEulerAngles(52,-36,0); app.root.addChild(sun);
  const fill = new pc.Entity('Fill');
  fill.addComponent('light',{type:'directional',color:new pc.Color(.28,.45,.62),intensity:.45,castShadows:false});
  fill.setEulerAngles(-35,130,0); app.root.addChild(fill);

  function material(name,c,metal=.0,gloss=.25){const m=new pc.StandardMaterial();m.name=name;m.diffuse=new pc.Color(c[0],c[1],c[2]);m.metalness=metal;m.gloss=gloss;m.useMetalness=true;m.update();return m;}
  const asphalt=material('asphalt',[.19,.22,.22],0,.15), concrete=material('concrete',[.42,.46,.45],0,.18), darkConcrete=material('darkConcrete',[.21,.24,.24],0,.17), steel=material('steel',[.3,.36,.39],.55,.42), redPaint=material('redPaint',[.55,.13,.08],.18,.34), bluePaint=material('bluePaint',[.08,.28,.37],.18,.32), greenPaint=material('greenPaint',[.18,.34,.22],.18,.3), yellowPaint=material('yellowPaint',[.58,.43,.12],.13,.28), water=material('water',[.05,.24,.32],.05,.78), enemyCloth=material('enemyCloth',[.2,.25,.2],0,.13), enemyVest=material('enemyVest',[.16,.19,.17],.05,.2), objectiveMat=material('objective',[.14,.55,.65],.3,.62);

  const solids=[];
  function box(name,p,s,mat,solid=true){const e=new pc.Entity(name);e.addComponent('render',{type:'box',castShadows:true,receiveShadows:true});e.render.material=mat;e.setPosition(p[0],p[1],p[2]);e.setLocalScale(s[0],s[1],s[2]);app.root.addChild(e);if(solid)solids.push({minX:p[0]-s[0]/2,maxX:p[0]+s[0]/2,minZ:p[2]-s[2]/2,maxZ:p[2]+s[2]/2,entity:e});return e;}
  function cylinder(name,p,s,mat){const e=new pc.Entity(name);e.addComponent('render',{type:'cylinder',castShadows:true,receiveShadows:true});e.render.material=mat;e.setPosition(...p);e.setLocalScale(...s);app.root.addChild(e);return e;}
  function loadTexture(url,target,tiling=1){app.assets.loadFromUrl(url,'texture',(err,asset)=>{if(err||!asset||!asset.resource)return;const t=asset.resource;t.addressU=pc.ADDRESS_REPEAT;t.addressV=pc.ADDRESS_REPEAT;t.minFilter=pc.FILTER_LINEAR_MIPMAP_LINEAR;target.diffuseMap=t;target.diffuseMapTiling=new pc.Vec2(tiling,tiling);target.update();});}
  loadTexture('https://raw.githubusercontent.com/petroulacl/fps-asset-kit/main/textures/Asphalt023S/Asphalt023S.png',asphalt,14);
  loadTexture('https://raw.githubusercontent.com/petroulacl/fps-asset-kit/main/textures/Concrete048/Concrete048.png',concrete,4);

  box('Ground',[0,-.3,0],[88,.6,108],asphalt,false); box('Water',[52,-.25,-8],[18,.45,78],water,false); box('Quay',[39,-.05,-8],[7,.9,78],concrete,true);
  box('Warehouse-A',[-30,4.5,-28],[24,9,22],darkConcrete,true); box('Warehouse-B',[17,3.7,-39],[31,7.4,14],concrete,true); box('Gatehouse',[-22,2.4,43],[13,4.8,9],concrete,true); box('Office',[20,2.6,35],[17,5.2,12],darkConcrete,true);
  const cs=[[-18,1.3,8,redPaint,0],[-9,1.3,8,bluePaint,0],[0,1.3,8,greenPaint,0],[18,1.3,4,yellowPaint,0],[18,3.9,4,bluePaint,0],[27,1.3,4,redPaint,0],[-8,1.3,-9,yellowPaint,0],[1,1.3,-9,bluePaint,0],[10,1.3,-9,redPaint,0],[-24,1.3,-9,greenPaint,90],[-24,1.3,-20,redPaint,90],[30,1.3,-16,greenPaint,90],[8,1.3,-24,yellowPaint,0],[17,1.3,-24,redPaint,0]];
  for(const [x,y,z,mat,yaw] of cs){const c=box('Container',[x,y,z],yaw===90?[2.6,2.6,8.2]:[8.2,2.6,2.6],mat,true);c.setEulerAngles(0,yaw,0);}
  for(let i=0;i<9;i++)cylinder('Barrel',[-31+(i%3)*1.3,.65,11+Math.floor(i/3)*1.25],[.72,1.3,.72],i%2?steel:yellowPaint);
  for(let i=0;i<7;i++)box('Jersey',[-14+i*4.4,.55,24],[3,1.1,.65],concrete,true);
  box('CraneLegA',[31,8,-47],[1.2,16,1.2],steel,true);box('CraneLegB',[40,8,-47],[1.2,16,1.2],steel,true);box('CraneTop',[35.5,16,-47],[18,1.1,1.2],yellowPaint,false);box('CraneArm',[26,17,-47],[22,.65,.65],yellowPaint,false);

  const drive=box('EncryptedDrive',[21,.45,-31],[.65,.22,.42],objectiveMat,false); const extractMarker=cylinder('ExtractBeacon',[-24,1.7,48],[.22,3.4,.22],objectiveMat); extractMarker.enabled=false;

  const enemies=[];
  function createEnemy(name,x,z){const root=new pc.Entity(name);root.setPosition(x,0,z);app.root.addChild(root);
    const torso=box(name+'-torso',[0,0,0],[.1,.1,.1],enemyCloth,false);torso.reparent(root);torso.setLocalPosition(0,1.55,0);torso.setLocalScale(.72,.82,.42);
    const head=new pc.Entity(name+'-head');head.addComponent('render',{type:'sphere',castShadows:true,receiveShadows:true});head.render.material=enemyVest;root.addChild(head);head.setLocalPosition(0,2.2,0);head.setLocalScale(.42,.46,.42);
    const gun=box(name+'-gun',[0,0,0],[.1,.1,.1],steel,false);gun.reparent(root);gun.setLocalPosition(.34,1.55,-.38);gun.setLocalScale(.75,.1,.12);
    const armL=box(name+'-armL',[0,0,0],[.1,.1,.1],enemyCloth,false);armL.reparent(root);armL.setLocalPosition(-.48,1.55,-.1);armL.setLocalScale(.18,.75,.18);
    const armR=box(name+'-armR',[0,0,0],[.1,.1,.1],enemyCloth,false);armR.reparent(root);armR.setLocalPosition(.48,1.55,-.1);armR.setLocalScale(.18,.75,.18);
    const legL=box(name+'-legL',[0,0,0],[.1,.1,.1],enemyVest,false);legL.reparent(root);legL.setLocalPosition(-.2,.5,0);legL.setLocalScale(.22,.95,.24);
    const legR=box(name+'-legR',[0,0,0],[.1,.1,.1],enemyVest,false);legR.reparent(root);legR.setLocalPosition(.2,.5,0);legR.setLocalScale(.22,.95,.24);
    enemies.push({root,torso,head,armL,armR,legL,legR,hp:100,dead:false,cooldown:Math.random()*1.2,phase:Math.random()*6.28});}
  [[-10,3],[12,-2],[26,-28],[-25,-16],[9,-34],[-28,29],[25,24],[3,29]].forEach((p,i)=>createEnemy('Raider-'+(i+1),p[0],p[1]));

  const weaponRoot=new pc.Entity('WeaponRoot');camera.addChild(weaponRoot);weaponRoot.setLocalPosition(.34,-.42,-.75);weaponRoot.setLocalEulerAngles(-3,180,0);
  function fallbackWeapon(){const g=new pc.Entity('FallbackRifle');weaponRoot.addChild(g);const r=box('vm-receiver',[0,0,0],[.1,.1,.1],steel,false);r.reparent(g);r.setLocalScale(.34,.12,.54);const h=box('vm-handguard',[0,0,0],[.1,.1,.1],darkConcrete,false);h.reparent(g);h.setLocalPosition(0,0,-.43);h.setLocalScale(.26,.11,.38);const b=box('vm-barrel',[0,0,0],[.1,.1,.1],steel,false);b.reparent(g);b.setLocalPosition(0,.01,-.82);b.setLocalScale(.055,.055,.58);const m=box('vm-mag',[0,0,0],[.1,.1,.1],darkConcrete,false);m.reparent(g);m.setLocalPosition(.03,-.18,-.05);m.setLocalEulerAngles(8,0,0);m.setLocalScale(.16,.38,.17);const st=box('vm-stock',[0,0,0],[.1,.1,.1],darkConcrete,false);st.reparent(g);st.setLocalPosition(0,0,.43);st.setLocalScale(.24,.14,.36);return g;}
  let weaponModel=fallbackWeapon();
  app.assets.loadFromUrl('https://raw.githubusercontent.com/petroulacl/fps-asset-kit/main/weapons/flat_guns_west/Flat%20Guns%20West/GLB/Rifle_Assault_West.glb','container',(err,asset)=>{if(err||!asset||!asset.resource)return;try{const loaded=asset.resource.instantiateRenderEntity();weaponRoot.addChild(loaded);loaded.setLocalScale(.46,.46,.46);loaded.setLocalPosition(.04,-.1,-.1);loaded.setLocalEulerAngles(0,90,0);weaponModel.enabled=false;weaponModel=loaded;}catch(e){console.warn(e);}});
  const flashMat=material('flash',[1,.56,.12],0,.95);const muzzle=new pc.Entity('MuzzleFlash');muzzle.addComponent('render',{type:'sphere'});muzzle.render.material=flashMat;weaponRoot.addChild(muzzle);muzzle.setLocalPosition(0,0,-1.23);muzzle.setLocalScale(.13,.13,.13);muzzle.enabled=false;
  const shotAudio=new Audio('https://raw.githubusercontent.com/petroulacl/fps-asset-kit/main/sfx/gunshots/game_gunshot.wav');shotAudio.preload='auto';shotAudio.volume=.48;

  function collides(x,z,r=.42){return solids.some(s=>x+r>s.minX&&x-r<s.maxX&&z+r>s.minZ&&z-r<s.maxZ);}
  function segmentBlocked(ax,az,bx,bz){const steps=Math.ceil(Math.hypot(bx-ax,bz-az)/.8);for(let i=1;i<steps;i++){const t=i/steps;if(collides(ax+(bx-ax)*t,az+(bz-az)*t,.05))return true;}return false;}
  function toast(text){const e=$('#toast');e.textContent=text;e.classList.remove('on');void e.offsetWidth;e.classList.add('on');}
  function hitMark(){const e=$('#hit-marker');e.classList.remove('flash');void e.offsetWidth;e.classList.add('flash');}
  function raySphere(o,d,c,r){const oc=new pc.Vec3().sub2(o,c),b=oc.dot(d),q=oc.dot(oc)-r*r,disc=b*b-q;if(disc<0)return null;const t=-b-Math.sqrt(disc);return t>0?t:null;}
  function shoot(){if(state.mode!=='raid'||state.reload>0||state.fireCooldown>0)return;if(state.ammo<=0){toast('MAGAZINE EMPTY');return;}state.ammo--;state.fireCooldown=.095;muzzle.enabled=true;setTimeout(()=>muzzle.enabled=false,45);try{const a=shotAudio.cloneNode();a.volume=.5;a.play().catch(()=>{});}catch(_){ }
    const o=camera.getPosition().clone(),d=camera.forward.clone();let best=null,bestT=Infinity;for(const e of enemies){if(e.dead)continue;const c=e.root.getPosition().clone();c.y+=1.45;const t=raySphere(o,d,c,.72);if(t&&t<bestT){const h=o.clone().add(d.clone().mulScalar(t));if(!segmentBlocked(o.x,o.z,h.x,h.z)){best=e;bestT=t;}}}if(best){best.hp-=42;hitMark();best.torso.setLocalEulerAngles(-8,0,0);if(best.hp<=0){best.dead=true;state.kills++;best.root.rotateLocal(0,0,82);setTimeout(()=>best.root.enabled=false,900);toast('HOSTILE DOWN');}}updateHud();}
  function reload(){if(state.mode!=='raid'||state.reload>0||state.ammo>=30||state.reserve<=0)return;state.reload=1.65;toast('RELOADING');}
  function interact(){if(state.mode!=='raid')return;const p=player.getPosition();if(!state.objectiveSecured&&p.distance(drive.getPosition())<2.1){state.objectiveSecured=true;drive.enabled=false;extractMarker.enabled=true;$('#objective').textContent='OBJECTIVE · Reach Gate 3 extraction';toast('ENCRYPTED DRIVE SECURED');return;}if(state.objectiveSecured&&p.distance(extractMarker.getPosition())<2.6)endRaid(true);}
  function updateHud(){$('#ammo').textContent=state.ammo;$('#reserve').textContent=state.reserve;$('#hp').textContent=Math.max(0,Math.ceil(state.hp));$('#armor').textContent=Math.max(0,Math.ceil(state.armor));$('#stamina').textContent=Math.ceil(state.stamina);const m=Math.max(0,Math.floor(state.raidTime/60)),s=Math.max(0,Math.floor(state.raidTime%60));$('#raid-timer').textContent=String(m).padStart(2,'0')+':'+String(s).padStart(2,'0');const sh=$('#shield');if(state.shield>0){sh.classList.remove('hidden');sh.textContent='INSERTION SHIELD · '+state.shield.toFixed(1);}else sh.classList.add('hidden');$('#damage-flash').style.opacity=Math.min(.75,state.damageFlash).toFixed(2);}
  function damage(a){if(state.shield>0||state.mode!=='raid')return;let d=a;if(state.armor>0){const x=Math.min(state.armor,d*.65);state.armor-=x;d-=x*.68;}state.hp-=d;state.damageFlash=.65;if(state.hp<=0){state.hp=0;endRaid(false);}updateHud();}
  function resetRaid(){Object.assign(state,{hp:100,armor:60,stamina:100,ammo:30,reserve:90,reload:0,raidTime:900,shield:6,ads:false,firing:false,fireCooldown:0,objectiveSecured:false,kills:0,damageFlash:0,yaw:0,pitch:0});player.setPosition(0,0,24);player.setEulerAngles(0,0,0);camera.setLocalEulerAngles(0,0,0);drive.enabled=true;extractMarker.enabled=false;const pos=[[-10,3],[12,-2],[26,-28],[-25,-16],[9,-34],[-28,29],[25,24],[3,29]];enemies.forEach((e,i)=>{e.hp=100;e.dead=false;e.cooldown=.5+Math.random();e.root.enabled=true;e.root.setPosition(pos[i][0],0,pos[i][1]);e.root.setEulerAngles(0,0,0);e.torso.setLocalEulerAngles(0,0,0);});$('#objective').textContent='OBJECTIVE · Recover encrypted drive';updateHud();}
  function show(e){e.classList.add('screen-on');}function hide(e){e.classList.remove('screen-on');}
  $('#deploy-btn').addEventListener('click',()=>{hide(menu);show(brief);state.mode='brief';});
  $('#begin-btn').addEventListener('click',()=>{hide(brief);hud.classList.remove('hidden');controls.classList.remove('hidden');resetRaid();state.mode='raid';canvas.focus();});
  $('#return-btn').addEventListener('click',()=>{hide(result);hud.classList.add('hidden');controls.classList.add('hidden');show(menu);state.mode='menu';});
  $('#reload-btn').addEventListener('pointerdown',reload);$('#use-btn').addEventListener('pointerdown',interact);
  function endRaid(ok){if(state.mode!=='raid')return;state.mode='result';hud.classList.add('hidden');controls.classList.add('hidden');show(result);$('#result-title').textContent=ok?'EXTRACTION SUCCESSFUL':'OPERATOR LOST';$('#result-copy').textContent=ok?`Encrypted drive recovered. ${state.kills} hostiles eliminated. Your raid kit returns to stash.`:`You were killed in Harbor Yard after eliminating ${state.kills} hostiles. Deployed kit is considered lost.`;}

  const pad=$('#move-pad'),knob=$('#move-knob');let mp=null;function moveInput(e){const r=pad.getBoundingClientRect();let x=e.clientX-(r.left+r.width/2),y=e.clientY-(r.top+r.height/2),lim=r.width*.32,mag=Math.hypot(x,y);if(mag>lim){x*=lim/mag;y*=lim/mag;}state.moveX=x/lim;state.moveY=-y/lim;knob.style.transform=`translate(${x}px,${y}px)`;}pad.addEventListener('pointerdown',e=>{mp=e.pointerId;pad.setPointerCapture(e.pointerId);moveInput(e)});pad.addEventListener('pointermove',e=>{if(e.pointerId===mp)moveInput(e)});function stopMove(e){if(e.pointerId!==mp)return;mp=null;state.moveX=state.moveY=0;knob.style.transform='translate(0,0)';}pad.addEventListener('pointerup',stopMove);pad.addEventListener('pointercancel',stopMove);
  const look=$('#look-zone');let lp=null,lx=0,ly=0;look.addEventListener('pointerdown',e=>{lp=e.pointerId;lx=e.clientX;ly=e.clientY;look.setPointerCapture(e.pointerId)});look.addEventListener('pointermove',e=>{if(e.pointerId!==lp)return;state.yaw-=(e.clientX-lx)*.18;state.pitch=Math.max(-72,Math.min(70,state.pitch-(e.clientY-ly)*.14));lx=e.clientX;ly=e.clientY;});look.addEventListener('pointerup',e=>{if(e.pointerId===lp)lp=null});look.addEventListener('pointercancel',e=>{if(e.pointerId===lp)lp=null});
  const fire=$('#fire-btn');fire.addEventListener('pointerdown',e=>{state.firing=true;fire.setPointerCapture(e.pointerId);shoot()});['pointerup','pointercancel','pointerleave'].forEach(v=>fire.addEventListener(v,()=>state.firing=false));$('#ads-btn').addEventListener('pointerdown',()=>state.ads=!state.ads);

  canvas.addEventListener('click',()=>{if(state.mode==='raid'&&!pc.platform.touch)canvas.requestPointerLock?.()});document.addEventListener('mousemove',e=>{if(document.pointerLockElement===canvas&&state.mode==='raid'){state.yaw-=e.movementX*.11;state.pitch=Math.max(-72,Math.min(70,state.pitch-e.movementY*.095));}});document.addEventListener('mousedown',e=>{if(state.mode==='raid'&&e.button===0){state.firing=true;shoot();}if(state.mode==='raid'&&e.button===2)state.ads=true;});document.addEventListener('mouseup',e=>{if(e.button===0)state.firing=false;if(e.button===2)state.ads=false;});document.addEventListener('keydown',e=>{if(e.code==='KeyR')reload();if(e.code==='KeyE')interact();});
  function keys(){let x=0,y=0;if(app.keyboard.isPressed(pc.KEY_A))x--;if(app.keyboard.isPressed(pc.KEY_D))x++;if(app.keyboard.isPressed(pc.KEY_W))y++;if(app.keyboard.isPressed(pc.KEY_S))y--;return{x,y};}

  app.on('update',dt=>{if(state.mode!=='raid')return;state.raidTime-=dt;state.shield=Math.max(0,state.shield-dt);state.fireCooldown=Math.max(0,state.fireCooldown-dt);state.damageFlash=Math.max(0,state.damageFlash-dt*1.8);if(state.raidTime<=0){endRaid(false);return;}if(state.reload>0){state.reload-=dt;weaponRoot.setLocalEulerAngles(-16,180,9);if(state.reload<=0){const n=Math.min(30-state.ammo,state.reserve);state.ammo+=n;state.reserve-=n;toast('READY');}}else weaponRoot.setLocalEulerAngles(-3,180,0);if(state.firing)shoot();
    const k=keys();let mx=Math.abs(state.moveX)>.02?state.moveX:k.x,my=Math.abs(state.moveY)>.02?state.moveY:k.y,l=Math.hypot(mx,my);if(l>1){mx/=l;my/=l;}const sprint=l>.82&&state.stamina>0,speed=sprint?6.1:4.15;if(sprint)state.stamina=Math.max(0,state.stamina-dt*18);else state.stamina=Math.min(100,state.stamina+dt*13);const yr=state.yaw*pc.math.DEG_TO_RAD,fx=-Math.sin(yr),fz=-Math.cos(yr),rx=Math.cos(yr),rz=-Math.sin(yr),dx=(rx*mx+fx*my)*speed*dt,dz=(rz*mx+fz*my)*speed*dt,p=player.getPosition();if(!collides(p.x+dx,p.z))player.setPosition(p.x+dx,0,p.z);const p2=player.getPosition();if(!collides(p2.x,p2.z+dz))player.setPosition(p2.x,0,p2.z+dz);player.setEulerAngles(0,state.yaw,0);camera.setLocalEulerAngles(state.pitch,0,0);
    const f=state.ads?48:72;camera.camera.fov+=(f-camera.camera.fov)*Math.min(1,dt*12);const target=state.ads?new pc.Vec3(0,-.16,-.49):new pc.Vec3(.34,-.42,-.75),wp=weaponRoot.getLocalPosition(),t=Math.min(1,dt*13);weaponRoot.setLocalPosition(wp.x+(target.x-wp.x)*t,wp.y+(target.y-wp.y)*t,wp.z+(target.z-wp.z)*t);
    const pp=player.getPosition();enemies.forEach(e=>{if(e.dead||!e.root.enabled)return;e.cooldown-=dt;e.phase+=dt*6;const ep=e.root.getPosition(),x=pp.x-ep.x,z=pp.z-ep.z,dist=Math.hypot(x,z),sees=dist<27&&!segmentBlocked(ep.x,ep.z,pp.x,pp.z);if(sees){e.root.setEulerAngles(0,Math.atan2(x,z)*pc.math.RAD_TO_DEG,0);if(dist>7.5){const vx=x/dist*dt*1.55,vz=z/dist*dt*1.55;if(!collides(ep.x+vx,ep.z,.34))e.root.translate(vx,0,0);const ep2=e.root.getPosition();if(!collides(ep2.x,ep2.z+vz,.34))e.root.translate(0,0,vz);e.legL.setLocalEulerAngles(Math.sin(e.phase)*25,0,0);e.legR.setLocalEulerAngles(-Math.sin(e.phase)*25,0,0);}if(dist<21&&e.cooldown<=0){e.cooldown=.85+Math.random()*.7;const acc=Math.max(.12,.62-dist*.017);if(Math.random()<acc)damage(7+Math.random()*8);}}else{e.legL.setLocalEulerAngles(0,0,0);e.legR.setLocalEulerAngles(0,0,0);}e.torso.setLocalEulerAngles(e.torso.getLocalEulerAngles().x*.82,0,0);});updateHud();});

  document.querySelectorAll('.stash-item').forEach(b=>b.addEventListener('click',()=>toast(b.dataset.name?b.dataset.name.toUpperCase()+' · READY FOR LOADOUT':'GEAR INSPECTED')));
  bootCopy.textContent='Loading PlayCanvas scene and tactical assets…';setTimeout(()=>{boot.style.opacity='0';boot.style.transition='opacity .35s';setTimeout(()=>boot.remove(),380);state.mode='menu';},900);
})();
