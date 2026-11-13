# My Epoch

*Every adventure leaves a story.*

My Epoch is a character scrapbook for **WoW Forever**. Remember the people you adventured with, the loot you found, the quests you finished, and the milestones along the way—all in a parchment book with illustrations and space for your own stories.

Each character has a separate journal. Switch between them with the character picker, revisit a day on the Calendar, or search for a particular item, companion, or memory. My Epoch accompanies the game's existing interface rather than replacing it.

## What’s in the book?

| Chapter | What you’ll find |
| --- | --- |
| **Chronicle** | Major milestones and saved equipment, stats, and skills. **Compare milestones** to see what changed, or revisit your **Personal records**. |
| **Calendar** | Select a day to read its full diary and add your own notes. Switch to Events to filter quests, loot, mobs defeated, groups, milestones, recaps, and more. Routine movement samples stay out of the event list. |
| **Recaps** | Daily, weekly, monthly, yearly, and milestone summaries of recorded activity and progress. |
| **Quests** | Completed quest history, recorded attempts, notes, and kill history. Confirmed objective credit is separate from kills recorded while a quest was active. |
| **Company** | Revisit group sessions, conversations and pull damage. Save companions to **Favorites**, keep notes, and organize them with tags and named rosters. Open a roster to invite a player. |
| **Loot** | Browse receipts, observed group drops, crafting and gathering. Follow an **Item story** or check a mob’s observed drop rates. Turn on **Floating loot** to see your own recent finds grouped by source while you play. |
| **Gold** | A dated ledger of recorded income and spending, balance charts, merchant receipts, trades, mail, auctions, and trading-cost reports. |
| **Memories** | Write a story, gather **Adventure chapters**, keep a **Wish list**, and rediscover earlier adventures with **On This Day**. Choose illustrations and attach screenshot references. Optional writing prompts help you find a starting point. |
| **Journey** | Explore recorded locations on the map and follow their links back into the journal. Death markers are hidden by default. |
| **Search** | Find records, conversations, and personal notes across the selected character’s scrapbook. Enter words and press Enter or Search; Clear removes the results. |
| **Archive** | Review storage, preview what would expire, and confirm cleanup. Shortcuts open your preferences in WoW’s AddOns settings. |

## Installation

1. Close WoW, then extract the addon ZIP.
2. Copy the **MyEpoch** folder into your Forever installation’s addon directory:

   ```text
   World of Warcraft/_forever_/Interface/AddOns/MyEpoch/
   ```

3. Check that `MyEpoch.toc` is directly inside that folder—not inside a second nested `MyEpoch` folder.
4. Start WoW Forever and enable **My Epoch** in the AddOns list.

If you downloaded this repository, copy only its inner `MyEpoch` folder into AddOns. The development tools and tests are not needed to play.

My Epoch targets **WoW Forever**. Retail and other Classic clients are not supported. No desktop companion is required; **QuestieDB** is an optional source of additional quest information.

## Languages

My Epoch supports German, French, Italian, Spanish, Brazilian Portuguese, Russian, Korean, Simplified Chinese, and Traditional Chinese. It follows your WoW client language automatically, with English as the fallback. Latin American Spanish currently shares the Spanish translation.

Translations cover all eleven chapters, their menus and filters, detailed reports, settings, and the illustration picker. Generated diaries and recaps can be presented in your current language from their recorded facts. Quest, item, location, class, spell, and skill names use the current client language when WoW can resolve their IDs, with the captured name as a fallback.

Your notes, conversations, and custom story titles stay exactly as written. Illustration titles and descriptions, older entries that only contain prose, and some external diagnostic messages may still appear in their original language.

Translations aim for the same relaxed, slightly whimsical scrapbook feel in each language, rather than matching English word for word. Suggestions from native speakers are welcome.

## Opening your book

Click the **My Epoch minimap button** or type `/myepoch` to open the book. Recording begins automatically once your character is ready, so there is no session to start manually.

