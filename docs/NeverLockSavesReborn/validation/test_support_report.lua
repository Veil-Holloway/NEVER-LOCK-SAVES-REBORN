local dir=assert(arg[1], 'module directory required')
package.path=dir..'/?.lua;'..package.path
local report=require('support_report')
local n=0
local function eq(a,b,label) n=n+1;assert(a==b,label..': '..tostring(a)..' != '..tostring(b)) end
local input={build='0.14.0-rc1',gameBuild='2.31',versions={cet='1.37.1',redscript='0.5.29',red4ext='unknown',nativeSettings='1.98',darkFuture='2.0.0'},
 settings={mode=3,tone=2,guardianEnabled=true},facts={q000_done=1,q001_started=0},
 sensors={combatKnown=true,combatActive=false,vehicleKnown=true,vehicleActive=false,phoneKnown=true,phoneActive=false,phoneBridgeStatus='observed_clear',phoneRawState=0,autosavePhoneBridgeStatus='observed_clear',autosavePhoneRawState=0,paused=false},
 context=0,body=2,queue={pending=true,source='manual',serial=12,session=2,gate='stabilizing',state='Waiting',currentState='Waiting',lastOutcomeState='Submitted',lastOutcomeReason='submitted',origin='game',expiresIn=14},
 darkFuture={vehicleSleep=1,addiction=0,starvation=-1,dehydration=0,lifecycle='Running',enabled=true,valid=true,inMenu=false},
 notificationPool='Exploration | pool=0/2/2 | mode=3 | saveProtection=false',
 configWriteStatus='written',profileSelected=true,errors={'bridge_unavailable','dispatch_rejected'},
 autosave={enabled=true,status='waiting',reason='exploration_interval',accepted=2,rejected=1,blockedTransitions=4,blockedReason='phone unknown'},
 guardian={enabled=true,total_requests=8,history_incomplete=false,tracking_gaps=0,records={{id='R123-456:G1:2:1',source='manual',phase='Submitted',reason='submitted',serial=1,session=2,write_status='Verified',reload_status='Verified'}}}}
local r=report.build(input)
eq(r.reborn_build,'0.14.0-rc1','version preserved');eq(r.game_build,'2.31','game version preserved')
eq(r.dependencies.cet,'1.37.1','CET version preserved');eq(r.dependencies.red4ext,'unknown','missing exact version remains unknown')
eq(r.settings.effective.mode,3,'mode captured');eq(r.settings.effective.autosaveEnabled,false,'unsupplied settings defaultoff')
eq(r.settings.validation,'valid','valid effective settings');eq(r.settings.config_write_status,'written','write acknowledgement separate');eq(r.settings.restart_persistence,'unknown','write is not restart evidence')
eq(r.schema_version,2,'scope-freeze report schema');eq(r.presets.scope,'manual_named_settings_only','manual presets scope exact')
eq(r.facts.q000_done,1,'intro fact captured');eq(r.facts.q001_started,0,'diagnostic zero retained')
eq(r.context.category,0,'context zero retained');eq(r.context.body,2,'body category retained')
eq(r.context.combat,'clear','known clear not unknown');eq(r.context.vehicle,'clear','vehicle clear');eq(r.context.phone,'clear','phone clear');eq(r.context.phone_evidence.status,'observed_clear','phone bridge evidence retained');eq(r.context.phone_evidence.raw_state,0,'phone raw tri-state retained');eq(r.context.paused,false,'paused false retained')
eq(r.queue.serial,12,'serial captured');eq(r.queue.gate,'stabilizing','gate captured');eq(r.queue.source,'manual','source captured');eq(r.queue.current_state,'Waiting','current queue state explicit');eq(r.queue.last_outcome_state,'Submitted','historical outcome separate');eq(r.queue.last_outcome_reason,'submitted','historical reason normalized');eq(r.queue.expires_in,14,'bounded expiry captured')
eq(r.dark_future.vehicle_sleep,1,'DF active');eq(r.dark_future.addiction,0,'DF clear');eq(r.dark_future.starvation,-1,'DF unknown');eq(r.dark_future.lifecycle,'Running','DF lifecycle')
eq(r.notification_pool,'Exploration | pool=0/2/2 | mode=3 | saveProtection=false','known diagnostic string retained')
eq(r.guardian.records[1].phase,'Submitted','request phase retained');eq(r.guardian.records[1].write_status,'Unknown','incoming success claim cannot imply file write');eq(r.guardian.records[1].reload_status,'Unknown','incoming success claim cannot imply reload')
eq(r.autosave.accepted,2,'request counts');eq(r.autosave.blocked_transitions,4,'block transition count retained');eq(r.autosave.blocked_reason,'phone_unknown','block reason normalized');eq(r.autosave.completion,'Unknown','scheduler never means written')
eq(r.autosave.queue_acceptances,2,'host queue acceptances distinctly labeled');eq(r.autosave.acceptance_scope,'host_queue_only','host queue is not engine submission')
eq(r.latest_failures[1],'bridge_unavailable','enumerated failure captured')
eq(report.build({autosave={reason='quest_milestone'}}).autosave.reason,'quest_milestone','supported quest request reason retained')
for _,status in ipairs({'request_submitted','request_accepted','queue_request_accepted','request_rejected','request_error','dispatching'}) do
 eq(report.build({autosave={status=status}}).autosave.status,status,'actual scheduler status '..status)
