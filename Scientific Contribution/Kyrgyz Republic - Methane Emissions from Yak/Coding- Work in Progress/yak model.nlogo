;; ================================================================
;; YAK ENTERIC + DUNG METHANE EMISSIONS MODEL
;; Adapted from a cattle Tier-2-style toy model to reflect yak-specific
;; physiology, husbandry, demography, and grazing-system emission sources
;; on the Qinghai-Tibetan Plateau (QTP).
;;
;; NOTE ON SCOPE: the atmospheric box-model portion (methane-concentration,
;; radiative-forcing, temperature) is a simplified illustrative dynamic,
;; not itself drawn from the yak literature reviewed. All yak-specific
;; biological/emission/demographic parameters below are cited inline.
;;
;; NOTE ON WIDGETS: beta, sigma, mu, alpha, B, radiative-forcing, and
;; food-available are NOT declared in globals below because they are
;; supplied by Interface sliders/monitors. Declaring them here as well
;; as on the Interface causes a "already defined" compile error.
;; ================================================================

globals [
  start-year
  end-year
  current-year
  NE_ma_value
  C_a_value
  C_fi_value
  DE_percentage
  Y_m
  EF_final_each_year
  cumulative_EF_final
  populations
  methane-concentration
  temperature
  C-pi
  temperature-anomaly
  Radiative-Forcing-chosen
  SSP_1_1_9
  SSP_1_2_6
  SSP_2_4_5
  SSP_3_7_0
  SSP_5_8_5
  T-dot
  cumulative-dung-CH4
  dung-CH4-each-year
  benchmark-EF-per-yak
  food-available        ;; <-- add this
  radiative-forcing     ;; <-- add this too if not already present
]

;;globals [
  ;;start-year
  ;;end-year
  ;;current-year
  ;;NE_ma_value
  ;;C_a_value
  ;;C_fi_value
  ;;DE_percentage
  ;;Y_m                        ;; methane conversion factor (% of GE lost as CH4)
  ;;EF_final_each_year
  ;;cumulative_EF_final
  ;;populations
  ;;methane-concentration
  ;;temperature
  ;;C-pi
  ;;temperature-anomaly
  ;;Radiative-Forcing-chosen
  ;;SSP_1_1_9
  ;;SSP_1_2_6
  ;;SSP_2_4_5
  ;;SSP_3_7_0
  ;;SSP_5_8_5
  ;;T-dot
  ;;food-available
  ;;radiative-forcing
  ;; --- dung/manure emissions (new: not present in cattle version) ---
  ;;cumulative-dung-CH4
  ;;dung-CH4-each-year
  ;; --- validation benchmark ---
  ;;benchmark-EF-per-yak       ;; Ding et al. 2010: ~28 kg CH4/yr, 175 kg grazing non-lactating yak
;;]

turtles-own [
  age
  sex
  is-calf?
  has-reproduced?
  years-since-last-calving
  enteric-emission-rate     ;; renamed from emission-rate
]

patches-own [
  is-dung-patch?
  dung-age                   ;; ticks since deposition
]