- Use the left-hand bookmarks to choose a chapter and its filters.
- Select an entry to read its details on the facing page. Hover over item icons for tooltips.
- Choose **Write a memory** to add your own story, or add notes to an existing entry.
- Milestone notes offer thirteen optional writing prompts. The menu scrolls with the mouse wheel or controller, and choosing a prompt leaves your writing untouched.
- Use **Illustrations** to browse the artwork. You can set a location’s default or choose a different illustration for an individual memory or milestone.
- Open **Settings → AddOns → My Epoch** (or type `/myepoch settings`) to adjust book scale or enable combat auto-close. It is off by default; when enabled, the book reopens after combat if combat closed it.

The window fits most of your screen and keeps its size as you switch chapters. Drag its title bar to move it. You can also drag the minimap button around the minimap.

## Using a controller

My Epoch includes controller navigation for Xbox/Steam Deck, PlayStation, and Switch Pro. ImprovedForever is optional. While the book is open, use the game's UI-focus button—normally Xbox **View**, PlayStation **touchpad**, or Switch **Minus**—to take or release My Epoch's focus. The compact header icon shows the available focus key and can also be clicked. Current UI-focus remapping and explicit unbinding are respected. Release the button and center the sticks; the focus outline and header prompts show which control you can use. Switching focus preserves the current page and selection.

Assign **Focus My Epoch with controller** to open or refocus the book, or use `/myepoch focus`. **Toggle My Epoch** remains a separate open/close binding. These addon bindings start unassigned. The temporary UI-focus shortcut applies only while the open book is eligible; it does not change saved bindings. Native popups, chat entry, CompactKeyboard's visible keyboard, and supported ImprovedForever overlays take priority; finish those interactions before reclaiming the book. If input still does not reach the book, `/myepoch controller` prints the loaded version, device, focus key, capture status, and recent focus attempts for troubleshooting. `/myepoch status` also reports the loaded version; a copy older than 0.2.0 does not include controller navigation.

| Control | Action |
| --- | --- |
| D-pad or left stick | Move between controls and through grids. |
| South face button | Select or activate the focused control. |
| East face button | Go back or close the current dialog. |
| Bumpers | Switch chapters. |
| Triggers | Move between the header, bookmarks, and the two pages. |
| Right stick | Scroll the selected page. |
| West face button | Inspect a focused item or model when offered. |
| North face button | Move the book; confirm or go back to finish. |

Prompts follow your controller. The default Confirm/Back buttons are **A/B** on Xbox, **Cross/Circle** on PlayStation, and **B/A** on Switch Pro. Under **Settings → AddOns → My Epoch → Controller navigation**, you can swap Confirm and Back, choose a prompt style, or turn scrapbook navigation off. Select **Center book** on the main My Epoch settings page to reset its position. These preferences apply across characters. Mouse and keyboard remain available.

Select a text field to open the controller keyboard. It includes caret movement, selection, copy/cut/paste within My Epoch, undo, punctuation, and multiline writing. Bumpers move the caret; the west face button deletes; the north face button changes case. Notes keep their normal autosave behavior. Fields with an explicit Submit action keep that action. Back first cancels any unfinished composition, then leaves the editor; it does not undo text already saved.

Keyboard layouts cover English, German, French, Italian, Spanish, Brazilian Portuguese, Russian, Korean, and Simplified/Traditional Chinese. Korean uses two-beolsik syllable composition. Chinese uses Pinyin and a paged character picker, including optional tone numbers and `v` for `ü`; it selects individual characters rather than predicting phrases. You can change the keyboard language independently of the game language. Choose **Symbols**, then **Accents**, for accented Latin letters. Use **Literal text / codes** for case-sensitive wish codes. External clipboard paste uses your platform's paste interface; the addon's clipboard only holds text copied within My Epoch.

Controller navigation pauses during combat and while another supported controller window has input. Your normal combat auto-close setting still controls whether the book closes. Release held buttons and center the sticks before returning to the book. Screenshots and device disconnection also release controller input.

The implementation includes host and simulator checks. Actual hardware input, secure combat behavior, and cross-language font availability require validation in the Forever client; see the controller validation notes in [CONTRIBUTING.md](CONTRIBUTING.md).

## Recaps and your calendar

