# Eight hours of choosing what to research

On 20 November 2026, from 00:14 to 08:14 JST, Dighouse ran in the Mac app on primary 6.2 SOL with High thinking. Its task was to choose areas worth sustained lidar research. It chose its own areas and tests. A coordinator watched the session and stepped in five times. The changes and short replays described below followed that run.

## What the session produced

Dighouse saved 67 passes across 12 project and calibration records, with 244 tile verdicts and 83 find files. Those counts include controls and repeat flights. The app reported 57 advisory suggestions, 26 finds awaiting a suggestion, zero independent model opinions and zero human decisions. At Perry Mesa, two readings by the same model both classified a modern stock-tank berm as likely archaeological. That example matters when interpreting the volume of output.

The original assessment ranked Cahokia first and El Tiradero second. Cahokia offered unusually good evidence for testing repeatability. The same three mapped Ramey Field mounds fell within 4.1 m of predicted positions on each of three flights. That answers a practical question about locating known features. It leaves open what another pass would teach an archaeologist about Cahokia.

At El Tiradero, once the coordinator supplied the published maps, Dighouse aligned them to the terrain and predicted two withheld landmarks within about 3 m and 6 m. Lower Lacantún yielded a different kind of lead. Two profiles across a field-described basin measured depths of 1.46 m and 1.50 m. Comparison with a naturally incised channel and an independently mapped water feature could help assess the interpretation. The run established a measurable shape; its origin remains open.

## Where the coordinator intervened

| During the run | Change made afterward |
| --- | --- |
| A research turn was already running when the coordinator tried to attach the deadline. They requested a checkpoint and set the goal between turns. | The timed workflow sets the goal and deadline before research begins. |
| A provider 429 stopped progress for 9 min 31 s. The coordinator restarted the same goal on the same account. The specific limit was unresolved. | Timed sessions retain their thread, model and deadline and retry transient throttling with backoff. Explicit quota exhaustion and a user stop are handled separately. |
| After 23 passes the coordinator asked which observation would change the decision to pursue a project. | The workflow asks for the closest prior study, competing interpretations, a decisive observation and the best alternative use of the next pass. Recommendations distinguish benchmarks, open questions and deferred work. |
| The coordinator retrieved two original El Tiradero PDFs and rendered the maps the text reader had missed. | The source tools retain PDFs privately, render a requested page, and record text access, figure inspection and map registration separately. |
| Ten minutes before the deadline the coordinator requested final checks and a ranked assessment. | The timer reserves time for closeout. The workflow requests the outstanding human decisions and can save a reusable lesson in the project's methodology. |

The app recovered from a download timeout and a shared-cache error on its own. It also corrected a coordinate-datum mismatch and rejected catalog overlaps after checking the actual coverage.

## What the three replays established

1. **Cahokia research selection.** In a replay without supplied paper titles, the model consulted Fowler's atlas and West Plaza excavation work and identified a recent lidar detection study. It could verify only part of that study. It deferred sustained work and proposed one archive pass to establish whether West Plaza had already been tested and whether the old survey grid could place a held-out target accurately. Mounds 43 and 91 would be known controls, with cultivation-altered Mound 44 as a comparison. The replay acquired no new terrain.
2. **El Tiradero source access.** Starting with the original citations, the model inspected page 7 of Feria Cuevas (2015) and page 9 of Pinzón et al. (2022). It identified the site-plan footprints and the labeled excavations and scale bar, and logged both pages without coordinator-supplied copies. It correctly left terrain registration unverified in this replay. [Feria Cuevas, figure 2](https://www.mesoweb.com/Simposio/pdf/28/Feria.2015.pdf#page=7) · [Pinzón et al., figure 2](https://www.mesoweb.com/Simposio/pdf/34/Pinzon_et_al.2022.pdf#page=9)
3. **Timed recovery.** A native timer test injected a 429, observed the 16-second retry delay, resumed the original thread, requested closeout and interrupted unfinished work at the original deadline. Separate tests covered restored state and explicit cancellation. This used a simulated provider and a shortened clock. [Timer tests](../app/Tests/DighouseTests/TimedResearchTests.swift)

## What to test next

Run the rebuilt app once for eight hours with the coordinator observing. Record the time and reason for every intervention. Check whether the app saves a ranked assessment before the deadline on its own. For each promoted area, have a reviewer read the closest study and identify the specific remaining question and the observation that could change its interpretation. An assessment containing only benchmarks and deferred areas is a valid outcome.

The short replays exercised the individual fixes. Full-session recovery, closeout quality, and research judgment across unfamiliar areas still need that unattended run. Use any repeated intervention or unsupported promotion to choose the next product change.