end
eq(report.build({autosave={status='request_accepted',checkpointSubmission='Verified'}}).autosave.checkpoint_submission,'Unknown','queue acceptance cannot prove checkpoint submission')
local failed=report.build({autosave={status='request_error',reason='host request failed',errors=2,resets=3},errors={}})
eq(failed.autosave.reason,'dispatch_error','actual scheduler failure reason normalized');eq(failed.autosave.errors,2,'scheduler failure counter retained')
eq(failed.autosave.resets,3,'scheduler reset counter retained');eq(failed.latest_failures[1],'dispatch_error','current scheduler failure included without separate ring')
eq(report.build({autosave={reason='player queue has priority'}}).autosave.reason,'player_queue_priority','current queued player reason retained')
eq(report.build({configWriteStatus='failed'}).latest_failures[1],'write_failed','current config failure retained')
input.settings.mode=0;eq(r.settings.effective.mode,3,'report isolated from later input mutation')
local bad={build='/home/Veil/private',gameBuild='api_key_secret',versions={cet='https://host/token',redscript=7},
 settings={mode=2,secret='password'},facts={q000_done=math.huge,q001_started='1'},sensors={combatKnown=false,combatActive=true,vehicleKnown=true,vehicleActive='false',phoneKnown=true,phoneActive=true,phoneBridgeStatus='private/path',phoneRawState=99,autosavePhoneBridgeStatus='bridge_unknown',autosavePhoneRawState=-1,autosavePhoneSource='phone_manager'},
 queue={source='C:/Users/name/save',serial=-1,session=0/0,gate='/private/secret',state='saved successfully',currentState='Saved',lastOutcomeState='Written',lastOutcomeReason='C:/private',expiresIn=1e50},
 notificationPool='Exploration | pool=0/2/2 | mode=3 | saveProtection=false /private/secret',
 errors={'C:/Users/name/save','unknown'},profileSelected=true,profileLabel='PersonalName',saveContents='secret',
 darkFuture={vehicleSleep=true,addiction=2,starvation='0',dehydration=0,lifecycle='secret'},
 guardian={records={{id='/private/password',source='PersonalName',phase='Written',reason='/private',write_status='Verified',reload_status='Verified'}}}}
local b=report.build(bad)
eq(b.reborn_build,'unknown','path build stripped');eq(b.game_build,'unknown','nonversion stripped');eq(b.dependencies.cet,'unknown','URL dependency stripped')
eq(b.settings.validation,'invalid','invalid effective settings labeled invalid');eq(next(b.settings.effective),nil,'no partial effective settings')
eq(b.facts.q000_done,'unknown','infinite fact');eq(b.facts.q001_started,'unknown','string fact not coerced')
eq(b.context.combat,'unknown','unknown sensor not promoted');eq(b.context.vehicle,'unknown','invalid Boolean not promoted');eq(b.context.phone,'active','verified active sensor');eq(b.context.phone_evidence.status,'unknown','untrusted phone evidence status stripped');eq(b.context.phone_evidence.raw_state,'unknown','out of range phone raw stripped');eq(b.context.phone_evidence.autosave_status,'bridge_unknown','allowlisted autosave phone status retained');eq(b.context.phone_evidence.autosave_raw_state,-1,'autosave unknown tri-state retained');eq(b.context.phone_evidence.autosave_source,'phone_manager','autosave phone source retained')
eq(b.queue.source,'unknown','untrusted source');eq(b.queue.serial,'unknown','negative serial');eq(b.queue.session,'unknown','NaN session');eq(b.queue.gate,'unknown','untrusted gate');eq(b.queue.state,'unknown','false completed state');eq(b.queue.current_state,'unknown','untrusted current state');eq(b.queue.last_outcome_state,'unknown','untrusted historical state');eq(b.queue.last_outcome_reason,'unknown','untrusted historical reason');eq(b.queue.expires_in,'unknown','unbounded expiry')
eq(b.notification_pool,'unknown','appended paths stripped');eq(b.dark_future.vehicle_sleep,-1,'Boolean DF not active');eq(b.dark_future.addiction,-1,'out of range DF');eq(b.dark_future.dehydration,0,'clear DF preserved')
eq(b.guardian.records[1].id,'unknown','untrusted correlation ID');eq(b.guardian.records[1].phase,'Unknown','Written phase not inferred');eq(b.presets.scope,'manual_named_settings_only','manual presets scope fixed');eq(b.saveContents,nil,'save contents omitted');eq(b.latest_failures[1],'unknown','raw failure redacted')
local crowded={guardian={records={}},errors={}}
for i=1,1000 do crowded.guardian.records[i]={id='R1-2:G1:2:'..i,phase='Requested'};crowded.errors[i]='dispatch_rejected' end
local c=report.build(crowded);eq(#c.guardian.records,12,'guardian records bounded12');eq(#c.latest_failures,8,'failures bounded8');eq(c.history_scope,'snapshot_only','snapshot not continuous logging')
local polluted=setmetatable({build='2.0'}, {__index=function() error('untrusted metamethod') end})
eq(report.build(polluted).reborn_build,'unknown','root metatable rejected')
eq(report.build({settings=setmetatable({mode=3},{})}).settings.validation,'invalid','settings metatable rejected')
eq(report.build(nil).queue.pending,'unknown','missing pending is unknown')
print('PASS support_report: '..n..' sanitization/evidence/bounding assertions')
