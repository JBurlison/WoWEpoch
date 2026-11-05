local _,E=...
local V,B,R,A,T={},E.Book,E.Archive,E.API,E.BookTheme;E.ArchiveView=V
for _,pair in ipairs({{"archiveControl","calendarControl"},{"archiveStat","calendarStat"},{"archivePaper","calendarPanel"},{"archiveRow","questRow"}})do B.widgetFactories[pair[1]]=B.widgetFactories[pair[2]]end
local function controls(page,rows,columns)
    if B.Navigation.Grid(page,rows,columns)then return end
    columns=columns or 3;local y=page.y;local w=(B.Width(page)-(columns-1)*8)/columns
    for i,r in ipairs(rows)do local f=B.Acquire(page,"archiveControl")
        f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+((i-1)%columns)*(w+8),-y-math.floor((i-1)/columns)*38)
        f:SetSize(w,32);f.text:SetWidth(w-12);f.text:SetText(E.Text(r[1]));T.ButtonStyle(f,r[3]and"filter"or nil);f:SetScript("OnClick",r[2])
    end;page.y=y+math.ceil(#rows/columns)*38
end
local function heading(page,kicker,title)
    B.Text(page,kicker,11):SetTextColor(.54,.40,.23);B.Text(page,title,29)
end
local function paper(page,title,text)
    local start=page.y;local panel=B.Acquire(page,"archivePaper");panel:SetWidth(B.Width(page));page.y=start+20
    for i,body in ipairs({title,text})do local y=page.y;local size=i==1 and 22 or 16;local f=B.Text(page,body,size)
        f:SetWidth(B.Width(page)-48);f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",36,-y)
        local h=math.max(size,f:GetStringHeight());f:SetHeight(h);page.y=y+h+14
    end
    page.y=page.y+10;panel:SetHeight(page.y-start);page.y=page.y+18
end
local function stats(page,rows)
    if #rows==0 then return end
    local y=page.y;local w=B.Width(page)/#rows
    for i,r in ipairs(rows)do local f=B.Acquire(page,"archiveStat")
        f:ClearAllPoints();f:SetPoint("TOPLEFT",page.content,"TOPLEFT",12+(i-1)*w,-y);f:SetSize(w-10,70)
        f.value:SetWidth(w-10);f.value:SetText(r[1]);f.caption:SetWidth(w-10);f.caption:SetText(r[2])
    end;page.y=y+80
end
local function card(page,title,status,detail,action)
    local f=B.Acquire(page,"archiveRow");f:SetWidth(B.Width(page));f.text:SetText(E.Text(title));f.status:SetText(E.Text(status or""))
    f.meta:SetFont(E.Font(),13,"");f.meta:SetText(E.Text(detail or""))
    local h=math.max(f.text:GetStringHeight(),f.status:GetStringHeight());f.meta:ClearAllPoints();f.meta:SetPoint("TOPLEFT",12,-h-20)
    f:SetHeight(math.max(78,h+f.meta:GetStringHeight()+38));f.tint:SetAlpha(0);f.accent:SetAlpha(0)
    f:GetHighlightTexture():SetAlpha(action and .08 or 0);f:SetScript("OnClick",action);page.y=page.y+f:GetHeight();return f
end
local function pages(page,rows,key,size,render)
    local count=math.max(1,math.ceil(#rows/size));B[key]=math.max(1,math.min(B[key]or 1,count))
    if count>1 then B.Text(page,"Page "..B[key].." of "..count,12)end
    for i=(B[key]-1)*size+1,math.min(#rows,B[key]*size)do render(rows[i])end
    local buttons={}
    if B[key]>1 then buttons[#buttons+1]={"Previous page",function()B[key]=B[key]-1;B.Render(true)end}end
    if B[key]<count then buttons[#buttons+1]={"Next page",function()B[key]=B[key]+1;B.Render(true)end}end
    if #buttons>0 then page.y=page.y+10;controls(page,buttons,2)end
end
local function finiteDays(value)return type(value)=="number"and value>0 and value<math.huge end
local pending=setmetatable({},{__mode='k'})
local function policy(page,c,row)
    B.Text(page,'Retention for this character only',18)
    local function save(days)
        local ok,reason=R.Configure(c,row.key,days)
        B.archiveMessage=ok and'Policy saved. No history was removed.'or reason
        if ok then pending[c]=nil;B.archivePolicyDrafts=B.archivePolicyDrafts or{};B.archivePolicyDrafts[row.key]=nil end
        B.Render()
    end
    local options={};for _,choice in ipairs({{'Forever',false},{'7 days',7},{'30 days',30},{'90 days',90},{'1 year (365 days)',365}})do
        local days=choice[2];options[#options+1]={choice[1],function()save(days or nil)end,row.days== (days or nil)}
    end;controls(page,options,3)
    B.Text(page,'Custom whole days (1–36500), then press Enter:',13)
    B.archivePolicyDrafts=B.archivePolicyDrafts or{}
    local edit=B.Input(page,B.archivePolicyDrafts[row.key]or'',function(value)
        local days=tonumber(value)
        if not days then B.archiveMessage='Enter whole days from 1 to 36500, or choose Forever.';B.Render();return end
        save(days)
    end)
    edit:SetScript('OnTextChanged',function(self,user)if user then B.archivePolicyDrafts[row.key]=self:GetText()end end)
    if row.personalNotes then B.Text(page,'Personal notes expire by their last edit time, independently of generated summaries. Notes linked to protected records stay protected. Undated notes remain retained.',13)end
end
local function settings(left)
    controls(left,{{B.archiveSettingsOpen and"Hide book settings"or"Book settings",function()B.archiveSettingsOpen=not B.archiveSettingsOpen;B.Render()end,B.archiveSettingsOpen}},2)
    if not B.archiveSettingsOpen then return end
    B.Text(left,"Book scale: "..math.floor(E.db.settings.scale*100+.5).."% of automatic fit",14)
    local function scale(value)E.db.settings.scale=math.max(.65,math.min(1,value));B.Fit();B.Render()end
    controls(left,{{"Make book smaller",function()scale(E.db.settings.scale-.05)end},{"Make book larger",function()scale(E.db.settings.scale+.05)end},{"Reset book scale",function()scale(1)end}})
    controls(left,{{"Combat auto-close: "..(E.db.settings.combatClose and"on"or"off"),function()B.SetCombatClose(not E.db.settings.combatClose);B.Render()end,E.db.settings.combatClose}},1)
    B.Text(left,"Combat auto-close starts off. When enabled, the book reopens after combat only if combat closed it. These book settings apply across characters.",13)
end
function V.Render(left,right)
    local c=B.Character();B.archiveTab=B.archiveTab or"retention";V.lastReview=nil
    local account=B.archiveTab=="accountStorage"
    local storage=account or B.archiveTab=="storage"
    local subject=account and E.db or c
    heading(left,"CHAPTER XI - KEEP THE STORY SAFE","The archive")
    B.Text(left,"Your history stays until you choose otherwise. Every category begins at Forever.",15)
    if R.saveSizeWarning then paper(left,"Archive save warning",R.saveSizeWarning)end
    local tabs={};for _,tab in ipairs({{"retention","Retention review"},{"storage","Archive size"},{"accountStorage","Account archive size"},{"capabilities","Recording status"}})do local key=tab[1]
        tabs[#tabs+1]={tab[2],function()B.archiveTab=key;B.selected=nil;B.Render(true)end,B.archiveTab==key}
    end;B.Navigation.Subviews(tabs)
    if storage then
        paper(left,"A growing collection.",account and "All character scrapbooks and shared book settings are saved together. Measure the whole collection while recording continues." or "Measure this character's saved history in small batches while recording continues.")
        controls(left,{{account and "Measure the account again" or "Measure this character again",function()R.Start(subject);B.Render()end}},1)
    elseif B.archiveTab=="capabilities"then
        paper(left,"Every page has a source.","Recording coverage belongs with each memory. Unknown sources, inaccessible conversations and unobserved activity stay visibly unknown.")
        B.Text(left,"These are recording-system diagnostics from this running session. They do not establish complete historical coverage for the selected character.",14)
    else
        paper(left,"Keep the story safe.","Starring a memory protects that memory and its linked sources. Group conversations, loot and other supporting records remain part of its story.")
        B.Text(left,"Review this character's categories, age cutoffs and protected sources before choosing a cleanup policy.",15)
        B.Text(left,'Policies apply only to '..(c.identity.name or c.id)..'. Saving a policy does not immediately remove history.',13)
        controls(left,{{'Review cleanup',function()pending[c]=nil;R.StartReview(c,A.Now(),true);B.archiveMessage=nil;B.Render(true)end},
            {'Refresh review',function()pending[c]=nil;R.StartReview(c,A.Now());B.archiveMessage=nil;B.Render(true)end}},2)
        controls(left,{{'Automatic cleanup: '..(c.state.retentionAutomatic and'on'or'off'),function()
            R.SetAutomatic(c,not c.state.retentionAutomatic);pending[c]=nil;B.archiveMessage=nil;B.Render()
        end,c.state.retentionAutomatic}},1)
        B.Text(left,'Automatic cleanup starts off. When enabled, this character is checked once per local day while logged in, out of combat, with the book closed. Finite policies permanently expire eligible history and notes. Unknown combat state defers cleanup.',13)
        if B.archiveMessage then B.Text(left,B.archiveMessage,14)end
    end
    left.y=left.y+10;settings(left);left.y=left.y+10
    B.Text(left,"Keep the story, even without the picture.",20)
    B.Text(left,"Screenshot references preserve time, context and captions. They do not manage image files on disk, and newly captured images may be unavailable inside the book.",14)
    if B.selected then return end
    if storage then
        if not R.results[subject]and not R.interrupted[subject]and not(R.worker and R.worker.c==subject)then R.Start(subject)end
        heading(right,account and "ACCOUNT COLLECTION" or "A CHARACTER'S COLLECTION",account and "All saved scrapbooks" or "Your saved pages")
        local out=R.results[subject]
        if R.interrupted[subject]then B.Text(right,"Measurement stopped because the history changed. Measure again to retry.",14)end
        if R.worker and R.worker.c==subject then B.Text(right,out and"Measuring again; the previous completed estimate is shown below."or"Measuring your history in small batches…",14)end
        if not out then if not R.interrupted[subject]then B.Text(right,"The result will appear when the scan finishes.",15)end;return end
        local values={{R.Bytes(out.bytes),"ESTIMATED LUA TEXT"}}
        if account and out.characters>0 then values[#values+1]={E.Number(out.characters),"SCRAPBOOKS"}end
        if out.records>0 then values[#values+1]={tostring(out.records),"JOURNAL RECORDS"}end
        if out.notes>0 then values[#values+1]={tostring(out.notes),"PERSONAL NOTES"}end
        stats(right,values)
        B.Text(right,account and "Estimate across the account during this scan, including shared settings. The game can reach its Lua loading limit as distinct entries accumulate. File size alone cannot predict that limit." or "Per-character Lua text estimate. SavedVariables file size and runtime memory differ. Images and transient UI data are excluded.",13)
        if out.unavailable>0 then B.Text(right,"Incomplete estimate: some values could not be measured.",14)end
        B.Text(right,"Measured "..A.Date(out.finished),13)
        if out.changed or subject.revision~=out.revision then B.Text(right,"Recording changed during or since this measurement. Measure again for a newer estimate.",13)end
        pages(right,R.Rows(out),account and "archiveAccountSizePage" or "archiveSizePage",6,function(row)
            local parts={};if row.records>0 then parts[#parts+1]=row.records..(row.records==1 and" record"or" records")end;if row.notes>0 then parts[#parts+1]=row.notes..(row.notes==1 and" note"or" notes")end
            card(right,row.label,R.Bytes(row.bytes),table.concat(parts," / "))
        end)
        B.Text(right,"Forever means no automatic expiry. Available memory and crash recovery still depend on the client; no silent cap or purge is applied.",13)
    elseif B.archiveTab=="capabilities"then
        heading(right,"RECORDING COVERAGE","What the book can observe")
        local keys=E.SortedKeys(A.status)
        if #keys==0 then B.Text(right,"No recording diagnostics are available yet.",15)end
        pages(right,keys,"archiveStatusPage",8,function(key)card(right,key,"",A.status[key])end)
        B.Text(right,"Available details depend on the events and fields the client exposes during play.",13)
    else
        local cleanup=R.cleanupWorker
        if cleanup and cleanup.c==c and not cleanup.automatic then
            heading(right,'KEEP THE STORY SAFE','Checking reviewed history')
            B.Text(right,'Rechecking protected sources and personal notes in small batches before removing the reviewed history.',16)
            controls(right,{{'Cancel cleanup',function()R.CancelCleanup(c);B.Render(true)end}},2)
            return
        end
        local worker=R.reviewWorker
        if worker and worker.c==c then
            heading(right,'KEEP THE STORY SAFE','Reviewing your history')
            B.Text(right,'Checking categories and protected sources in small batches. Nothing is removed during this review.',16)
            controls(right,{{'Cancel review',function()R.CancelReview(c,'Review cancelled. Refresh review to restart.');pending[c]=nil;B.Render(true)end}},2)
            return
        end
        local review=pending[c]
        if review then
            heading(right,'REVIEW BEFORE REMOVING','Cleanup for '..(c.identity.name or c.id))
            local p=review.preview
            B.Text(right,'Reviewed '..A.Date(p.at)..'. This permanently removes '..p.count..' recorded entries and '..p.noteCount..' personal notes. Removed data cannot be restored by choosing Forever.',15)
            for _,row in ipairs(review.rows)do if #row.eligible>0 then B.Text(right,row.label..': '..#row.eligible,14)end end
            B.Text(right,'Stars, linked sources, active records and FIFO accounting history remain protected. Cleanup leaves a dated coverage record.',13)
            local options={{'Cancel review',function()pending[c]=nil;B.Render(true)end}}
            if p.count+p.noteCount>0 then options[#options+1]={'Remove reviewed history',function()
                local job=R.StartCleanup(c,p);pending[c]=nil;B.archiveMessage=job and nil or'Cleanup could not start. Review cleanup again.';B.Render(true)
            end}end
            controls(right,options,2);return
        end
        local report=R.ReviewFor(c);V.lastReview=report
        if not report then
            heading(right,'KEEP THE STORY SAFE','Reviewing your history')
            B.Text(right,R.reviewFailures[c]or'Checking categories and protected sources in small batches. The report will appear when it is ready.',16)
            if R.reviewWorker and R.reviewWorker.c==c then
                controls(right,{{'Cancel review',function()R.CancelReview(c,'Review cancelled. Refresh review to restart.');B.Render(true)end}},2)
            end
            return
        end
        B.Text(right,'Reviewed '..A.Date(report.preview.at)..'. Refresh review to update the age cutoffs.',12)
        local row=B.archiveCategory and report.groups[B.archiveCategory]
        if not row then
            heading(right,"KEEP BY DEFAULT - REVIEW BY CATEGORY","How long to remember")
            local finite=0;for _,r in ipairs(report.rows)do if finiteDays(r.days)then finite=finite+1 end end
            B.Text(right,finite>0 and finite..(finite==1 and" category has"or" categories have").." a finite saved policy. Review does not apply cleanup."or"All categories: Forever / No automatic expiry",15)
            pages(right,report.rows,"archiveCategoryPage",6,function(r)
                local parts={"Open category review"};if r.total>0 then parts[#parts+1]=r.total..(r.total==1 and" recorded entry"or" recorded entries")end
                card(right,r.label,finiteDays(r.days)and r.days.." days"or"Forever",table.concat(parts," / "),function()B.archiveCategory=r.key;B.archiveProtected=false;B.archiveRecordPage=1;B.Render(true)end)
            end)
            B.Text(right,'Personal daily, recap and other notes have separate policies. All begin at Forever.',13);return
        end
        heading(right,"BEFORE ANYTHING EXPIRES",row.label)
        controls(right,{{"All categories",function()B.archiveCategory=nil;B.selected=nil;B.Render(true)end}},2)
        policy(right,c,row)
        B.Text(right,finiteDays(row.days)and"Rolling cutoff: "..A.Date(report.preview.at-row.days*86400).." (local time; each day is 24 hours)."or"Forever: no records in this category are eligible for age-based expiry.",14)
        local values={};if row.total>0 then values[#values+1]={tostring(row.total),"RECORDED ENTRIES"}end
        if #row.eligible>0 then values[#values+1]={tostring(#row.eligible),"ELIGIBLE FOR EXPIRY"}end
        if #row.protected>0 then values[#values+1]={tostring(#row.protected),"OLDER, PROTECTED"}end
        stats(right,values)
        B.Text(right,"Stars, linked sources, active recording state and records needed by retained entries remain protected.",13)
        if row.key=="gold"then B.Text(right,"FIFO lots, sales, returns and inventory movements stay protected together so cleanup cannot change cost calculations.",13)end
        controls(right,{{"Eligible records",function()B.archiveProtected=false;B.archiveRecordPage=1;B.Render(true)end,not B.archiveProtected},{"Protected records",function()B.archiveProtected=true;B.archiveRecordPage=1;B.Render(true)end,B.archiveProtected}},2)
        local rows=B.archiveProtected and row.protected or row.eligible
        pages(right,rows,"archiveRecordPage",8,function(r)
            card(right,r.title or r.kind,A.RecordDate(r),B.archiveProtected and R.Reason(c,(r.noteKey and report.preview.noteReasons or report.preview.reasons)[r.id])or"Older than the saved category cutoff",function()
                if r.noteKey then B.chapter='Search';B.selected=nil;B.searchNoteKey=r.noteKey else B.selected=r.id end
                B.Render(true)
            end)
        end)
        if #rows==0 then B.Text(right,B.archiveProtected and"No older protected records to list."or"No eligible records to list.",15)end
        B.Text(right,"Cleanup can change statistics and leave coverage gaps. Returning a policy to Forever prevents later expiry; it cannot recover removed data.",13)
    end
end
E.On("ARCHIVE_SAVE_WARNING",function()
    if B.frame and B.frame:IsShown() and B.chapter=="Archive" then B.Render() end
end)
E.On("ARCHIVE_MEASURED",function(c)
    if B.frame and B.frame:IsShown()and B.chapter=="Archive"and
        ((B.Character()==c and B.archiveTab=="storage")or(c==E.db and B.archiveTab=="accountStorage"))then B.Render()end
end)
E.On('ARCHIVE_REVIEWED',function(c,report,confirm)
    if confirm and report then pending[c]=report end
    if B.frame and B.frame:IsShown()and B.chapter=='Archive'and B.Character()==c and B.archiveTab=='retention'then B.Render()end
end)
E.On('ARCHIVE_CLEANED',function(c,ok,message,automatic)
    pending[c]=nil
    if not automatic and B.Character()==c then
        B.archiveMessage=message
        if B.frame and B.frame:IsShown()and B.chapter=='Archive'then B.Render()end
    end
end)
