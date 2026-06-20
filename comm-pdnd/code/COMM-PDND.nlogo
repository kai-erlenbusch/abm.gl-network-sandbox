extensions [ nw ]

breed [comm-objects comm-object]
breed [comm-subjects comm-subject]

undirected-link-breed [ undirected-edges undirected-edge ]
undirected-link-breed [ object-links object-link ]

comm-subjects-own [ norm-perception bc-level motivation activation-phase sorted-objects norm-cue-sum extremist? original-norm-perception original-motivation adaption-value deviance?]
comm-objects-own [ age norm-cue reception-frequency p-values reception-growth? reception-growth]

globals [
  selected-comm-subjects

  selected
  current-omega
  current-epsilon
  current_min_norm
  current_max_norm
  current_alpha
  current_beta

  highlighted-node
  highlight-bicomponents-on
  stop-highlight-bicomponents
  highlight-maximal-cliques-on
  stop-highlight-maximal-cliques
]

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Setup
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to clear
  clear-all
  set-default-shape comm-subjects "circle"
  reset-ticks
end

to initial-norm-perception
  clear-all-plots
  if norm-perception-distribution = "random-distribution" [
    ask comm-subjects [
      set norm-perception random-float 1
    ]
  ]

  if norm-perception-distribution = "normal-distribution" [
    ask comm-subjects [
      set norm-perception random-normal norm-perception-mean norm-perception-sd
      while [norm-perception < 0 or norm-perception > 1] [
        set norm-perception (random-normal norm-perception-mean norm-perception-sd)
      ]
      set original-norm-perception norm-perception
    ]
  ]
  if norm-perception-distribution = "beta-distribution" [
    set current_min_norm min_norm
    set current_max_norm max_norm
    set current_alpha alpha
    set current_beta beta
      ask comm-subjects [
      let x random-gamma alpha 1
      set norm-perception ( x / ( x + random-gamma beta 1) )
      set norm-perception min_norm + (norm-perception * (max_norm - min_norm))
      set original-norm-perception norm-perception
    ]
  ]
  ask comm-subjects [
    set original-norm-perception norm-perception
  ]
  update-plots
end

to reset-simulation
  clear-all-plots
  ask comm-objects [
    die
  ]
  ask comm-subjects [
    set size 2
    set shape "circle"
    set activation-phase 0
    set motivation original-motivation
    set norm-perception original-norm-perception
  ]
  update-plots
  reset-ticks
end

to current-bounded-confidence
  ask comm-subjects [
    set bc-level fix-bc-level
  ]
end

to beta-distribution-norm
  set current_min_norm min_norm

end

to setup-subjects
  ask comm-subjects [
    set size 2
    set motivation random-float activation-threshold
    set original-motivation motivation
    set activation-phase 0
    set deviance? false
  ]
end

to entry-exit
  ask comm-subjects [
    if random-float 1 < noise-rate [
      set norm-perception random-normal current-norm-perception noise-range
      while [norm-perception < 0 or norm-perception > 1] [
        set norm-perception random-normal current-norm-perception noise-range
      ]
    ]
  ]
end

to-report norm-perception-color-cluster [np]
  if norm-perception <= 0.1 [ report gray ]
  if norm-perception <= 0.2 [ report red ]
  if norm-perception <= 0.3 [ report orange ]
  if norm-perception <= 0.4 [ report brown ]
  if norm-perception <= 0.5 [ report pink ]
  if norm-perception <= 0.6 [ report green ]
  if norm-perception <= 0.7 [ report lime ]
  if norm-perception <= 0.8 [ report turquoise ]
  if norm-perception <= 0.9 [ report cyan ]
  report sky
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Network
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to setup-network-structure
  clear-all
  chooser-network-structure
  setup-subjects
  initial-norm-perception
  current-bounded-confidence
  colorize-subjects
  layout-subjects
  reset-ticks
end

to chooser-network-structure
  if network-topology = "watts-strogatz" [
    generate-watts-strogatz
  ]
  if network-topology = "test-network" [
    test-network
  ]
  if network-topology = "erdös-renyi" [
    generate-random
  ]
  if network-topology = "preferential-attachment" [
    generate-preferential-attachment
  ]
end

to generate-watts-strogatz
  clear
  nw:generate-watts-strogatz comm-subjects undirected-edges nb-subjects neighborhood-size rewire-prob
end

to test-network
  clear
  create-comm-subjects nb-subjects
  ask comm-subjects [
    create-undirected-edges-with other comm-subjects
  ]
end

to generate-random
  clear
  nw:generate-random comm-subjects undirected-edges nb-subjects connection-prob
end

to generate-preferential-attachment
  clear
  nw:generate-preferential-attachment comm-subjects undirected-edges nb-subjects 1
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Layouts
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to layout-subjects
  if layout-network = "spring" [
    let factor sqrt count comm-subjects
    if factor = 0 [ set factor 1 ]
    layout-spring comm-subjects undirected-edges (0.2 / factor) (50 / factor) (10 / factor) ; spring-constant spring-length repulsion-effect
  ]
  if layout-network = "circle" [
    layout-circle sort comm-subjects max-pxcor * 0.9
  ]
  display
  ifelse subject-labels? [
    label-subjects
  ][
    ask comm-subjects [
      set label ""
    ]
  ]
end

to label-subjects
    if subject-labels = "Norm Perception" [
     ask comm-subjects [
      set label precision norm-perception 2
    ]
  ]
    if subject-labels = "Centrality" [
      label-centrality
    ]
end

