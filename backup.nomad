job "nomad-cluster-backup" {
  datacenters = ["dc1"]
  namespace   = "default"
  type        = "batch"

  periodic {
    cron             = "0 3 * * *" # At 3 AM everyday
    prohibit_overlap = true
    time_zone        = "Asia/Kolkata"
  }

  group "backup" {
    count = 1
    network {
      mode = "host"
    }

    task "app" {
      driver = "raw_exec"

      template {
        data        = <<EOH
{{- with nomadVar "nomad/jobs/nomad-cluster-backup" }}
NOMAD_TOKEN="{{ .NOMAD_TOKEN }}"
{{- end }}
EOH
        destination = "secrets/file.env"
        env         = true
      }

      template {
        data        = file(abspath("./backup.sh"))
        destination = "$${NOMAD_TASK_DIR}/backup.sh"
        perms       = "755"
      }

      env {
        NOMAD_BACKUP_S3_BUCKET = "my-nomad-backups"
      }

      config {
        command = "$${NOMAD_TASK_DIR}/backup.sh"
      }

    }
  }
}