Calendar-period recaps become available on your first login after the period ends. For example, yesterday’s daily recap becomes available when you log in today. Level and skill milestone recaps do not wait for the next day.

All dates use **your local time**. Weeks run **Tuesday through Monday**. Daily recaps appear on the Calendar day they describe; weekly, monthly, and yearly recaps appear on the period’s last day.

Generated summaries stay separate from your editable notes. Recorded active-play time excludes recorded AFK time.

The Calendar holds its page steady while you read or write. Its daily summary includes distance traveled in estimated yards when travel was recorded. Activity keeps recording in the background; select a day again or reopen the book to see the latest entries.

## Chapters, wishes, and little celebrations

In **Memories → Adventure chapters**, collect entries by hand or choose a date range and filters. An open chapter keeps gathering matching entries. **Seal chapter** freezes its selection; you can still edit it or reopen it later. Add a cover illustration and your own notes. Sealing does not protect entries from your retention rules—star the chapter to protect its linked sources.

In **Memories → Wish list**, write a personal goal or track levels, skill ranks, items, crafting, gathering, quests, and places. Goals start counting from creation unless you choose to include recorded history. Completing a wish keeps a linked memory, and manual completion is available too.

Use **Share a wish list** to copy a share code for a friend. Notes are included unless you turn that option off. Your friend can choose **Bring in a friend’s wishes**, paste the code, and review it before importing. Imported wishes start fresh: your progress, character identity, and completion memories stay yours.

**Chronicle → Personal records** quietly keeps your best recorded days and death-free stretches. Choose the categories to track in **Settings → AddOns → My Epoch → Personal records**. Missing prices, costs, or recording time remain unknown. Item stories describe recorded appearances and transactions, without claiming that two identical items are the same physical copy.

Major milestones, completed wishes, and newly available recaps can show a small parchment notification. Notifications wait until combat ends and never open the book by themselves. Under **Settings → AddOns → My Epoch**, the two **Notifications** pages let you set account defaults or override them for an individual character. You can turn notifications off, choose categories, adjust sound, or change their position. Turning notifications off does not stop recording or remove unread indicators.

A major milestone and its written recap share one notification. A level or skill milestone shows the rank you reached, such as **Cooking 75**. The toast fades during its final second. Hover over it to keep it on screen while you read. Daily, weekly, monthly, and yearly recaps have their own notifications.

Under **Settings → AddOns → My Epoch**, enable **Show floating loot** to keep recent finds visible with the book closed. With a controller, highlight **My Epoch** and press **D-pad Right** to enter its settings. The tracker looks back **24 hours** by default; an existing saved duration is kept. Choose a preset or use the minutes slider for any duration from 1 to 1,440 minutes. Drag the tracker title to move it. The **Settings for character** selector lets you adjust a different journal without switching your active tracker.

Click a mob or source name to fold or unfold its loot. The header counts every item you received from that source during the selected period. Underneath, each item has one icon with its total quantity. Hover over an icon for its item tooltip. Each character remembers which sources you folded.

Under **Company → Companions**, open a player and choose **Add to favorites**. In **Company → Favorites**, give companions a shared tag such as *Raid* and assign them to rosters such as *Raid 1* or *Raid 2*. Choose a roster, select a player, and click **Invite** beside their name to send that player an invitation.

Open the game's **Edit Mode** to move the **My Epoch notifications** area, or select **Move notifications in Edit Mode** in My Epoch’s notification settings. Drag the area or use its direction buttons, then choose **Apply position**. **Reset position** previews the default location; Apply saves it. **Cancel position** or leaving Edit Mode discards unapplied changes. The position follows account defaults unless this character uses an override. During positioning, queued notifications and the current toast's remaining time are preserved. Controller users can also use the position sliders in WoW’s AddOns settings; native Edit Mode keeps ownership of controller input.

## Capturing a moment

Choose **Capture a moment**, or use the capture action on a memory or milestone. My Epoch briefly hides the scrapbook, requests a screenshot, then restores the book.

The actual image stays in WoW’s **Screenshots** folder. The scrapbook can keep screenshot references and captions alongside your memories, but it cannot import or display those screenshot files inside the game. Use the bundled illustrations to decorate the pages themselves.