to layout-objects
 let factor sqrt count comm-objects
    if factor = 0 [ set factor 1 ]
    layout-spring comm-objects object-links (1 / factor) (20 / factor) (5 / factor)
 ifelse show-objects? [
    ask comm-objects [
      set hidden? false
    ]
  ][
    ask comm-objects [
      set hidden? true
    ]
  ]
  ifelse show-object-links? [
    ask object-links [
      set hidden? false
    ]
  ][
    ask object-links [
      set hidden? true
    ]
  ]
  ifelse object-labels? [
    ask comm-objects [
      set label precision norm-cue 2
    ]
  ][
    ask comm-objects [
      set label ""
    ]
  ]
  display
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Go
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to go
  remove-irrelevant-objects
  entry-exit
  detect-extremism
  produce-comm-objects
  recept-comm-objects
  update-plots
  tick
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Production of Messages
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to produce-comm-objects
  set current-omega omega
  set current-epsilon epsilon

  ask comm-subjects [

    let motivation-0 count link-neighbors with [breed = comm-subjects and motivation = 0 and norm-perception <= 1.0 ]

    if motivation-0 != 0 [
      set motivation motivation + (epsilon * motivation-0)
    ]

    if (motivation < activation-threshold) [
      set activation-phase (activation-phase + 1)

    ifelse motivation > 0 [
      set motivation (1 / omega * ln (1 + (exp (omega) - 1) * (motivation / activation-threshold))) + 0.001
      ][
      set motivation 0.01
      set motivation (1 / omega * ln (1 + (exp (omega) - 1) * (motivation / activation-threshold)))
      ]
    ]

    if (motivation >= activation-threshold)[
      hatch-comm-objects 1 [
      set age 0
      set reception-frequency 0
      set reception-growth? false
      set color yellow
      set shape "circle"
      set size 0.8
      set label ""
      set norm-cue [current-norm-perception] of myself
      create-object-link-with myself [
          set color yellow
        ]
      ]
      set motivation 0 ;
      set activation-phase 0
    ]
  ]
end

to-report current-norm-perception
  report norm-perception
end

to-report current-norm-cue
  report norm-cue
end

to-report current-bpunded-confidence
  report bc-level
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Reception of Messages
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to recept-comm-objects
  ask comm-objects [
    set p-values []
    ifelse reception-growth = 0 [
      set reception-growth? false
    ][
      set reception-growth? true
    ]
    set reception-growth 0
  ]

  ask comm-subjects [
    set sorted-objects []
    set sorted-objects (comm-objects with [nw:distance-to myself = obj-distance])
    let eligible-count count sorted-objects
    set sorted-objects sort-on [(- reception-frequency)] sorted-objects

    if eligible-count > 0 [
      set norm-cue-sum 0
      let rank 0
      let rank-list []
      foreach sorted-objects [
        obj ->
        set rank rank + 1
        let age-of-obj [age] of obj
        let p (1 / (rank ^ gamma))*(obj-fatigue ^ [age] of obj)
        if [reception-growth?] of obj [
          set p p * (obj-fatigue ^ [age] of obj)
        ]
        ask obj [
          set p-values lput p p-values
        ]
        if random-float 1 < p [
         if (abs (norm-perception - [current-norm-cue] of obj) < bc-level) [
          set norm-cue-sum norm-cue-sum + [current-norm-cue] of obj
          ask obj [
            set reception-frequency [reception-frequency + 1] of obj
            set reception-growth [reception-growth + 1] of obj
          ]
          set rank-list lput obj rank-list
        ]
      ]
    ]

      if not extremist? [
      if length rank-list > 0 [
          let old-norm-perception norm-perception
          ; Hegselmann & Krause (HK)
          set norm-perception ((norm-perception + norm-cue-sum) / (length rank-list + 1))
          set adaption-value abs(norm-perception - old-norm-perception)
        ]
      ]
    ]
  ]

  ask comm-objects [
    set age age + 1
  ]
end

to remove-irrelevant-objects
  ask comm-objects [
    if length p-values != 0 and mean p-values <= obj-relevance [ ;; if comm-objects seem too irrelevant (low average probability of reception, they are removed from the system)
    die
   ]
  ]
end

to detect-extremism
  ask comm-subjects [
    ;; detect if in extremism zone
    if (extremism_type = "two-side") [
      set extremist? (0.5 - abs(norm-perception - 0.5) < extremism_range)
    ]
    if (extremism_type = "one-side-left") [
      set extremist? (norm-perception < extremism_range)
    ]
    if (extremism_type = "one-side-right") [
      set extremist? (norm-perception > extremism_range)
    ]
  ]
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Centrality Measures
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to highlighting-centrality
  compute-centrality
  normalize-sizes-and-colors
  if subject-labels? = false [
    ask comm-subjects [
      set label ""
    ]
  ]
  nw:set-context turtles links
end

to compute-centrality
  if (centrality-measure = "betweenness") [
    centrality [ -> nw:betweenness-centrality ]
  ]
  if (centrality-measure = "closeness") [
    centrality [ -> nw:closeness-centrality ]
  ]
  if (centrality-measure = "eigenvector") [
    centrality [ -> nw:eigenvector-centrality ]
  ]
end

to centrality [ measure ]
  nw:set-context comm-subjects undirected-edges
  ask comm-subjects [
    let res (runresult measure)
    ifelse is-number? res [
      set label precision res 1
      set size res
    ][
      set label "N/A"
      set size 1
    ]
  ]
end

to centrality-label [ measure ]
  nw:set-context comm-subjects undirected-edges
  ask comm-subjects [
    let res (runresult measure)
    ifelse is-number? res [
      set label precision res 2
    ][
      set label "N/A"
      set size 1
    ]
  ]
  nw:set-context turtles links
