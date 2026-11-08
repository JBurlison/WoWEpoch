local _,E=...
-- Called only after a genuine journal close has detached widget callbacks.
-- Recording indexes, financial readers, enrichment and saved history stay live.
local modules={'ChapterView','Chapters','WishView','KeepsakeView','JourneyView','Journey','CompanyLayout','Company','ItemStoryView','ItemStories','DiaryPresentation','MobDropView','MemoryView','SavedPages'}
function E.ReleaseJournalViewCaches()
    local navigation=E.Book and E.Book.Navigation
    if navigation and type(navigation.ReleaseView)=='function'then navigation.ReleaseView()end
    for _,name in ipairs(modules)do
        local module=E[name]
        if module and type(module.ReleaseView)=='function'then module.ReleaseView()end
    end
end