;; ----------------------------------------------------------------
;; SETUP
;; ----------------------------------------------------------------
to setup
  clear-all

  ;; ---- TEMPORARY: hardcoded defaults for debugging ----
  ;; (overrides whatever the Interface sliders/choosers currently show;
  ;; delete or comment out this block once the model is verified working,
  ;; to let the Interface widgets drive the model again)
  set number-of-yaks 100
  set Emission-Rate 1
  set reproductive-rate 0.44
  set mortality-rate-calf 0.15
  set mortality-rate-adult 0.05
  set avg_live_body_weight 175
  set avg_daily_weight_gain 0.1
  set Amt_of_milk_produced 0
  set No_of_hrs_worked_in_a_day 0
  set moderate_body_condition 1.0
  set beta 0.35
  set sigma 0.15
  set mu 0.03
  set alpha 0.03
  set B 0.1
  set dung-CH4-per-patch 0.5
  set feeding-situation "grazing"
  set diet-type "moderate_quality"
  set C_fi_type "non_lactating"
  set SSP-Scenario "SSP_2-4.5"
  ;; ---- end hardcoded defaults ----

  setup-patches
  create-turtles number-of-yaks [
    set color one-of [red green blue]
    set age random 15
    set sex one-of ["male" "female"]
    set is-calf? (age < 1)
    set has-reproduced? false
    set years-since-last-calving 1
    set size 2
    set enteric-emission-rate Emission-Rate
  ]
  set start-year 2015
  set end-year 2100
  set current-year start-year
  set-up-variables
  set EF_final_each_year n-values (end-year - start-year + 1) [0]
  set cumulative_EF_final 0
  set populations n-values (end-year - start-year + 1) [0]
  set dung-CH4-each-year n-values (end-year - start-year + 1) [0]
  set cumulative-dung-CH4 0
  set C-pi 722
  set methane-concentration C-pi
  set Temperature 0
  set temperature-anomaly 0
  set Radiative-Forcing-chosen 0
  set food-available 100
  ;; Ding, X.Z.; Long, R.J.; Kreuzer, M.; Mi, J.D.; Yang, B. (2010).
  ;; "Methane emissions from yak (Bos grunniens) steers grazing or kept
  ;; indoors and fed diets with varying forage:concentrate ratio during
  ;; the cold season on the Qinghai-Tibetan Plateau." Anim. Feed Sci.
  ;; Technol. 162:91-98. SF6 tracer measurements gave ~28 kg CH4/year
  ;; for grazing non-lactating yaks weighing 175 kg.
  set benchmark-EF-per-yak 28

  reset-ticks
end

to setup-patches
  ask patches [
    set pcolor green
    set is-dung-patch? false
    set dung-age 0
  ]
end

to set-up-variables
  set SSP_1_1_9 1.9
  set SSP_1_2_6 2.6
  set SSP_2_4_5 4.5
  set SSP_3_7_0 7.0
  set SSP_5_8_5 8.5

  ;; NE_ma (maintenance energy coefficients): kept in the IPCC/NRC
  ;; structural form; no yak-specific NE_ma coefficient table exists in
  ;; the literature reviewed, so these remain diet-quality proxies to
  ;; be calibrated locally rather than assumed equal to cattle defaults.
  let NE_ma_high_diet 7.5
  let NE_ma_moderate_diet 6.0
  let NE_ma_low_diet 4.5

  let C_a_grazing 0.36
  let C_a_supplemented 0.20
  let C_a_indoor 0.10

  let C_fi_lac 0.386
  let C_fi_non_lac 0.322

  let DE_high 65    ;; grazing alpine meadow forage rarely reaches feedlot-level DE
  let DE_moderate 55
  let DE_low 45

  ;; Feeding situation coefficient (replaces cattle "stall/pasture/grazing"
  ;; with yak-system categories matching Ding et al. 2010's design:
  ;; grazing vs. indoor oat-hay vs. concentrate-supplemented grazing)
  ifelse feeding-situation = "indoor-oat-hay" [
    set C_a_value C_a_indoor
  ] [
    ifelse feeding-situation = "supplemented-grazing" [
      set C_a_value C_a_supplemented
    ] [
      set C_a_value C_a_grazing
    ]
  ]

  ifelse C_fi_type = "lactating" [
    set C_fi_value C_fi_lac
  ] [
    set C_fi_value C_fi_non_lac
  ]

  ifelse diet-type = "high_quality" [
    set NE_ma_value NE_ma_high_diet
    set DE_percentage DE_high
  ] [
    ifelse diet-type = "moderate_quality" [
      set NE_ma_value NE_ma_moderate_diet
      set DE_percentage DE_moderate
    ] [
      if diet-type = "low_quality" [
        set NE_ma_value NE_ma_low_diet
        set DE_percentage DE_low
      ]
    ]
  ]

  update-Ym
end