end

to normalize-sizes-and-colors
  let comm-subjects-without-nan (comm-subjects with [ is-number? size ])
  if count comm-subjects-without-nan > 0 [
    let sizes sort [ size ] of comm-subjects-without-nan ; initial sizes in increasing order
    let delta last sizes - first sizes ; difference between biggest and smallest
    ifelse delta = 0 [ ; if they are all the same size
      ask comm-subjects-without-nan [ set size 1 ]
    ]
    [ ; remap the size to a range between 0.5 and 3.5
      ask comm-subjects-without-nan [ set size ((size - first sizes) / delta) * 3 + 0.5 ]
    ]
    ask comm-subjects-without-nan [ set color scale-color red size 0 5 ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Highlighting
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report color-cluster
  let color-list [ color ] of turtles with [ breed = comm-subjects ]
  let unique-colors remove-duplicates color-list
  report length unique-colors
end

to reset-selection
  ask comm-subjects [
    set shape "circle"
    set label ""
    set color grey
  ]
end

to norm-label
  ask comm-subjects [
      set label precision norm-perception 2
  ]
end

to label-centrality
  if (centrality-measure = "betweenness") [
    centrality-label [ -> nw:betweenness-centrality ]
  ]
  if (centrality-measure = "closeness") [
    centrality-label [ -> nw:closeness-centrality ]
  ]
  if (centrality-measure = "eigenvector") [
    centrality-label [ -> nw:eigenvector-centrality ]
  ]
end

to norm-size
 ask comm-subjects [
    set label precision norm-perception 2
    set size norm-perception
  ]
    normalize-sizes-and-colors
  if subject-labels? = false [
    ask comm-subjects [
      set label ""
    ]
  ]
end

to normalize-size
  let comm-subjects-without-nan (comm-subjects with [ is-number? size ])
  if count comm-subjects-without-nan > 0 [
    let sizes sort [ size ] of comm-subjects-without-nan ;
    let delta last sizes - first sizes
    ifelse delta = 0 [
      ask comm-subjects-without-nan [ set size 1 ]
    ]
    [
      ask comm-subjects-without-nan [ set size ((size - first sizes) / delta) * 3 + 0.5 ]
    ]
  ]
end

to find-biggest-clique
  ask comm-subjects [
    set shape "circle"
  ]
  set selected-comm-subjects []
  nw:set-context comm-subjects undirected-edges
  let selected-comm-subjects-agentset one-of nw:biggest-maximal-cliques
  let sorted-comm-subjects sort selected-comm-subjects-agentset
  set selected-comm-subjects sorted-comm-subjects
  ask comm-subjects [
    ifelse member? self selected-comm-subjects [
      set color red
      set shape "x"
    ] [
      set color gray
    ]
  ]
  nw:set-context turtles links
  print selected-comm-subjects
end

to find-biggest-cliques
  nw:set-context comm-subjects undirected-edges
  let biggest-cliques nw:biggest-maximal-cliques
  color-clusters biggest-cliques
  nw:set-context turtles links
end

to community-detection
  nw:set-context comm-subjects undirected-edges
  color-clusters nw:louvain-communities
  nw:set-context turtles links
end

to highlight-maximal-cliques

  if stop-highlight-maximal-cliques = true [
    set stop-highlight-maximal-cliques false
    set highlight-maximal-cliques-on false
    stop
  ]
  set highlight-maximal-cliques-on true
  if highlight-bicomponents-on = true [
    set stop-highlight-bicomponents true
  ]

  if mouse-inside? [
    nw:set-context comm-subjects undirected-edges
    highlight-clusters nw:maximal-cliques
  ]
  display
  nw:set-context turtles links
end

to highlight-clusters [ clusters ]
  let node min-one-of comm-subjects [ distancexy mouse-xcor mouse-ycor ]
  if node != nobody and node != highlighted-node [
    set highlighted-node node
    color-clusters filter [ cluster -> member? node cluster ] clusters
    ask node [ set color white ]
  ]
end

to color-clusters [ clusters ]
  ask comm-subjects [ set color gray ]
  ask undirected-edges [ set color gray - 2 ]
  let n length clusters
  let hues n-values n [ i -> (360 * i / n) ]
  (foreach clusters hues [ [cluster hue] ->
    ask cluster [
      set color hsb hue 100 100
      ask my-links with [ member? other-end cluster ] [ set color hsb hue 100 75 ]
    ]
  ])
end

to reset-labels
   ask comm-subjects [
    set label ""
    ]
    ask comm-objects [
      set label ""
    ]
  nw:set-context turtles links
end

to drag-drop
  ifelse mouse-down? [
    handle-select-and-drag
  ][
    set selected nobody
    reset-perspective
  ]
  display
end

to handle-select-and-drag
  ifelse selected = nobody  [
    set selected min-one-of turtles [distancexy mouse-xcor mouse-ycor]
    ifelse [distancexy mouse-xcor mouse-ycor] of selected > 1 [
      set selected nobody
    ][
      watch selected
    ]
  ][
    ask selected [ setxy mouse-xcor mouse-ycor ]
  ]
end

to size-comm-objects
  if count comm-objects > 0 [
    let mean_rf mean [reception-frequency] of comm-objects
    let sd_rf standard-deviation [reception-frequency] of comm-objects
    ask comm-objects [
      let normalized_size 0.5 + ((reception-frequency - mean_rf) / sd_rf)
      set size max list 0.5 min list normalized_size 5
    ]
  ]
end

to colorize-subjects
  nw:set-context turtles links
  ask comm-subjects [
    set color norm-perception-color-cluster norm-perception
    ]
end

to show-activation
  ask comm-subjects [
    ifelse motivation = 0 [
      set color white
    ] [
      set color norm-perception-color-cluster norm-perception
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Manipulation and Simulation
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to manipulation
  foreach selected-comm-subjects [
   cs ->
    ask cs [
    if deviant-norm-perception = "normal-distribution" [
      set norm-perception random-normal norm-perception-mean norm-perception-sd
      while [norm-perception < 0 or norm-perception > 1] [
      set norm-perception (random-normal norm-perception-mean norm-perception-sd)
    ]
  ]
    if deviant-norm-perception = "beta-distribution" [
      set current_min_norm min_norm
      set current_max_norm max_norm
      set current_alpha alpha_deviance
      set current_beta beta_deviance
        let x random-gamma alpha_deviance 1
        set norm-perception ( x / ( x + random-gamma beta_deviance 1) )
        set norm-perception min_norm + (norm-perception * (max_norm - min_norm))
    ]
   ]
  ]
  update-plots
end

to select-comm-subjects
  ask comm-subjects [
    set shape "circle"
  ]
  highlighting-centrality
  set selected-comm-subjects []

  if network-position = "central" [
    let sorted-comm-subjects sort-on [ ( - label ) ] comm-subjects
    set selected-comm-subjects n-values nb-selection [ i -> item i sorted-comm-subjects ]
  ]
  if network-position = "peripheral" [
    let sorted-comm-subjects sort-on [ label ] comm-subjects
    set selected-comm-subjects n-values nb-selection [ i -> item i sorted-comm-subjects ]
  ]
  if network-position = "random" [
    set selected-comm-subjects sort n-of nb-selection comm-subjects
  ]
  ask comm-subjects [
    ifelse member? self selected-comm-subjects [
      set color red
      set shape "square"
      set bc-level deviance-bc-level
      set deviance? true
    ] [
      set color gray
    ]
  ]
  output-print selected-comm-subjects
end

to-report report-norm-perceptions
  report map [ p -> precision p 2 ] [norm-perception] of comm-subjects
end
@#$#@#$#@
GRAPHICS-WINDOW
480
362
878
761
-1
-1
6.4
1
10
1
1
1
0
0
0
1
-30
30
-30
30
0
0
1
ticks
30.0

BUTTON
17
96
72
129
Clear
clear
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
247
567
459
600
norm-perception-mean
norm-perception-mean
0
1
0.5
0.1
1
NIL
HORIZONTAL

SLIDER
247
605
460
638
norm-perception-sd
norm-perception-sd
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
75
96
227
129
nb-subjects
nb-subjects
0
200
100.0
1
1
NIL
HORIZONTAL

SLIDER
17
280
228
313
neighborhood-size
neighborhood-size
0
20
3.0
1
1
NIL
HORIZONTAL

SLIDER
18
317
229
350
rewire-prob
rewire-prob
0
1
0.2
.01
1
NIL
HORIZONTAL

CHOOSER
132
153
228
198
layout-network
layout-network
"spring" "circle"
0

BUTTON
22
465
228
499
Layout
layout-subjects
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
894
363
1551
527
Norm Perception Distribution
Norm Perception
# Agents
0.0
1.0
0.0
0.0
true
false
"" "set-plot-y-range 0 round(nb-subjects / 8)"
PENS
"distribution" 0.02 1 -13791810 true "" "histogram [norm-perception] of comm-subjects"
"pen-1" 0.02 1 -5298144 true "" "if selected-comm-subjects != 0 [\nlet norm-perceptions [] ; erstelle eine leere Liste\nforeach selected-comm-subjects [\n  cs -> ; cs steht für comm-subject\n  let np [norm-perception] of cs ; np steht für norm-perception\n  set norm-perceptions lput np norm-perceptions ; füge np zur Liste norm-perceptions hinzu\n]\nhistogram norm-perceptions\n]"

SLIDER
713
134
870
167
fix-bc-level
fix-bc-level
0
1
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
253
193
466
226
omega
omega
0
50
10.0
.1
1
NIL
HORIZONTAL

BUTTON
75
44
131
92
Go Once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
254
135
468
168
activation-threshold
activation-threshold
0
5
1.0
1
1
NIL
HORIZONTAL

SLIDER
253
249
466
282
epsilon
epsilon
0
1
0.2
.001
1
NIL
HORIZONTAL

SLIDER
484
247
691
280
obj-fatigue
obj-fatigue
0
1
0.9
0.01
1
NIL
HORIZONTAL

SLIDER
482
300
691
333
obj-relevance
obj-relevance
0
1
0.15
0.01
1
NIL
HORIZONTAL

BUTTON
135
45
229
93
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
356
432
460
465
max_norm
max_norm
0
1
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
248
432
352
465
min_norm
min_norm
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
248
468
461
501
alpha
alpha
0.1
10
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
248
506
460
539
beta
beta
0.1
10
5.0
0.1
1
NIL
HORIZONTAL

CHOOSER
249
360
459
405
norm-perception-distribution
norm-perception-distribution
"normal-distribution" "beta-distribution" "random-distribution"
0

PLOT
1277
533
1553
710
Histogramm Reception Frequency
Reception Frequency
# Messages
0.0
40.0
0.0
10.0
true
false
"" ""
PENS
"default" 2.0 1 -16777216 true "" "histogram [reception-frequency] of comm-objects"

CHOOSER
18
205
228
250
network-topology
network-topology
"watts-strogatz" "erdös-renyi" "preferential-attachment"
0

BUTTON
16
44
72
92
Setup
setup-network-structure
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
484
190
691
223
gamma
gamma
0
5
1.0
0.25
1
NIL
HORIZONTAL

SLIDER
18
380
229
413
connection-prob
connection-prob
0
1
0.05
0.01
1
NIL
HORIZONTAL

BUTTON
27
618
230
652
Layout
layout-objects
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
481
134
690
167
obj-distance
obj-distance
0
10
2.0
1
1
NIL
HORIZONTAL

SLIDER
248
692
458
725
noise-rate
noise-rate
0
1
0.01
0.01
1
NIL
HORIZONTAL

CHOOSER
715
247
880
292
extremism_type
extremism_type
"one-side-left" "one-side-right" "two-side"
2

SLIDER
715
304
880
337
extremism_range
extremism_range
0
1
0.02
0.01
1
NIL
HORIZONTAL

TEXTBOX
715
213
857
241
If in extremism zone:\nno change of perception
11
63.0
1

BUTTON
899
189
1039
223
Show Activation
show-activation
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1048
113
1193
147
Resize 
size-comm-objects
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
790
722
873
756
NIL
drag-drop
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
896
293
1040
338
centrality-measure
centrality-measure
"betweenness" "closeness" "eigenvector"
0

BUTTON
897
256
1040
289
Show Centrality
highlighting-centrality
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1050
305
1197
339
Maximal Cliques
highlight-maximal-cliques\n 
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1050
228
1195
262
Community Detection
community-detection
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1050
267
1196
301
Biggest Maximal Cliques
find-biggest-cliques
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
1229
152
1374
185
nb-selection
nb-selection
0
100
25.0
1
1
NIL
HORIZONTAL

SWITCH
26
656
230
689
show-objects?
show-objects?
1
1
-1000

SWITCH
25
728
229
761
show-object-links?
show-object-links?
1
1
-1000

BUTTON
1235
264
1382
298
Select Deviants
select-comm-subjects
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
899
114
1039
147
Colorize 
colorize-subjects
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
894
532
1272
759
Norm Clusters 
Steps
Fraction of Agents
0.0
1.0
0.0
0.5
true
true
"" ""
PENS
"np <= 0.1" 1.0 0 -7500403 true "" "plotxy ticks ((count comm-subjects with [norm-perception <= 0.1]) / nb-subjects )"
"0.1 < np <= 0.2" 1.0 0 -2674135 true "" "plotxy ticks ((count comm-subjects with [norm-perception > 0.1 and norm-perception <= 0.2]) / nb-subjects )"
"0.2 < np <= 0.3" 1.0 0 -955883 true "" "plotxy ticks ((count comm-subjects with [norm-perception > 0.2 and norm-perception <= 0.3]) / nb-subjects )"
"0.3 < np <= 0.4" 1.0 0 -6459832 true "" "plotxy ticks ((count comm-subjects with [norm-perception > 0.3 and norm-perception <= 0.4]) / nb-subjects )"
"0.4 < np <= 0.5" 1.0 0 -2064490 true "" "plotxy ticks ((count comm-subjects with [norm-perception > 0.4 and norm-perception <= 0.5]) / nb-subjects )"
"0.5 < np <= 0.6" 1.0 0 -10899396 true "" "plotxy ticks ((count comm-subjects with [norm-perception > 0.5 and norm-perception <= 0.6]) / nb-subjects )"
"0.6 < np <= 0.7" 1.0 0 -13840069 true "" "plotxy ticks ((count comm-subjects with [norm-perception > 0.6 and norm-perception <= 0.7]) / nb-subjects )"
"0.7 < np <= 0.8" 1.0 0 -14835848 true "" "plotxy ticks ((count comm-subjects with [norm-perception > 0.7 and norm-perception <= 0.8]) / nb-subjects )"
"0.8 < np <= 0.9" 2.0 0 -11221820 true "" "plotxy ticks ((count comm-subjects with [norm-perception > 0.8 and norm-perception <= 0.9]) / nb-subjects )"
"np > 0.9" 1.0 0 -13791810 true "" "plotxy ticks ((count comm-subjects with [norm-perception > 0.9]) / nb-subjects )"

BUTTON
899
150
1039
184
Resize
norm-size\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
248
727
457
760
noise-range
noise-range
0
1
0.2
0.1
1
NIL
HORIZONTAL

SWITCH
25
692
229
725
object-labels?
object-labels?
1
1
-1000

CHOOSER
22
538
227
583
subject-labels
subject-labels
"Norm Perception" "Centrality"
0

SWITCH
22
502
228
535
subject-labels?
subject-labels?
1
1
-1000

CHOOSER
1229
103
1375
148
network-position
network-position
"central" "peripheral" "random"
0

SLIDER
1399
262
1546
295
deviance-bc-level
deviance-bc-level
0
1
1.0
.01
1
NIL
HORIZONTAL

CHOOSER
1397
112
1543
157
deviant-norm-perception
deviant-norm-perception
"beta-distribution" "normal-distribution"
0

SLIDER
1397
162
1545
195
alpha_deviance
alpha_deviance
.1
10
5.0
.1
1
NIL
HORIZONTAL

SLIDER
1397
199
1547
232
beta_deviance
beta_deviance
0.1
10
0.5
0.1
1
NIL
HORIZONTAL

TEXTBOX
1167
715
1317
743
np=\nnorm perception
11
14.0
1

TEXTBOX
20
12
170
36
SETUP & GO\n
18
0.0
1

TEXTBOX
250
308
438
372
INITIAL\nNORM PERCEPTION
18
25.0
1

TEXTBOX
16
150
166
197
NETWORK\nTOPOLOGY
18
115.0
1

TEXTBOX
19
260
212
289
Watts-Strogatz (Small-World)
11
115.0
1

TEXTBOX
19
359
169
377
Erdös-Renyi (Random)
11
115.0
1

TEXTBOX
248
548
472
576
Parameter: Normal Distribution
11
25.0
1

TEXTBOX
250
414
439
433
Parameter: Beta Distribution
11
25.0
1

TEXTBOX
248
12
524
36
COMMUNICATIVE ACTION
18
53.0
1

TEXTBOX
252
40
419
109
PRODUCTION OF\nNORMATIVE MESSAGES
14
55.0
1

TEXTBOX
347
176
497
195
Individual Component
11
55.0
1

TEXTBOX
369
233
478
252
Social Component\n
11
55.0
1

TEXTBOX
354
118
504
136
Activation Threshold
11
55.0
1

TEXTBOX
483
36
671
88
RECEPTION OF\nNORMATIVE MESSAGES
14
63.0
1

TEXTBOX
249
79
399
97
THRESHOLD MODEL
11
44.0
1

TEXTBOX
482
77
632
95
PROBABILITY MODEL\n
11
44.0
1

TEXTBOX
518
174
697
203
Social Component (Social Cues)
11
63.0
1

TEXTBOX
521
230
723
259
Temporal Component (Fatigue)
11
63.0
1

TEXTBOX
527
117
719
146
Spatial Component (Distance)
11
63.0
1

TEXTBOX
712
35
884
89
UPDATE: DESCRIPTIVE\nNORM PERCEPTION
14
63.0
1

TEXTBOX
546
284
696
303
Relevance Threshold (Exit)
11
63.0
1

TEXTBOX
655
54
721
73
----->
11
63.0
1

TEXTBOX
712
74
904
102
HEGSELMANN-KRAUSE MODEL
11
44.0
1

TEXTBOX
714
94
858
130
Bounded Confidence Level
14
63.0
1

TEXTBOX
247
664
369
686
Noise
14
25.0
1

TEXTBOX
24
434
191
458
LAYOUT
18
35.0
1

TEXTBOX
172
442
235
462
AGENTS
14
35.0
1

TEXTBOX
156
596
233
616
MESSAGES\n
14
35.0
1

TEXTBOX
715
188
882
210
Stubbornness
14
63.0
1

TEXTBOX
897
60
1064
80
AGENTS
14
105.0
1

TEXTBOX
1222
12
1584
59
MANIPULATION: DEVIANCE
18
15.0
1

TEXTBOX
1046
59
1213
79
MESSAGES
14
105.0
1

TEXTBOX
899
80
1042
108
based on norm perception
11
105.0
1

TEXTBOX
1047
79
1209
110
based on reception frequency
11
105.0
1

BUTTON
1235
303
1382
337
Manipulate
manipulation
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
1225
47
1384
106
1. Choose network position based on centrality-measure
11
15.0
1

TEXTBOX
1394
46
1564
90
2. Choose distribution of norm perception and bc-level
11
15.0
1

TEXTBOX
895
12
1062
36
HIGHLIGHTING
18
105.0
1

TEXTBOX
900
229
1067
249
CENTRALITY 
14
105.0
1

TEXTBOX
1055
185
1175
224
COMMUNITIES & CLIQUES
14
105.0
1

TEXTBOX
1235
199
1375
264
3. Select and manipulate agents\n(make sure to turn on \"subject-labels?\")
11
15.0
1

MONITOR
1277
714
1369
759
Mean (np)
mean [norm-perception] of comm-subjects
3
1
11

MONITOR
1457
712
1553
757
Median (np)
median [norm-perception] of comm-subjects
3
1
11

MONITOR
1372
713
1454
758
SD
standard-deviation [norm-perception] of comm-subjects
3
1
11

BUTTON
1050
12
1106
46
Reset
ask links [\nset color grey\n]\nask comm-subjects [\nset size 2\n]\n\ncolorize-subjects
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
1396
92
1563
112
Norm Perception 
11
15.0
1

TEXTBOX
1399
244
1566
264
BC-Level
11
15.0
1

TEXTBOX
484
97
600
115
Relevance
14
63.0
1

TEXTBOX
255
99
371
117
Activation
14
55.0
1

@#$#@#$#@
# COMM-PDND


## WHAT IS IT?

The Communication-Based Model of Perceived Descriptive Norm Dynamics in Digital Networks (COMM-PDND) is an agent-based model specifically created to examine the dynamics of perceived descriptive norms in the context of digital network structures. The model, developed as part of a master's thesis titled "The Dynamics of Perceived Descriptive Norms in Digital Network Publics: An Agent-Based Simulation", emphasizes the critical role of communication processes in norm formation. It focuses on the role of communicative interactions in shaping these perceived descriptive norms.

The COMM-PDND model is tuned to explore the effects of normative deviance in digital social networks. It provides functionalities for manipulating agents according to their centrality positions within the network, and has a versatile set of customizable parameters, making it adaptable to a wide range of research contexts.

## HOW IT WORKS

The two central processes in the ABM are *norm signaling* and *norm inference*. Regarding the communicative process of norm formation and "the conceptual route of norm acquisisition" (Kashima et al., 2013), the dissemination of normative cues as well as the normative inference about the prevalence of a behavior are conceptualized as communicative actions (Friemel & Neuberger, 2021).

### Norm Signaling and Norm Inference as Communicative Actions 
#### The Production of Normative Messages (Norm Signaling)

The production of normative messages is based on the threshold model of "repeated activation in social networks" by Piedrahita et al. (2018), which takes into account both individual and social motivational factors.

- Individual motivation "omega" is modeled as a logarithmic function that continuously increases until the activation threshold is reached.

- Social motivation depends on the actions of neighboring agents and is represented by the constant parameter "epsilon", which is the signal intensity of activated agents.

As soon as the activation state exceeds the "activation-threshold", the agents send out a normative message based on their current perceived descriptive norm.

Initially, each agent is assigned a random activation state [0, 1]. Each activation results in a reset and brings the agents to the beginning of their activation cycle.

#### The Reception of Normative Messages (Norm Inference)

The reception of normative messages is conceived as a probability model based on the principle of selective exposure. The specific relevance of reception is calculated on the basis of the following parameters:

- Spatial component (distance): The constant "obj-distance" is used to pre-filter which messages are theoretically visible and receivable by the agents. In the initial configuration, the parameter is set to 2, so that only messages from proximal referents are considered.

- Social component (social cues): Messages that are frequently received in the local network have a higher probability of being received again. This leads to a positive feedback mechanism. The smaller "gamma" is set, the greater the influence of the reception frequency

- Temporal component (fatigue): The relevance of a message decreases over time, which reduces the probability of reception. When messages become irrelevant (average probability of reception < "obj-relevance"), they are removed from the system.

### Update: Descriptive Norm Perceptions

#### Hegselmann-Krause (HK) Model

The COMM-PDND uses an update mechanism to regularly adjust the descriptive norm perceptions of the agents. This mechanism is based on the HK model (Hegselmann & Krause, 2002), which is in the tradition of "similarity biased models of social influence". According to this model, the strength of social influence between connected individuals is directly related to their similarity. In terms of individual changes in descriptive norm perception, this means:

- At each time step, agents adjust their own descriptive norm perception by taking into account the average of all normative information received during that simulation step.

- Each agent has an determined bounded confidence level ("fix-bc-level"), which indicates the tolerance for divergent normative information. Only information that deviates less than the bc-level from one's norm perception is considered.

For the concrete implementation of the mechanism, the NetLogo model of Lorenz (2012) was used as a guideline.

### Noise

The "noise" parameter is designed to account for random deviations in the agents' descriptive norm perception at each simulation step (Flache et al., 2017, para. 2.44). It helps to account for unpredictable changes in norm perception that cannot be explained by communicative interactions in the network.

To regulate the variances, the "noise-rate" is kept relatively low in the initial configuration (*p* = 0.02). The random deviations follow a normal distribution with a "noise-range" of *SD* = 0.2.

### Stubbornness

The parameter "stubbornness" serves as a kind of resistance mechanism that limits the adaptability of agents' descriptive norm perceptions (Deffuant, 2002). The core idea behind this parameter is that there are agents who are so entrenched in their perceptions that they not willing or able to change them in response to social influence.

The "extremism_type" parameter can be used to choose between "one-sided" or "two-sided" stubbornness. The "extremism_range" parameter determines the range of norm perceptions in which agents maintain their descriptive norm perceptions despite external influences.

Example: extremism_type:two-sided; extremism_range: 0.02
Here, agents whose current descriptive norm perception is either at the lower (near 0) or upper (near 1) end of the norm perception range [0, 1] are in the "extremism zone". This setting could represent an asymmetric interaction dynamic in which agents with extremely pronounced low or high descriptive norm perceptions are more likely to influence others with their normative information than to be influenced by others themselves. 

## HOW TO USE IT

#### 1. SETUP

- Generate a social network with undirected connections based on the number of agents and the network topology selection.

- Make sure to set the "norm-perception-distribution" and the "fix-bc-level" as desired before pressing SETUP.

Note: A high number of agents can extremely slow down the ABM.

#### 2. LAYOUT

- Layout the agents in the network either as "circle" or as "spring" to increase the visibility of the network and possible clusters. 

- Additionally, LABELS can be turned on and off to show the exact current norm perception. 

#### 3. GO

- Click on GO to start the simulation. Click on GO ONCE to simulate only one simulation step.

#### 4. HIGHLIGHTING

- In addition to colouring the norm perceptions by clicking on COLOURIZE, the size of the agents can be displayed in relation to their norm perceptions by clicking on RESIZE (the same applies to messages).

- When SHOW CENTRALITY is clicked, the centrality measures of the agents are visualised by their size and colour, allowing immediate comparison.

- Furthermore, the generated network can be described in more detail by displaying the communities and cliques (to see the effect of "maximal cliques" you have to move the cursor over the agents).

## THINGS TO TRY

#### [OPTIONAL] SIMULATING DEVIANCE

You can select a number of "nb-selection" agents based on their network position (peripheral vs. central) and assign them a specific norm perception and their own bc-level based on the beta distribution of the "deviant-norm-perception". 

This mechanism can be used to implement the scenario of normative deviance in the system.

The network position (peripheral vs. central) is based on the selection of the "centrality-measure". Make sure that before clicking on "selection", the "subject-labels?" is set to "on" to calculate the centrality correctly. 

- If "network-position" is set to "central", this means that the agents will be sorted in descending order of their centrality value and the first "nb-selection" will be selected as agents to be manipulated.

- If "network-position" is set to "peripheral", this means that the agents will be sorted in ascending order of their centrality value and the first "nb-selection" are selected as agents to be manipulated.

Click on "SELECT DEVIANTS" to make visible which agents would be manipulated (red).

Click on "MANIPULATE" to execute the manipulation. 

**Example of Application**.

In the master thesis, a 2x2 simulation experiment was conducted by systematically varying the parameters "network-position" and "deviant-bc-level" to investigate the influence of deviant agents on the dynamics of descriptive norm perceptions.


## REFERENCES

**Deffuant, G., Amblard, F., Weisbuch, G., & Faure, T. (2002).** How can extremism prevail? A study based on the relative agreement interaction model. *Journal of artificial societies and social simulation*, *5*(4). https://www.jasss.org/5/4/1.html 

**Flache, A., Mäs, M., Feliciani, T., Chattoe-Brown, E., Deffuant, G., Huet, S., & Lorenz, J. (2017).** Models of Social Influence: Towards the Next Frontiers. *Journal of Artificial Societies and Social Simulation*, *20*(4), 2. https://doi.org/10.18564/jasss.3521

**Friemel, T. N., & Neuberger, C. (2021).** Öffentlichkeit als dynamisches Netzwerk. In M. Eisenegger, M. Prinzing, P. Ettinger, & R. Blum (Hrsg.), *Digitaler Strukturwandel der Öffentlichkeit* (S. 81–96). Springer Fachmedien Wiesbaden. https://doi.org/10.1007/978-3-658-32133-8_5

**Hegselmann, R. & Krause, U. (2002).** Opinion Dynamics and Bounded Confidence, Models, Analysis and Simulation. *Journal of Artificial Societies and Social Simulation*, *5*, 2. https://www.jasss.org/5/3/2.html

**Lorenz, J. (2012).** Continuous Opinion Dynamics under Bounded Confidence. *NetLogo*. http://ccl.northwestern.edu/netlogo/models/community/bc

**Piedrahita, P., Borge-Holthoefer, J., Moreno, Y., & González-Bailón, S. (2018).** The contagion effects of repeated activation in social networks. *Social Networks*, 54, 326–335. https://doi.org/10.1016/j.socnet.2017.11.001


## CREDITS

COMM-PDND © 2023 by Lars Reinelt is licensed under CC BY-NC-SA 4.0 

 --
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup-network-structure</setup>
    <go>go</go>
    <timeLimit steps="10"/>
    <metric>count comm-subjects with [norm-perception &lt; 0.1] / count comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.1 and norm-perception &lt; 0.2] / count comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.2 and norm-perception &lt; 0.3] / count comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.3 and norm-perception &lt; 0.4] / count comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.4 and norm-perception &lt; 0.5] / count comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.5 and norm-perception &lt; 0.6] / count comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.6 and norm-perception &lt; 0.7] / count comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.7 and norm-perception &lt; 0.8] / count comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.8 and norm-perception &lt; 0.9] / count comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.9] / count comm-subjects</metric>
  </experiment>
  <experiment name="experiment" repetitions="50" runMetricsEveryStep="true">
    <setup>setup-network-structure
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <metric>standard-deviation [norm-perception] of comm-subjects</metric>
    <metric>count comm-subjects with [norm-perception &lt; 0.1]</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.1 and norm-perception &lt; 0.2]</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.2 and norm-perception &lt; 0.3]</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.3 and norm-perception &lt; 0.4]</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.4 and norm-perception &lt; 0.5]</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.5 and norm-perception &lt; 0.6]</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.6 and norm-perception &lt; 0.7]</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.7 and norm-perception &lt; 0.8]</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.8 and norm-perception &lt; 0.9]</metric>
    <metric>count comm-subjects with [norm-perception &gt; 0.9]</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-mean">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-object-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-mean">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-sd">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-object-links?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 1" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 0" repetitions="100" runMetricsEveryStep="true">
    <setup>setup-network-structure
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 1.2" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 2" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 0.2" repetitions="100" runMetricsEveryStep="true">
    <setup>setup-network-structure
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 2.2" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="200"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 1.3" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 2" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="500"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 1.3.2" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 3" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="0.76"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Parmetereinstellung 4" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 1_Z_1" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 2_Z_075" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 3_Z_050" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 4_Z_025" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 1_Z_1" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 2_Z_075" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 3_Z_050" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 4_Z_025" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;central&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 5_P_1" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;peripheral&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 6_P_075" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;peripheral&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 7_P_050" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;peripheral&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Model 8_P_025" repetitions="100" runMetricsEveryStep="true">
    <setup>import-network
select-comm-subjects
manipulation</setup>
    <go>go</go>
    <timeLimit steps="400"/>
    <metric>report-norm-perceptions</metric>
    <metric>mean [norm-perception] of comm-subjects</metric>
    <metric>median [norm-perception] of comm-subjects</metric>
    <enumeratedValueSet variable="max_norm">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-topology">
      <value value="&quot;watts-strogatz&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="gamma">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="norm-perception-distribution">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviant-norm-perception">
      <value value="&quot;beta-distribution&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="deviance-bc-level">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta_deviance">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="fix-bc-level">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-range">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-relevance">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="connection-prob">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="neighborhood-size">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-selection">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="omega">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="links-to-use">
      <value value="&quot;undirected&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="epsilon">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="min_norm">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha_deviance">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="activation-threshold">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_range">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="show-objects?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="centrality-measure">
      <value value="&quot;betweenness&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="clear-before-generating?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-distance">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rewire-prob">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="object-labels?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="subject-labels">
      <value value="&quot;Norm Perception&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="extremism_type">
      <value value="&quot;two-side&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="nb-subjects">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="obj-fatigue">
      <value value="0.9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="noise-rate">
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout-network">
      <value value="&quot;spring&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="network-position">
      <value value="&quot;peripheral&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
