'use strict';
const canvas=document.getElementById('game'),ctx=canvas.getContext('2d',{alpha:false});
const wrap=document.getElementById('wrap');
const ui={
 hpFill:document.getElementById('hpFill'),manaFill:document.getElementById('manaFill'),xpFill:document.getElementById('xpFill'),
 hpText:document.getElementById('hpText'),manaText:document.getElementById('manaText'),xpText:document.getElementById('xpText'),
 levelText:document.getElementById('levelText'),powerText:document.getElementById('powerText'),questTitle:document.getElementById('questTitle'),questText:document.getElementById('questText'),
 overlay:document.getElementById('overlay'),upgrade:document.getElementById('upgrade'),cards:document.getElementById('upgradeCards'),toast:document.getElementById('toast'),progressFill:document.getElementById('progressFill'),dashBtn:document.getElementById('dashBtn'),novaBtn:document.getElementById('novaBtn'),runStats:document.getElementById('runStats'),pauseSheet:document.getElementById('pauseSheet'),installSheet:document.getElementById('installSheet')
};
let W=1280,H=720,dpr=1,last=0,started=false,paused=false,won=false,shake=0,flash=0,toastTimer=0,runTime=0,kills=0,manualPause=false;
let camX=0,worldW=5600,floorY=610;
const keys={left:false,right:false,jump:false,cast:false,dash:false,nova:false};
const particles=[],projectiles=[],enemies=[],pickups=[],platforms=[],decor=[];
const stars=Array.from({length:90},()=>({x:Math.random()*1.2,y:Math.random()*.62,r:.4+Math.random()*1.6,a:.25+Math.random()*.75}));
const audio={ctx:null,master:null,musicTimer:null,musicStep:0};
function initAudio(){if(audio.ctx)return;try{audio.ctx=new (window.AudioContext||window.webkitAudioContext)();audio.master=audio.ctx.createGain();audio.master.gain.value=.18;audio.master.connect(audio.ctx.destination)}catch(e){}}
function tone(freq=440,dur=.08,type='sine',gain=.12,slide=1){if(!audio.ctx)return;const o=audio.ctx.createOscillator(),g=audio.ctx.createGain();o.type=type;o.frequency.setValueAtTime(freq,audio.ctx.currentTime);o.frequency.exponentialRampToValueAtTime(Math.max(40,freq*slide),audio.ctx.currentTime+dur);g.gain.setValueAtTime(gain,audio.ctx.currentTime);g.gain.exponentialRampToValueAtTime(.001,audio.ctx.currentTime+dur);o.connect(g);g.connect(audio.master);o.start();o.stop(audio.ctx.currentTime+dur)}
function startMusic(){if(!audio.ctx||audio.musicTimer)return;const notes=[146.83,174.61,220,196,164.81,220,246.94,196];audio.musicTimer=setInterval(()=>{if(!started||paused||document.hidden)return;const f=notes[audio.musicStep++%notes.length];tone(f,.65,'sine',.018,.995);if(audio.musicStep%4===0)tone(f/2,1.1,'triangle',.012,1.002)},720)}
function noise(dur=.12,gain=.08){if(!audio.ctx)return;const n=Math.max(1,Math.floor(audio.ctx.sampleRate*dur)),buf=audio.ctx.createBuffer(1,n,audio.ctx.sampleRate),data=buf.getChannelData(0);for(let i=0;i<n;i++)data[i]=(Math.random()*2-1)*(1-i/n);const s=audio.ctx.createBufferSource(),g=audio.ctx.createGain();s.buffer=buf;g.gain.value=gain;s.connect(g);g.connect(audio.master);s.start()}
function resize(){const r=wrap.getBoundingClientRect();dpr=Math.min(2,window.devicePixelRatio||1);canvas.width=Math.max(1,Math.floor(r.width*dpr));canvas.height=Math.max(1,Math.floor(r.height*dpr));W=r.width;H=r.height;ctx.setTransform(dpr,0,0,dpr,0,0);floorY=Math.max(390,H-110)}
window.addEventListener('resize',resize,{passive:true});resize();
function clamp(v,a,b){return Math.max(a,Math.min(b,v))}
function rand(a,b){return a+Math.random()*(b-a)}
function rects(a,b){return a.x<b.x+b.w&&a.x+a.w>b.x&&a.y<b.y+b.h&&a.y+a.h>b.y}
function circleRect(cx,cy,r,o){const px=clamp(cx,o.x,o.x+o.w),py=clamp(cy,o.y,o.y+o.h),dx=cx-px,dy=cy-py;return dx*dx+dy*dy<r*r}
const player={x:120,y:0,w:42,h:62,vx:0,vy:0,dir:1,onGround:false,hp:100,maxHp:100,mana:100,maxMana:100,manaRegen:13,level:1,xp:0,nextXp:100,spell:18,speed:285,jump:640,castCd:0,dashCd:0,novaCd:0,inv:0,dashT:0,blast:1,crit:.08,lifeSteal:0};
const upgrades=[
 {icon:'✦',name:'Arcane Power',desc:'+6 spell damage.',apply:()=>player.spell+=6},
 {icon:'♥',name:'Vitality',desc:'+25 max HP and heal 25.',apply:()=>{player.maxHp+=25;player.hp=Math.min(player.maxHp,player.hp+25)}},
 {icon:'◈',name:'Mana Well',desc:'+25 max mana and faster regeneration.',apply:()=>{player.maxMana+=25;player.mana=player.maxMana;player.manaRegen+=3}},
 {icon:'➤',name:'Fleetstep',desc:'+9% movement speed and faster dash recovery.',apply:()=>{player.speed*=1.09}},
 {icon:'☄',name:'Pyromancy',desc:'Larger projectile impact and stronger particles.',apply:()=>player.blast+=.28},
 {icon:'✧',name:'Focused Casting',desc:'+6% critical chance.',apply:()=>player.crit=Math.min(.5,player.crit+.06)},
 {icon:'☼',name:'Rift Drain',desc:'Recover 3% of magic damage as HP.',apply:()=>player.lifeSteal+=.03},
 {icon:'⚡',name:'Overcharge',desc:'+12 spell damage, -10 max mana.',apply:()=>{player.spell+=12;player.maxMana=Math.max(50,player.maxMana-10);player.mana=Math.min(player.mana,player.maxMana)}}
];
function resetGame(){
 started=true;paused=false;manualPause=false;won=false;runTime=0;kills=0;camX=0;shake=0;flash=0;particles.length=projectiles.length=enemies.length=pickups.length=platforms.length=decor.length=0;
 Object.assign(player,{x:120,y:floorY-62,w:42,h:62,vx:0,vy:0,dir:1,onGround:false,hp:100,maxHp:100,mana:100,maxMana:100,manaRegen:13,level:1,xp:0,nextXp:100,spell:18,speed:285,jump:640,castCd:0,dashCd:0,novaCd:0,inv:0,dashT:0,blast:1,crit:.08,lifeSteal:0});
 buildLevel();updateHUD();showToast('Reach the Rift Gate');
}
function buildLevel(){
 platforms.push({x:0,y:floorY,w:worldW,h:120,type:'ground'});
 const plats=[[520,-90,220],[920,-160,180],[1320,-85,250],[1780,-150,200],[2250,-110,260],[2740,-180,220],[3270,-100,250],[3720,-170,200],[4160,-120,240]];
 for(const [x,dy,w] of plats)platforms.push({x,y:floorY+dy,w,h:24,type:'stone'});
 const enemyDefs=[
  [520,'wisp'],[780,'crawler'],[1020,'wisp'],[1280,'crawler'],[1500,'wisp'],[1780,'sentinel'],[2050,'crawler'],[2320,'wisp'],[2550,'sentinel'],[2890,'crawler'],[3120,'wisp'],[3360,'sentinel'],[3650,'crawler'],[3920,'wisp'],[4210,'sentinel'],[4510,'crawler']
 ];
 enemyDefs.forEach(([x,t],i)=>spawnEnemy(x,t,i));
 for(let x=320;x<4800;x+=rand(170,280)) decor.push({x,type:Math.random()<.55?'crystal':'ruin',s:rand(.6,1.25)});
 decor.push({x:4880,type:'gate',s:1.3});
}
function spawnEnemy(x,type,id){
 let e={x,y:floorY-48,w:42,h:48,vx:0,vy:0,type,id,hp:45,maxHp:45,dmg:12,speed:70,dead:false,hit:0,aggro:330,attack:0,xp:35};
 if(type==='wisp')Object.assign(e,{w:36,h:36,y:floorY-160,hp:32,maxHp:32,dmg:10,speed:85,xp:30,float:Math.random()*6});
 if(type==='crawler')Object.assign(e,{w:50,h:34,y:floorY-34,hp:54,maxHp:54,dmg:14,speed:95,xp:38});
 if(type==='sentinel')Object.assign(e,{w:46,h:70,y:floorY-70,hp:92,maxHp:92,dmg:18,speed:48,xp:65});
 enemies.push(e);
}
function spawnBoss(){if(enemies.some(e=>e.type==='boss'&&!e.dead))return;const e={x:5110,y:floorY-120,w:94,h:120,vx:0,vy:0,type:'boss',id:999,hp:680,maxHp:680,dmg:24,speed:54,dead:false,hit:0,aggro:760,attack:0,xp:500,phase:0};enemies.push(e);ui.questTitle.textContent='Defeat the Rift Warden';ui.questText.textContent='Break the Warden before the portal consumes the Vale.';showToast('BOSS: Rift Warden');tone(110,.35,'sawtooth',.18,.5)}
function showToast(t){ui.toast.textContent=t;ui.toast.classList.add('show');clearTimeout(toastTimer);toastTimer=setTimeout(()=>ui.toast.classList.remove('show'),1350)}
function gainXp(n){player.xp+=n;while(player.xp>=player.nextXp){player.xp-=player.nextXp;player.level++;player.nextXp=Math.round(player.nextXp*1.35);openUpgrade();}updateHUD()}
function openUpgrade(){paused=true;ui.upgrade.classList.remove('hidden');ui.cards.innerHTML='';const pool=[...upgrades].sort(()=>Math.random()-.5).slice(0,3);pool.forEach(u=>{const b=document.createElement('button');b.className='card';b.type='button';b.innerHTML=`<div class="icon">${u.icon}</div><h3>${u.name}</h3><p>${u.desc}</p>`;b.addEventListener('click',()=>{u.apply();ui.upgrade.classList.add('hidden');paused=false;updateHUD();showToast(u.name);tone(660,.12,'sine',.1,1.4)});ui.cards.appendChild(b)})}
function updateHUD(){
 ui.hpText.textContent=`${Math.ceil(player.hp)} / ${player.maxHp}`;ui.manaText.textContent=`${Math.ceil(player.mana)} / ${player.maxMana}`;ui.xpText.textContent=`${Math.floor(player.xp)} / ${player.nextXp} XP`;ui.levelText.textContent=player.level;ui.powerText.textContent=Math.round(player.spell);
 ui.hpFill.style.width=`${clamp(player.hp/player.maxHp*100,0,100)}%`;ui.manaFill.style.width=`${clamp(player.mana/player.maxMana*100,0,100)}%`;ui.xpFill.style.width=`${clamp(player.xp/player.nextXp*100,0,100)}%`;
 ui.progressFill.style.width=`${clamp(player.x/(worldW-player.w)*100,0,100)}%`;
 const dcd=clamp(player.dashCd/1.05,0,1),ncd=clamp(player.novaCd/3.2,0,1);ui.dashBtn.style.setProperty('--cd',dcd);ui.novaBtn.style.setProperty('--cd',ncd);ui.dashBtn.classList.toggle('readyPulse',dcd===0);ui.novaBtn.classList.toggle('readyPulse',ncd===0);
}
function burst(x,y,color='#a78bfa',count=18,speed=190,size=4){for(let i=0;i<count;i++){const a=Math.random()*Math.PI*2,s=rand(speed*.25,speed);particles.push({x,y,vx:Math.cos(a)*s,vy:Math.sin(a)*s,life:rand(.35,.75),max:.75,size:rand(size*.5,size*1.5),color,drag:.96,g:-25})}}
function sparkTrail(x,y,color){particles.push({x,y,vx:rand(-30,30),vy:rand(-30,30),life:rand(.15,.35),max:.35,size:rand(2,6),color,drag:.94,g:0})}
function castSpell(){if(player.castCd>0||player.mana<12)return;player.castCd=.28;player.mana-=12;const speed=660,px=player.x+(player.dir>0?player.w+8:-8),py=player.y+25;projectiles.push({x:px,y:py,vx:speed*player.dir,vy:0,r:9*player.blast,life:1.25,damage:player.spell,type:'bolt',pierce:0});for(let i=0;i<9;i++)sparkTrail(px,py,'#67e8f9');tone(420,.07,'triangle',.08,1.8)}
function castNova(){if(player.novaCd>0||player.mana<38)return;player.novaCd=3.2;player.mana-=38;const cx=player.x+player.w/2,cy=player.y+player.h/2;burst(cx,cy,'#c084fc',52,360,6);burst(cx,cy,'#67e8f9',22,260,3);for(const e of enemies){if(e.dead)continue;const dx=(e.x+e.w/2)-cx,dy=(e.y+e.h/2)-cy,d=Math.hypot(dx,dy);if(d<210){dealDamage(e,player.spell*1.35*(1-d/420));e.vx+=Math.sign(dx||1)*220}}shake=8;flash=.13;tone(190,.24,'sawtooth',.12,2.2);noise(.13,.08)}
function dash(){if(player.dashCd>0)return;player.dashCd=1.05;player.dashT=.18;player.inv=.24;player.vx=player.dir*720;for(let i=0;i<12;i++)sparkTrail(player.x+player.w/2,player.y+player.h/2,'#fde68a');tone(150,.08,'square',.07,2)}
function dealDamage(e,amount){const crit=Math.random()<player.crit;const dmg=amount*(crit?1.85:1);e.hp-=dmg;e.hit=.12;shake=Math.max(shake,crit?7:3);burst(e.x+e.w/2,e.y+e.h/2,crit?'#fde68a':'#8be9fd',crit?14:7,crit?220:130,crit?4:3);if(player.lifeSteal)player.hp=Math.min(player.maxHp,player.hp+dmg*player.lifeSteal);if(e.hp<=0&&!e.dead){e.dead=true;kills++;burst(e.x+e.w/2,e.y+e.h/2,e.type==='boss'?'#fbbf24':'#a78bfa',e.type==='boss'?80:26,e.type==='boss'?420:230,e.type==='boss'?7:4);gainXp(e.xp);tone(e.type==='boss'?95:240,e.type==='boss'?.5:.1,'sawtooth',e.type==='boss'?.18:.07,.45);if(e.type==='boss')winGame();}}
function hurtPlayer(dmg,knock=1){if(player.inv>0||won)return;player.hp-=dmg;player.inv=.75;player.vy=-220;player.vx=-player.dir*190*knock;shake=10;flash=.18;burst(player.x+player.w/2,player.y+player.h/2,'#fb7185',20,220,4);noise(.1,.1);if(player.hp<=0){player.hp=0;gameOver()}updateHUD()}
function gameOver(){paused=true;setTimeout(()=>{ui.overlay.classList.remove('hidden');ui.overlay.querySelector('.title').innerHTML='RIFT<br>CLAIMED';ui.overlay.querySelector('.subtitle').textContent='The Vale consumed you. Your run can begin again immediately.';document.getElementById('startBtn').textContent='Try Again';},180)}
function winGame(){won=true;paused=true;saveBestRun();ui.questTitle.textContent='Rift Sealed';ui.questText.textContent='The Shattered Vale survives.';setTimeout(()=>{ui.overlay.classList.remove('hidden');ui.overlay.querySelector('.title').innerHTML='VALE<br>SAVED';ui.overlay.querySelector('.subtitle').textContent=`Rift Warden defeated at level ${player.level} in ${formatTime(runTime)} with ${kills} enemies defeated.`;ui.runStats.textContent=bestRunText();document.getElementById('startBtn').textContent='Play Again';},450)}
function playerPhysics(dt){
 player.castCd=Math.max(0,player.castCd-dt);player.dashCd=Math.max(0,player.dashCd-dt);player.novaCd=Math.max(0,player.novaCd-dt);player.inv=Math.max(0,player.inv-dt);player.dashT=Math.max(0,player.dashT-dt);player.mana=Math.min(player.maxMana,player.mana+player.manaRegen*dt);
 if(keys.left){player.dir=-1;if(player.dashT<=0)player.vx-=player.speed*5.2*dt}if(keys.right){player.dir=1;if(player.dashT<=0)player.vx+=player.speed*5.2*dt}
 if(!keys.left&&!keys.right&&player.dashT<=0)player.vx*=Math.pow(.0007,dt);
 player.vx=clamp(player.vx,-(player.dashT>0?760:player.speed),(player.dashT>0?760:player.speed));
 if(keys.jump&&player.onGround){player.vy=-player.jump;player.onGround=false;tone(230,.06,'triangle',.045,1.5)}
 player.vy+=1500*dt;let prevY=player.y;player.x+=player.vx*dt;player.y+=player.vy*dt;player.onGround=false;
 for(const p of platforms){if(player.x+player.w>p.x&&player.x<p.x+p.w&&prevY+player.h<=p.y+4&&player.y+player.h>=p.y&&player.vy>=0){player.y=p.y-player.h;player.vy=0;player.onGround=true}}
 player.x=clamp(player.x,0,worldW-player.w);
 if(player.y>H+300)hurtPlayer(999);
 if(keys.cast)castSpell();if(keys.dash)dash();if(keys.nova){castNova();keys.nova=false}
 if(player.x>4700&&!enemies.some(e=>e.type==='boss'))spawnBoss();
}
function enemyAI(e,dt){
 if(e.dead)return;e.hit=Math.max(0,e.hit-dt);e.attack=Math.max(0,e.attack-dt);const dx=player.x-e.x,dist=Math.abs(dx);let dir=Math.sign(dx||1);
 if(e.type==='wisp'){e.float+=dt*3.4;e.y+=Math.sin(e.float)*18*dt;if(dist<e.aggro)e.vx+=dir*e.speed*2.2*dt;e.vx*=Math.pow(.08,dt)}
 else if(e.type==='boss'){
  e.phase+=dt;if(dist<e.aggro)e.vx+=dir*e.speed*1.9*dt;e.vx=clamp(e.vx,-e.speed*1.4,e.speed*1.4);
  if(e.attack<=0&&dist<480){e.attack=e.hp<e.maxHp*.45?1.15:1.65;const shots=e.hp<e.maxHp*.45?5:3;for(let i=0;i<shots;i++){const a=(i-(shots-1)/2)*.16;projectiles.push({x:e.x+e.w/2,y:e.y+36,vx:Math.cos(a)*(-dir)*300,vy:Math.sin(a)*300,r:10,life:2.4,damage:e.dmg,type:'enemy'});}tone(120,.12,'square',.08,.7)}
 } else {if(dist<e.aggro)e.vx+=dir*e.speed*3*dt;else e.vx+=Math.sin((e.id+performance.now()/1800))*e.speed*.3*dt;e.vx=clamp(e.vx,-e.speed,e.speed)}
 e.x+=e.vx*dt;if(e.type!=='wisp')e.vx*=Math.pow(.02,dt);
 if(rects(player,e)&&e.attack<=0){e.attack=e.type==='boss'?.55:.9;hurtPlayer(e.dmg,e.type==='boss'?1.5:1)}
}
function updateProjectiles(dt){
 for(let i=projectiles.length-1;i>=0;i--){const p=projectiles[i];p.life-=dt;p.x+=p.vx*dt;p.y+=p.vy*dt;if(p.type==='bolt'){sparkTrail(p.x,p.y,Math.random()<.5?'#67e8f9':'#c084fc');let hit=null;for(const e of enemies){if(!e.dead&&circleRect(p.x,p.y,p.r,e)){hit=e;break}}if(hit){dealDamage(hit,p.damage);burst(p.x,p.y,'#67e8f9',14*player.blast,220,4*player.blast);projectiles.splice(i,1);continue}} else {sparkTrail(p.x,p.y,'#fb7185');if(circleRect(p.x,p.y,p.r,player)){hurtPlayer(p.damage);projectiles.splice(i,1);continue}}if(p.life<=0||p.x<camX-300||p.x>camX+W+600){projectiles.splice(i,1)}}
}
function updateParticles(dt){for(let i=particles.length-1;i>=0;i--){const p=particles[i];p.life-=dt;if(p.life<=0){particles.splice(i,1);continue}p.vx*=Math.pow(p.drag,dt*60);p.vy*=Math.pow(p.drag,dt*60);p.vy+=(p.g||0)*dt;p.x+=p.vx*dt;p.y+=p.vy*dt}}
function update(dt){if(!started||paused)return;runTime+=dt;playerPhysics(dt);for(const e of enemies)enemyAI(e,dt);updateProjectiles(dt);updateParticles(dt);camX+=(clamp(player.x-W*.35,0,worldW-W)-camX)*(1-Math.pow(.0008,dt));shake*=Math.pow(.01,dt);flash=Math.max(0,flash-dt);updateHUD()}
