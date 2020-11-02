plugins {
    id("idea")
}

val tfBin = "${rootDir}/terraform/terraform_0.13.5_linux_amd64"
val tfSrc = "${rootDir}/src/main/terraform/"
val tfCfg = "${rootDir}/config/backend.config"

tasks {
    task<Exec>("tfInit") {
        commandLine(tfBin, "init", "-backend-config=${tfCfg}", tfSrc)
    }
    task<Exec>("tfPlan") {
        commandLine(tfBin, "plan", tfSrc)
    }
    task<Exec>("tfApply") {
        commandLine(tfBin, "apply", "-auto-approve", tfSrc)
    }
}