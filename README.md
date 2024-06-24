<a href="https://zerodha.tech"><img src="https://zerodha.tech/static/images/github-badge.svg" align="right" /></a>

# nomad-cluster-backup

`nomad-cluster-backup` is a script designed to create full backups of a Nomad cluster, including its state and variables, and store them in an S3 bucket.

## Features

- Takes a full snapshot of the Nomad cluster, including:
  - ACL Policies
  - Job configurations
  - Allocations
  - Nodes
  - CSI Plugins
  - Other cluster state information
- Creates a raw dump of all Nomad variables across all namespaces
- Stores backups in an S3 bucket

## Configuration

Set the following environment variable:

- `NOMAD_BACKUP_S3_BUCKET`: The name of the S3 bucket where backups will be stored.
- `NOMAD_TOKEN`: A Nomad ACL token with management policy access. This is required to read variables across namespaces and retrieve the cluster state.

### Obtaining a Management Token

To create a management token for the backup process, run the following command:

```bash
nomad acl token create -name="nomad-vars-backup-admin" -type="management"
```

This command will output a new management token. Make sure to save this token securely, in Vault/Nomad variables as it provides full access to your Nomad cluster.

Example:

```bash
export NOMAD_BACKUP_S3_BUCKET="my-nomad-backups"
export NOMAD_TOKEN="xxxx"
```

## Usage

Run the script:

```
./nomad-cluster-backup.sh
```


## S3 Bucket Structure

The backups will be stored in the S3 bucket with the following structure:

```bash
s3://your-bucket-name/
├── vars/
│   ├── namespace1/
│   │   ├── path1.json
│   │   └── path2.json
│   └── namespace2/
│       └── path1.json
└── cluster/
    └── state.json
```

## Security Considerations

- Ensure your S3 bucket is encrypted, as it will contain sensitive information.
- Use appropriate IAM policies to restrict access to the S3 bucket.

## Deploying to Nomad

You can run this job as a periodic job to take regular backups of your Nomad cluster.

Refer to the sample [job spec](./backup.nomad) for more details.