## Understanding your records

My Epoch records what your character can observe while the addon is running. It cannot reconstruct a complete history from before installation or fill in activity it did not see. Some older quest completions may be available without a known completion date.

Mob drop rates use **kills with an observed item drop ÷ recorded kills of that mob**, including source-linked group loot. Item quantity is shown separately, so stacks and reopened corpses do not inflate the percentage. These are your recorded results, not guaranteed drop chances; unlinked drops are excluded from the rate.

Open a recorded defeat to see **Loot from this defeat**: one encounter containing all its linked items. This works for kills throughout the book, including solo adventures. When the creature cannot be identified directly, My Epoch can use nearby recorded kill and loot activity to suggest an **approximate match**. Open **Loot encounter details** to dismiss a suggestion or restore one you dismissed. Approximate matches do not count as confirmed quest credit or enter the exact mob drop-rate calculation.

In **Chronicle → Compare milestones**, browse major milestones by category and compare their saved gear on matching character panels. Changed equipment is highlighted, item tooltips still work, and the two pages scroll together. The gear preview uses your current appearance when you are logged in as that character.

Gold and item-value reports distinguish actual money changes from estimated item values. Unknown costs remain unknown, and inferred associations are labeled. Group chat and damage history depend on what the client makes available to your character.

## Keeping your memories

History is kept **forever by default**. In **Settings → AddOns → My Epoch → How long to remember**, you can set retention rules separately for each character and category. Open **Archive** in the scrapbook to review affected entries and confirm manual cleanup. Starred memories and their linked source records are protected from routine cleanup.

To keep the journal light, a full character snapshot (gear, stats, and skills) is saved with level-ups and other major milestones, including every 25 weapon or 75 profession skill points. Single skill points still record their old and new ranks. Older ordinary fights keep their sources and damage totals; the per-spell breakdown stays for boss encounters, starred or noted fights, fights linked to a memory, and your 50 most recent fights.

Your journal is stored locally in WoW’s SavedVariables. WoW writes those files during its normal reload/logout process; a crash can lose recent unsaved activity. To back up your scrapbook, close the game and copy:

```text
_forever_/WTF/Account/<your-account>/SavedVariables/MyEpoch.lua
```

Keep your backups outside the addon folder. Updating the addon does not require deleting your saved journal.

Closing the book releases temporary browsing catalogs, page data, and controller-editor buffers. Milestone recording, automatic recaps and notifications continue with the book closed; completed writing keeps its saved result and releases temporary compilation data. Saved history, unfinished writing, and the internal clipboard are preserved. Some pages briefly prepare their contents again when reopened. WoW reclaims released memory during its normal garbage collection, so the memory counter may not drop immediately; saved history still uses memory while the addon is loaded.

Wallet recording pauses during logout and world transitions, when the client may report an unavailable balance as zero. The Gold balance chart leaves a gap with a notice for older session-ending zero readings that cannot be verified. These gaps do not rewrite saved transactions or cash-flow totals; genuine observed zero balances remain valid.

## Commands

| Command | Action |
| --- | --- |
| `/myepoch` or `/epoch` | Open or close the scrapbook. |
| `/myepoch settings` | Open My Epoch in WoW’s AddOns settings. |
| `/myepoch focus` | Open or refocus the book for controller navigation. |
| `/myepoch controller` | Report controller detection, focus, and input-capture status. |
| `/myepoch close` | Close the book and cancel a pending automatic reopen after combat. |
| `/myepoch capture` | Capture a moment. |
| `/myepoch minimap hide` | Hide the minimap button. |
| `/myepoch minimap show` | Restore the minimap button. |
| `/myepoch status` | Show the addon version, client build, and recording status for troubleshooting. |

## Need help?

My Epoch is still in active development. If something looks wrong, include your addon version, the output of `/myepoch status`, the chapter involved, and the steps that led to the problem. A screenshot or the first Lua error is helpful too.

If the book does not open, check that My Epoch is enabled and that the folder contains `MyEpoch.toc`, then restart the game. After updating an already loaded addon, use `/reload` to load the new version.
