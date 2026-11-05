# My Epoch

*Every adventure leaves a story.*

My Epoch is a character scrapbook for **WoW Forever**. Remember the people you adventured with, the loot you found, the quests you finished, and the milestones along the way—all in a parchment book with illustrations and space for your own stories.

Each character has a separate journal. Switch between them with the character picker, revisit a day on the Calendar, or search for a particular item, companion, or memory. My Epoch accompanies the game's existing interface rather than replacing it.

## What’s in the book?

| Chapter | What you’ll find |
| --- | --- |
| **Chronicle** | Your character’s major milestones: levels, achievements, first discoveries and completions, and profession or weapon-skill thresholds. Milestones can include saved equipment, stats, and skills. |
| **Calendar** | A day-by-day view of your adventures, with links to groups, quests, loot, milestones, and recaps. Read the daily diary and add your own notes. |
| **Recaps** | Daily, weekly, monthly, yearly, and milestone summaries of recorded activity and progress. |
| **Quests** | Completed quest history, recorded attempts, notes, and kill history. Confirmed objective credit is separate from kills recorded while a quest was active. |
| **Company** | Group sessions, companions, shared activity, recorded conversations, and available pull damage details. Open a whisper or add a companion as a friend. |
| **Loot** | Item receipts, observed group drops, crafting and gathering records, and filters for exploring your finds. Mob reports show observed drop rates, kill counts, and item quantities. |
| **Gold** | A dated ledger of recorded income and spending, balance charts, merchant receipts, trades, mail, auctions, and trading-cost reports. |
| **Memories** | Write a story, save a quote, choose an illustration, attach screenshot references, and rediscover earlier adventures with **On This Day**. |
| **Journey** | Explore recorded locations on the map and follow their links back into the journal. Death markers are hidden by default. |
| **Search** | Find records, conversations, and personal notes across the selected character’s scrapbook. |
| **Archive** | Adjust the book’s size and combat behavior, review storage, and choose how long each character’s history is kept. |

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

## Your first adventure

Click the **My Epoch minimap button** or type `/myepoch` to open the book. Recording begins automatically once your character is ready, so there is no session to start manually.

- Use the left-hand bookmarks to choose a chapter and its filters.
- Select an entry to read its details on the facing page. Hover over item icons for tooltips.
- Choose **Write a memory** to add your own story, or add notes to an existing entry.
- Use **Illustrations** to browse the artwork. You can set a location’s default or choose a different illustration for an individual memory or milestone.
- Open **Archive** to adjust scale or enable combat auto-close. It is off by default; when enabled, the book reopens after combat if combat closed it.

The window fits most of your screen and keeps its size as you switch chapters. Drag its title bar to move it. You can also drag the minimap button around the minimap.

## Recaps and your calendar

Calendar-period recaps are saved quietly on your first login after the period ends. For example, yesterday’s daily recap becomes available when you log in today. Level and skill milestone recaps do not wait for the next day.

All dates use **your local time**. Weeks run **Tuesday through Monday**. Daily recaps appear on the Calendar day they describe; weekly, monthly, and yearly recaps appear on the period’s last day.

Generated summaries stay separate from your editable notes. Recorded active-play time excludes recorded AFK time.

## Capturing a moment

Choose **Capture a moment**, or use the capture action on a memory or milestone. My Epoch briefly hides the scrapbook, requests a screenshot, then restores the book.

The actual image stays in WoW’s **Screenshots** folder. The scrapbook can keep screenshot references and captions alongside your memories, but it cannot import or display those screenshot files inside the game. Use the bundled illustrations to decorate the pages themselves.

## Understanding your records

My Epoch records what your character can observe while the addon is running. It cannot reconstruct a complete history from before installation or fill in activity it did not see. Some older quest completions may be available without a known completion date.

Mob drop rates use **kills with an observed item drop ÷ recorded kills of that mob**, including source-linked group loot. Item quantity is shown separately, so stacks and reopened corpses do not inflate the percentage. These are your recorded results, not guaranteed drop chances; unlinked drops are excluded from the rate.

Gold and item-value reports distinguish actual money changes from estimated item values. Unknown costs remain unknown, and inferred associations are labeled. Group chat and damage history depend on what the client makes available to your character.

## Keeping your memories

History is kept **forever by default**. In **Archive**, you can set retention rules separately for each character and category. Starred memories and their linked source records are protected from routine cleanup.

Your journal is stored locally in WoW’s SavedVariables. WoW writes those files during its normal reload/logout process; a crash can lose recent unsaved activity. To back up your scrapbook, close the game and copy:

```text
_forever_/WTF/Account/<your-account>/SavedVariables/MyEpoch.lua
```

Keep your backups outside the addon folder. Updating the addon does not require deleting your saved journal.

## Commands

| Command | Action |
| --- | --- |
| `/myepoch` or `/epoch` | Open or close the scrapbook. |
| `/myepoch close` | Close the book and cancel a pending automatic reopen after combat. |
| `/myepoch capture` | Capture a moment. |
| `/myepoch minimap hide` | Hide the minimap button. |
| `/myepoch minimap show` | Restore the minimap button. |
| `/myepoch status` | Show the addon version, client build, and recording status for troubleshooting. |

## Need help?

My Epoch is still in active development. If something looks wrong, include your addon version, the output of `/myepoch status`, the chapter involved, and the steps that led to the problem. A screenshot or the first Lua error is helpful too.

If the book does not open, check that My Epoch is enabled and that the folder contains `MyEpoch.toc`, then restart the game. After updating an already loaded addon, use `/reload` to load the new version.
