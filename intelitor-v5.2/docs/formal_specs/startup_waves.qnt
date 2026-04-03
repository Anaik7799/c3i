module StartupWaves {
    type HolonStatus = Off | Starting | Ready | Failsafe
    
    var db_status: HolonStatus
    var obs_status: HolonStatus
    var app_status: HolonStatus
    var step: int

    action init = all {
        db_status' = Off,
        obs_status' = Off,
        app_status' = Off,
        step' = 0
    }

    action wave1 = all {
        step == 0,
        db_status' = Ready,
        obs_status' = obs_status,
        app_status' = app_status,
        step' = 1
    }

    action wave2 = all {
        step == 1,
        db_status == Ready,
        db_status' = db_status,
        obs_status' = Ready,
        app_status' = app_status,
        step' = 2
    }

    action wave3 = all {
        step == 2,
        obs_status == Ready,
        db_status' = db_status,
        obs_status' = obs_status,
        app_status' = Ready,
        step' = 3
    }

    action step_idle = all {
        step == 3,
        db_status' = db_status,
        obs_status' = obs_status,
        app_status' = app_status,
        step' = step
    }

    action step_next = any {
        wave1,
        wave2,
        wave3,
        step_idle
    }

    // Invariant: If App is ready, DB MUST be ready
    val safety_invariant = (app_status == Ready) implies (db_status == Ready)
}