;; ----------------------------------------------------------------
;; METHANE CONVERSION FACTOR (Ym) — yak-specific
;; ----------------------------------------------------------------
to update-Ym
  ;; Baseline: Ding et al. (2010) measured average GE lost as CH4 of
  ;; 54 +/- 15.2 kJ/MJ under QTP grazing/indoor cold-season conditions
  ;; = 5.4% +/- 1.5% of GE intake. This is markedly below the cattle
  ;; IPCC default of 6.5% (IPCC 2006 Tier 2), consistent with yak's
  ;; documented lower H2 production and methanogenesis-pathway
  ;; differences relative to cattle (Mi et al. 2017, PLOS ONE 12(1):
  ;; e0170044; Zhang et al. 2016, Curr. Biol. 26(14):1873-9).
  let base-Ym 5.4

  ifelse feeding-situation = "supplemented-grazing" [
    ;; Concentrate supplementation lowers enteric CH4 relative to
    ;; grazing/oat-hay-only diets:
    ;; - Ding et al. 2010: CH4 declined with F:C ratios of 0.6:0.4 and
    ;;   0.4:0.6 relative to oat hay alone.
    ;; - Ma et al. 2025, Animals 15(4):518: supplemental concentrate
    ;;   feeding during the warm season markedly lowered enteric CH4
    ;;   emissions while improving dietary energy efficiency.
    set Y_m base-Ym - 0.8
  ] [
    set Y_m base-Ym
  ]

  ;; Measurement variability observed in Ding et al. (2010), +/- 1.5
  set Y_m Y_m + (random-normal 0 1.5) * 0.1
  if Y_m < 2 [ set Y_m 2 ]  ;; floor to avoid non-physical values

  ;; NOTE: a 2025 Communications Earth & Environment meta-analysis
  ;; (Wang et al., "Methane emissions from indigenous nitrogen-efficient
  ;; bovidae are overestimated") found yak measured emissions were 39%
  ;; lower than IPCC Tier 2 model predictions — useful as an external
  ;; validation check on whatever Ym you calibrate to, not a Ym value
  ;; itself.
end

;; ----------------------------------------------------------------
;; MAIN LOOP
;; ----------------------------------------------------------------
to go
  if current-year <= end-year [
    regrow-grass
    regrow-food
    update-Ym
    ask turtles [
      age-turtle
      move-turtle
      consume-food
      reproduce
      die-if-needed
    ]
    update-dung-emissions
    update-population-and-ef
    update-radiative-forcing
    update-methane-emissions
    update-methane-concentration
    update-temperature
    tick
    set-current-plot "Methane Concentration Over Time"
    plot methane-concentration
    set-current-plot "Temperature Over Time"
    plot temperature
    set-current-plot "Population Over Time"
    plot count turtles
    set-current-plot "Enteric vs Dung CH4"
    set-current-plot-pen "enteric"
    plot cumulative_EF_final
    set-current-plot-pen "dung"
    plot cumulative-dung-CH4
    update-year
  ]
  if current-year > end-year [
    stop
  ]
end

to regrow-grass
  ask patches with [not is-dung-patch?] [
    set pcolor green
  ]
end

to regrow-food
  ;; Short QTP growing season (90-120 days) with sharp winter scarcity
  ;; is documented in the yak-adaptation literature (e.g. Bai et al.
  ;; 2021, Anim. Feed Sci. Technol. 281:115088, and seasonal feed-intake
  ;; dynamics referenced via Xue, Zhao & Zhang 2004, "Feed intake
  ;; dynamic of grazing livestock in natural grassland in Qinghai-
  ;; Tibetan Plateau," Ecol. Domest. Anim. 25:21-5).
  ;; Modeled here as a simple seasonal (sinusoidal) regrowth pulse
  ;; rather than a flat constant.
  let season-position (current-year - start-year) mod 1
  let seasonal-factor (0.5 + 0.5 * sin (360 * season-position))
  set food-available food-available + (5 * seasonal-factor) + 0.5
end

to age-turtle
  if age < 20 [
    set age age + 1
  ]
  set is-calf? (age < 1)
end

to move-turtle
  rt random 360
  fd 1
end

to consume-food
  if pcolor = green and food-available > 0 and not is-dung-patch? [
    set pcolor brown
    set food-available food-available - 0.1
    ;; Mark this patch as a fresh dung deposit. Dung patches, night
    ;; pens, and manure heaps are a distinct, non-trivial GHG source in
    ;; yak grazing systems, separate from enteric fermentation:
    ;; Liu, S. et al. (2017), "Key sources and seasonal dynamics of
    ;; greenhouse gas fluxes from yak grazing systems on the
    ;; Qinghai-Tibetan Plateau," Scientific Reports 7:40857. Found dung
    ;; deposition significantly increased CH4 emissions due to
    ;; dissolved CH4, large microbial populations, highly degradable
    ;; organic compounds, and anaerobic conditions of fresh patches.
    set is-dung-patch? true
    set dung-age 0
  ]
end

;; ----------------------------------------------------------------
;; REPRODUCTION — yak-specific demography
;; ----------------------------------------------------------------
to reproduce
  ;; Age at first breeding: 3-4 years, not 5 (Ivis.org, "An Overview of
  ;; the Reproductive Performance," in Recent Advances in Yak
  ;; Reproduction; FAO Ch.5 "Reproduction in the Yak," fao.org/4/ad347e).
  ;; Calving interval: female yak most likely calve once every two years
  ;; or twice in three years (FAO Ch.5). A regional statistic from
  ;; Hongyuan County, Sichuan (1976-1980) found 43.8% of ~500,000
  ;; breeding-age females produced a surviving calf in any given year —
  ;; used here as the default reproductive-rate.
  if sex = "female" and age >= 3 and years-since-last-calving >= 1 [
    if random-float 1 < reproductive-rate [
      hatch 1 [
        set age 0
        set sex one-of ["male" "female"]
        set is-calf? true
        set has-reproduced? false
        set years-since-last-calving 0
        set color one-of [red green blue]
        set enteric-emission-rate 0 ;; negligible enteric CH4 before rumen development
      ]
      set years-since-last-calving 0
      set has-reproduced? true
    ]
  ]
  if sex = "female" and age >= 3 [
    set years-since-last-calving years-since-last-calving + 1
  ]
end

to die-if-needed
  ;; Calf survival was 94% and 81% across two generations in an
  ;; inbreeding study (FAO Ch.5), i.e. first-year mortality roughly
  ;; 6-19% depending on herd management — distinct from, and higher
  ;; than, adult mortality.
  ;; NOTE: no literature-sourced adult yak mortality rate was found;
  ;; mortality-rate-adult is a free/calibration parameter, not a cited
  ;; value — calibrate it against known total Plateau population
  ;; figures (~13-16 million yaks) rather than trust a default.
  let mortality-to-use mortality-rate-adult
  if is-calf? [ set mortality-to-use mortality-rate-calf ]
  if random-float 1 < mortality-to-use or age >= 20 [
    die
  ]
end

to update-year
  set current-year start-year + ticks
  if current-year > end-year [
    stop
  ]
end

;; ----------------------------------------------------------------
;; DUNG/MANURE EMISSIONS (new module — not present in cattle version)
;; ----------------------------------------------------------------
to update-dung-emissions
  let total-dung-CH4 0
  ask patches with [is-dung-patch?] [
    ;; Simplified exponential decay: freshest dung patches have highest
    ;; flux (moist, anaerobic, high microbial load), declining as the
    ;; patch dries and mineralizes.
    ;; Liu et al. 2017 (Scientific Reports 7:40857) measured CO2, CH4,
    ;; N2O fluxes from alpine meadows, dung patches, manure heaps, and
    ;; night pens on the QTP, finding CH4 and N2O contributed 21.1% and
    ;; 44.8% respectively to a total annual GWP budget of 334.2 tonnes
    ;; CO2-eq from family-farm grazing yaks.
    ;; dung-CH4-per-patch is a calibration constant: tune it so
    ;; cumulative-dung-CH4 tracks toward roughly 21% of total system
    ;; CH4-equivalent GWP for your chosen herd size and area — the
    ;; source study does not give a universal per-patch constant.
    let flux dung-CH4-per-patch * exp (-0.3 * dung-age)
    set total-dung-CH4 total-dung-CH4 + flux
    set dung-age dung-age + 1
    if dung-age > 10 [
      set is-dung-patch? false
      set pcolor green
    ]
  ]
  let year-index (current-year - start-year)
  if year-index >= 0 and year-index < length dung-CH4-each-year [
    set dung-CH4-each-year replace-item year-index dung-CH4-each-year total-dung-CH4
  ]
  set cumulative-dung-CH4 cumulative-dung-CH4 + total-dung-CH4
end

;; ----------------------------------------------------------------
;; ENTERIC EMISSION FACTOR (Tier-2-style, yak-parameterized)
;; ----------------------------------------------------------------
to-report calculate-values
  let NE_a (C_a_value * NE_ma_value)
  let NE_G (22.02 * (avg_live_body_weight / (0.8 * moderate_body_condition)) * (avg_daily_weight_gain ^ 1.097))
  let NE_L ((Amt_of_milk_produced / 365) * (1.47 + 0.40 * 0.04))
  let NE_W (0.10 * NE_ma_value * No_of_hrs_worked_in_a_day)
  let NE_P (0.10 * NE_ma_value)
  let REM (1.123 - (4.092 * 10 ^ -3 * DE_percentage) + (1.126 * 10 ^ -5 * (DE_percentage ^ 2)) - (25.4 / DE_percentage))
  let REG (1.164 - (5.160 * 10 ^ -3 * DE_percentage) + (1.308 * 10 ^ -5 * (DE_percentage ^ 2)) - (37.4 / DE_percentage))
  let GE (((NE_ma_value + NE_a + NE_L + NE_W + NE_P) / REM) + ((NE_G) / REG)) / (DE_percentage / 100)
  let EF ((GE * (Y_m / 100) * 365) / 55.65)
  let EF_CO2eq EF * 28   ;; GWP of CH4 = 28 (IPCC AR5, common to both cattle/yak models)
  report EF_CO2eq
end

to update-population-and-ef
  let year-index (current-year - start-year)
  if year-index >= 0 and year-index < length populations [
    set populations replace-item year-index populations count turtles
    let EF_CO2eq_current_year calculate-values
    set EF_final_each_year replace-item year-index EF_final_each_year (EF_CO2eq_current_year * item year-index populations)
    set cumulative_EF_final sum EF_final_each_year
  ]
end

;; ----------------------------------------------------------------
;; VALIDATION CHECK against Ding et al. (2010) field benchmark
;; ----------------------------------------------------------------
to-report validation-ratio
  ;; Compares modeled average annual enteric CH4 per yak (kg CH4/yr,
  ;; back-converted from CO2-eq using GWP=28) against the ~28 kg
  ;; CH4/yr benchmark measured for a 175 kg grazing non-lactating yak
  ;; via SF6 tracer technique (Ding et al. 2010). A ratio near 1.0
  ;; suggests your calibration is in the right range; far from 1.0
  ;; means Y_m, DE_percentage, or NE_ma need adjustment.
  if count turtles = 0 [ report 0 ]
  let model-EF-CO2eq (calculate-values)
  let model-EF-CH4-kg (model-EF-CO2eq / 28)
  report model-EF-CH4-kg / benchmark-EF-per-yak
end

;; ----------------------------------------------------------------
;; CLIMATE BOX MODEL (unchanged structurally — not yak-specific)
;; ----------------------------------------------------------------
to update-radiative-forcing
  if SSP-Scenario = "SSP_1-1.9" [
    set Radiative-Forcing-chosen SSP_1_1_9
    set beta 0.2  set sigma 0.1  set mu 0.01  set alpha 0.02
  ]
  ifelse SSP-Scenario = "SSP_1-2.6" [
    set Radiative-Forcing-chosen SSP_1_2_6
    set beta 0.3  set sigma 0.12  set mu 0.02  set alpha 0.025
  ] [
    ifelse SSP-Scenario = "SSP_2-4.5" [
      set Radiative-Forcing-chosen SSP_2_4_5
      set beta 0.35  set sigma 0.15  set mu 0.03  set alpha 0.03
    ] [
      ifelse SSP-Scenario = "SSP_3-7.0" [
        set Radiative-Forcing-chosen SSP_3_7_0
        set beta 0.4  set sigma 0.2  set mu 0.05  set alpha 0.04
      ] [
        ifelse SSP-Scenario = "SSP_5-8.5" [
          set Radiative-Forcing-chosen SSP_5_8_5
          set beta 0.45  set sigma 0.25  set mu 0.07  set alpha 0.05
        ] [
          set Radiative-Forcing-chosen 1.9
          set beta 0.2  set sigma 0.1  set mu 0.01  set alpha 0.02
        ]
      ]
    ]
  ]
end

to update-methane-emissions
  ;; Total system CH4 now includes both enteric (per-turtle emission-rate)
  ;; and dung-patch flux, reflecting Liu et al. (2017)'s finding that
  ;; non-enteric sources are a material share of total system CH4.
  let total-emissions (sum [enteric-emission-rate] of turtles) + cumulative-dung-CH4
  set radiative-forcing total-emissions * Radiative-Forcing-chosen
end

to update-methane-concentration
  let C-dot (beta * Radiative-Forcing-chosen + B * cumulative_EF_final - sigma * methane-concentration)
  set methane-concentration methane-concentration + C-dot
end

to update-temperature
  let c-small (methane-concentration / C-pi)
  set T-dot (mu * ln c-small - alpha * temperature)
  set temperature temperature + T-dot
end

to-report T-dot-value
  report T-dot
end

to-report food-level
  report food-available
end

to-report population-count
  report count turtles
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
647
448
-1
-1
13.0
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
17
25
80
58
NIL
setup
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
107
27
170
60
NIL
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
24
85
196
118
number-of-yaks
number-of-yaks
0
60000
100.0
100
1
NIL
HORIZONTAL

SLIDER
31
137
203
170
Emission-Rate
Emission-Rate
0
100
1.0
1
1
NIL
HORIZONTAL

SLIDER
30
197
202
230
reproductive-rate
reproductive-rate
0
1
0.44
0.1
1
NIL
HORIZONTAL

SLIDER
34
249
206
282
mortality-rate-calf
mortality-rate-calf
0
0.3
0.15
0.01
1
NIL
HORIZONTAL

SLIDER
38
297
210
330
mortality-rate-adult
mortality-rate-adult
0
0.3
0.05
0.01
1
NIL
HORIZONTAL

SLIDER
43
358
215
391
avg_live_body_weight
avg_live_body_weight
0
500
175.0
50
1
NIL
HORIZONTAL

SLIDER
43
421
215
454
avg_daily_weight_gain
avg_daily_weight_gain
0
50
0.1
1
1
NIL
HORIZONTAL

SLIDER
47
476
251
509
Amt_of_milk_produced
Amt_of_milk_produced
0
100
0.0
1
1
per yr
HORIZONTAL

SLIDER
47
531
248
564
No_of_hrs_worked_in_a_day
No_of_hrs_worked_in_a_day
0
24
0.0
1
1
NIL
HORIZONTAL

SLIDER
290
465
475
498
moderate_body_condition
moderate_body_condition
0.5
1.5
1.0
0.1
1
NIL
HORIZONTAL

SLIDER
307
517
479
550
beta
beta
0
0.5
0.35
0.01
1
NIL
HORIZONTAL

SLIDER
500
516
672
549
sigma
sigma
0
0.3
0.15
0.01
1
NIL
HORIZONTAL

SLIDER
512
469
684
502
mu
mu
0
0.1
0.03
0.001
1
NIL
HORIZONTAL

SLIDER
312
564
484
597
alpha
alpha
0
0.1
0.03
0.01
1
NIL
HORIZONTAL

SLIDER
518
568
690
601
B
B
0
1
0.1
0.1
1
NIL
HORIZONTAL

SLIDER
669
25
841
58
dung-CH4-per-patch
dung-CH4-per-patch
0
2
0.5
0.1
1
NIL
HORIZONTAL

CHOOSER
688
97
854
142
feeding-situation
feeding-situation
"grazing" "supplemented-grazing" "indoor-oat-hay"
0

CHOOSER
696
163
836
208
diet-type
diet-type
"high_quality" "moderate_quality" "low_quality"
1

CHOOSER
708
237
846
282
C_fi_type
C_fi_type
"lactating" "non_lactating"
1

CHOOSER
708
304
846
349
SSP-Scenario
SSP-Scenario
"SSP_1-1.9" "SSP_1-2.6" "SSP_2-4.5" "SSP_3-7.0" "SSP_5-8.5"
2

MONITOR
724
386
834
431
NIL
population-count
17
1
11

MONITOR
854
385
939
430
NIL
current-year
17
1
11

MONITOR
737
447
794
492
NIL
Y_m
17
1
11

MONITOR
841
455
965
500
NIL
cumulative_EF_final
17
1
11

MONITOR
749
513
885
558
NIL
cumulative-dung-CH4
17
1
11

MONITOR
909
524
1004
569
NIL
validation-ratio
17
1
11

MONITOR
972
388
1061
433
NIL
food-available
17
1
11

MONITOR
992
447
1095
492
NIL
radiative-forcing
17
1
11

PLOT
933
19
1133
169
Methane Concentration Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot methane-concentration"

PLOT
1190
22
1390
172
Temperature Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot temperature"

PLOT
946
191
1146
341
Population Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

PLOT
1216
201
1416
351
Enteric vs Dung CH4
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"enteric" 1.0 0 -7500403 true "" ""
"dung" 1.0 0 -2674135 true "" ""

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="quick-test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5"/>
    <metric>methane-concentration</metric>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="number-of-yaks">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="B">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sigma">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="C_fi_type">
      <value value="&quot;non_lactating&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="No_of_hrs_worked_in_a_day">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproductive-rate">
      <value value="0.44"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="feeding-situation">
      <value value="&quot;grazing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mortality-rate-adult">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SSP-Scenario">
      <value value="&quot;SSP_2-4.5&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mu">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg_live_body_weight">
      <value value="175"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="moderate_body_condition">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diet-type">
      <value value="&quot;moderate_quality&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Emission-Rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Amt_of_milk_produced">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dung-CH4-per-patch">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg_daily_weight_gain">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mortality-rate-calf">
      <value value="0.15"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="mitigation-under-ssp" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="85"/>
    <metric>methane-concentration</metric>
    <metric>temperature</metric>
    <metric>cumulative_EF_final</metric>
    <metric>cumulative-dung-CH4</metric>
    <metric>validation-ratio</metric>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="number-of-yaks">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="B">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="sigma">
      <value value="0.15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="C_fi_type">
      <value value="&quot;non_lactating&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="No_of_hrs_worked_in_a_day">
      <value value="0"/>
      <value value="4"/>
      <value value="8"/>
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="alpha">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="reproductive-rate">
      <value value="0.44"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="beta">
      <value value="0.35"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="feeding-situation">
      <value value="&quot;grazing&quot;"/>
      <value value="&quot;supplemented-grazing&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mortality-rate-adult">
      <value value="0.05"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="SSP-Scenario">
      <value value="&quot;SSP_1-2.6&quot;"/>
      <value value="&quot;SSP_2-4.5&quot;"/>
      <value value="&quot;SSP_3-7.0&quot;"/>
      <value value="&quot;SSP_5-8.5&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mu">
      <value value="0.03"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg_live_body_weight">
      <value value="175"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="moderate_body_condition">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="diet-type">
      <value value="&quot;moderate_quality&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Emission-Rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Amt_of_milk_produced">
      <value value="0"/>
      <value value="10"/>
      <value value="50"/>
      <value value="100"/>
      <value value="200"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dung-CH4-per-patch">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="avg_daily_weight_gain">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mortality-rate-calf">
      <value value="0.15"/>
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
