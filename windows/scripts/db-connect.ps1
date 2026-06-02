param(
    [int]$PORT
)

try {

    $listener = Get-NetTCPConnection `
        -LocalPort $PORT `
        -State Listen `
        -ErrorAction Stop

    if ($listener) {

        Write-Host "Tunnel already active on port $PORT"

        exit 0
    }

}
catch {
    # Port not listening
}

# ---------------------------------------------------
# OPEN TUNNEL
# ---------------------------------------------------

switch ($PORT) {

    3411 { rds prod audinteldb }
    3412 { rds prod auspigroup }
    3413 { rds prod chrobinsondb }
    3414 { rds prod ffsdb }
    3415 { rds prod idrivedb }
    3416 { rds prod redwood }
    3417 { rds prod shiphawk }

    3307 { rds uat uat-aud1-encrypted }
    3308 { rds uat uat-chr }
    3309 { rds uat uat-ffs }
    3310 { rds uat uat-auspi }
    3311 { rds uat uat-redwood }

    default {

        Write-Host "Unknown port: $PORT"
        exit 1
    }
}