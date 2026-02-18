# UT2004 Dedicated Server (Docker)

Containerized Unreal Tournament 2004 dedicated server built on the [OldUnreal](https://github.com/OldUnreal) community installer.

## Quick start (local)

```bash
# Build the image
make build

# Start the server
make run

# Tail logs
make logs

# Stop
make stop
```

Or with plain Docker:

```bash
docker build -t ut2004-server .
docker run -d --name ut2004 \
  -p 7777:7777/udp \
  -p 7778:7778/udp \
  -p 7787:7787/udp \
  ut2004-server
```

## Deploy to AWS Fargate

The included CloudFormation template creates everything from scratch — VPC, subnets, ECS cluster, Fargate service, ECR repo, and IAM roles. The default task size (0.25 vCPU / 512 MB) fits within the [Fargate free tier](https://aws.amazon.com/fargate/pricing/) (750 hrs/month for 12 months on new accounts).

### Prerequisites

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) configured (`aws configure`)
- Docker running locally (to build and push the image)

### Deploy

```bash
# 1. Create the stack (VPC, ECS cluster, ECR repo, etc.)
make deploy

# 2. Build the image and push it to ECR — also triggers a new ECS deployment
make push

# 3. Get your server's public IP (wait ~1 min for the task to start)
make server-ip
```

Connect in UT2004 with the IP from step 3, port 7777.

### Other AWS commands

```bash
# Tail server logs in CloudWatch
make aws-logs

# Tear down everything
make teardown
```

### Changing game settings

Pass CloudFormation parameter overrides when deploying:

```bash
aws cloudformation deploy \
  --template-file cloudformation.yml \
  --stack-name ut2004-server \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides Map=CTF-Face3 Game=XGame.xCTFGame
```

Then force a new deployment so the running task picks up the change:

```bash
aws ecs update-service --cluster ut2004 --service ut2004-server --force-new-deployment
```

### Cost notes

| Resource | Free tier | After free tier |
|----------|-----------|-----------------|
| Fargate (0.25 vCPU / 512 MB) | 750 hrs/month for 12 months | ~$9/month 24/7 |
| ECR storage | 500 MB/month | $0.10/GB/month |
| CloudWatch Logs | 5 GB ingest + 5 GB storage | $0.50/GB ingest |
| VPC / Public IP | No charge for the VPC itself | $0.005/hr for public IPv4 (~$3.60/mo) |

Set `DesiredCount` to `0` to pause the server without tearing down the stack.

## CI/CD with GitHub Actions

Two workflows live in `.github/workflows/`:

| Workflow | Trigger | What it does |
|----------|---------|--------------|
| **Deploy** (`deploy.yml`) | Push to `main`, or manual | Builds image, pushes to ECR, forces new ECS deployment, prints the server IP in the job summary |
| **Infrastructure** (`infra.yml`) | Manual only | Creates/updates or tears down the CloudFormation stack with configurable map, game type, and desired count |

### Setup

Add these to your repo under **Settings > Secrets and variables > Actions**:

**Secrets** (pick one auth method):

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |

**Variables**:

| Variable | Default | Description |
|----------|---------|-------------|
| `AWS_REGION` | `eu-north-1` | Region where the stack lives |
| `AWS_ROLE_ARN` | _(none)_ | If set, uses OIDC role assumption instead of access keys (recommended) |

### First-time setup

1. Run the **Infrastructure** workflow with action = `deploy` to create the stack
2. Push to `main` (or run **Deploy** manually) to build and ship the image
3. The deploy job summary will show the server IP when it's ready

After that, every push to `main` automatically builds and deploys.

## Configuration

All runtime settings are controlled via environment variables. Copy `.env.example` to `.env` and tweak as needed — `docker compose` picks it up automatically.

| Variable    | Default              | Description                    |
|-------------|----------------------|--------------------------------|
| `MAP`       | `DM-Rankin`          | Starting map                   |
| `GAME`      | `XGame.xDeathMatch`  | Game type class                |
| `PORT`      | `7777`               | Game port (UDP)                |
| `QUERYPORT` | `7778`               | Query / status port (UDP)      |

### Common game types

| Class                          | Mode              |
|--------------------------------|-------------------|
| `XGame.xDeathMatch`           | Deathmatch        |
| `XGame.xTeamGame`             | Team Deathmatch   |
| `XGame.xCTFGame`              | Capture the Flag  |
| `XGame.xBombingRun`           | Bombing Run       |
| `XGame.xDoubleDom`            | Double Domination |
| `Onslaught.ONSOnslaughtGame`  | Onslaught         |
| `SkaarjPack.Invasion`         | Invasion          |

## Ports

| Port | Protocol | Purpose                                |
|------|----------|----------------------------------------|
| 7777 | UDP      | Game traffic                           |
| 7778 | UDP      | Game traffic (PORT+1, used internally) |
| 7787 | UDP      | Server query / browser list            |

## Volumes (local only)

The compose file mounts a named volume at `/opt/ut2004/System` so your `UT2004.ini` and other config edits persist across container restarts.

To start completely fresh:

```bash
make clean
```

## Custom command

Pass arguments to override the default server launch:

```bash
docker run --rm -it ut2004-server bash
```
