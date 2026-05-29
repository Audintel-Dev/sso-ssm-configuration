param(
    [int]$PORT
)

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

    default {

        Write-Host "Unknown port: $PORT"
        exit 1
    }
}