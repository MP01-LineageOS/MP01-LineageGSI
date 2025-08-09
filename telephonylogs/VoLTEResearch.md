# VoLTEResearch.md

Trying to debug the "Server Unreachable" issues

Debug commands:
```
adb shell getprop | grep -i md # a lot of modem stats
```

"Good" (In-Service - VoLTE on and working) state example:
```
[init.svc.ccci_mdinit]: [running]
[init.svc.volte_md_status]: [running]
[kcmdline.binder]: [c]
[kcmdline.loaded]: [1]
[persist.log.tag.RILMD2-SS]: [I]
[persist.vendor.md_c2k_cap_dep_check]: [0]
[persist.vendor.mdrsra_v2_support]: [1]
[persist.vendor.sys.pq.mdp.ccorr.en]: [1]
[persist.vendor.sys.pq.mdp.color.dbg]: [1]
[persist.vendor.sys.pq.mdp.color.idx]: [1]
[persist.vendor.sys.pq.mdp.dre.en]: [1]
[persist.vendor.sys.pq.mdp.hdrvivid.vp.dre.en]: [1]
[persist.vendor.sys.pq.mdp.hdrvp.dre.en]: [1]
[persist.vendor.sys.pq.mdp.vp.aispq.en]: [1]
[persist.vendor.sys.pq.mdp.vp.dre.en]: [1]
[pm.dexopt.cmdline]: [verify]
[ro.vendor.md_apps.load_date]: [2025/01/15 21:46:38 GMT +08:00]
[ro.vendor.md_apps.load_gencfg]: [GEN95_USER]
[ro.vendor.md_apps.load_type]: [user]
[ro.vendor.md_apps.load_verno]: [MOLY.LR13.R2.MP.V184]
[ro.vendor.md_apps.support]: [1]
[ro.vendor.md_auto_setup_ims]: [1]
[ro.vendor.md_mims_support]: [2]
[ro.vendor.md_prop_ver]: [1]
[ro.vendor.mtk_flight_mode_power_off_md]: [1]
[ro.vendor.mtk_md_world_mode_support]: [1]
[ro.vendor.num_md_protocol]: [2]
[ro.vendor.pq.mtk_mdp_ccorr_support]: [0]
[ro.vendor.pq.mtk_mdp_lite_pq_support]: [0]
[vendor.mtk.md.sbp]: [0]
[vendor.mtk.md1.status]: [ready]
[vendor.ril.active.md]: [9]
[vendor.ril.mux.ee.md1]: [0]
```

Fail Example:
[init.svc.ccci_mdinit]: [running]
[init.svc.volte_md_status]: [running]
[kcmdline.binder]: [c]
[kcmdline.loaded]: [1]
[persist.log.tag.RILMD2-SS]: [I]
[persist.vendor.md_c2k_cap_dep_check]: [0]
[persist.vendor.mdrsra_v2_support]: [1]
[persist.vendor.sys.pq.mdp.ccorr.en]: [1]
[persist.vendor.sys.pq.mdp.color.dbg]: [1]
[persist.vendor.sys.pq.mdp.color.idx]: [1]
[persist.vendor.sys.pq.mdp.dre.en]: [1]
[persist.vendor.sys.pq.mdp.hdrvivid.vp.dre.en]: [1]
[persist.vendor.sys.pq.mdp.hdrvp.dre.en]: [1]
[persist.vendor.sys.pq.mdp.vp.aispq.en]: [1]
[persist.vendor.sys.pq.mdp.vp.dre.en]: [1]
[pm.dexopt.cmdline]: [verify]
[ro.vendor.md_apps.load_date]: [2025/01/15 21:46:38 GMT +08:00]
[ro.vendor.md_apps.load_gencfg]: [GEN95_USER]
[ro.vendor.md_apps.load_type]: [user]
[ro.vendor.md_apps.load_verno]: [MOLY.LR13.R2.MP.V184]
[ro.vendor.md_apps.support]: [1]
[ro.vendor.md_auto_setup_ims]: [1]
[ro.vendor.md_mims_support]: [2]
[ro.vendor.md_prop_ver]: [1]
[ro.vendor.mtk_flight_mode_power_off_md]: [1]
[ro.vendor.mtk_md_world_mode_support]: [1]
[ro.vendor.num_md_protocol]: [2]
[ro.vendor.pq.mtk_mdp_ccorr_support]: [0]
[ro.vendor.pq.mtk_mdp_lite_pq_support]: [0]
[vendor.mtk.md.sbp]: [0]
[vendor.mtk.md1.status]: [ready]
[vendor.ril.active.md]: [9]
[vendor.ril.mux.ee.md1]: [0]


Carrier: Telstra
OS: LineageOS (system-1754590735)
Location/Activity: Shopping
Notes: Noticed after driving to shopping center, unable to call while in store.

