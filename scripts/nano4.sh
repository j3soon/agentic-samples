#!/usr/bin/env bash
# Shared local interface for humans and coding agents. Requires Linux/macOS/WSL.
set -euo pipefail
# Resolve repository files independently of the caller's working directory.
repo_dir=$(cd "$(dirname "$0")/.." && pwd)
config="$repo_dir/secrets/.env"
command=${1:-help}
if [[ $# -gt 0 ]]; then shift; fi

if [[ "$command" == help ]]; then
  cat <<'HELP'
Usage: bash scripts/nano4.sh COMMAND [ARGS...]
  configure USER PROJECT
  login | check | logout
  exec COMMAND [ARGS...]
  prepare IMAGE_URI SIF_NAME [SRUN_OPTIONS...]
  submit JOB_SCRIPT [JOB_ARGS...]
  status
  fetch [RELATIVE_PATHS...]  (default: logs outputs submission)

NCHC_REMOTE_DIR selects a remote run directory (one submission per directory).
HELP
  exit 0
fi

if [[ "$command" == configure ]]; then
  [[ $# == 2 && $1 =~ ^[a-zA-Z0-9_-]+$ && $2 =~ ^[a-zA-Z0-9_-]+$ ]] || {
    echo 'Usage: configure USER PROJECT (letters, digits, underscores, hyphens)' >&2; exit 2;
  }
  mkdir -p "$repo_dir/secrets"
  # Store only account identifiers, with permissions restricted to this user.
  (umask 077; printf 'NCHC_ISERVICE_HOST_ACCOUNT=%s\nNCHC_ISERVICE_PROJECT_ID=%s\n' "$1" "$2" > "$config")
  chmod 600 "$config"
  echo 'Saved username and project ID in secrets/.env.'
  exit 0
fi

if [[ ! -f "$config" ]]; then
  echo 'Run configure USER PROJECT first.' >&2; exit 2
fi
# Read only the two supported values, without executing the configuration file.
while IFS='=' read -r key value; do
  value=${value%$'\r'}
  case "$key" in
    NCHC_ISERVICE_HOST_ACCOUNT) NCHC_ISERVICE_HOST_ACCOUNT=$value ;;
    NCHC_ISERVICE_PROJECT_ID) NCHC_ISERVICE_PROJECT_ID=$value ;;
  esac
done < "$config"
[[ ${NCHC_ISERVICE_HOST_ACCOUNT:-} =~ ^[a-zA-Z0-9_-]+$ && ${NCHC_ISERVICE_PROJECT_ID:-} =~ ^[a-zA-Z0-9_-]+$ ]] || {
  echo 'Configure a valid username and project ID first.' >&2; exit 2;
}
remote_dir=${NCHC_REMOTE_DIR:-/work/$NCHC_ISERVICE_HOST_ACCOUNT/agentic-samples}
[[ "$remote_dir" == /* && "$remote_dir" != *$'\n'* ]] || { echo 'Remote directory must be absolute.' >&2; exit 2; }
# A private control socket lets commands reuse one password/MFA authentication.
# OpenSSH expands %C to a hash of the connection's host, user, and port details.
control_dir="$HOME/.ssh/nano4-control"
mkdir -p "$control_dir"
chmod 700 "$control_dir"
ssh_options=(-p 22 -o "ControlPath=$control_dir/%C" -o ConnectTimeout=15)
target="$NCHC_ISERVICE_HOST_ACCOUNT@nano4.nchc.org.tw"

case "$command" in
  login)
    # A running master is useful only if it can also open remote sessions.
    if ssh "${ssh_options[@]}" -O check "$target" 2>/dev/null; then
      if ssh "${ssh_options[@]}" -o BatchMode=yes "$target" true; then exit 0; fi
      echo 'Replacing a connection that cannot open remote sessions.' >&2
      ssh "${ssh_options[@]}" -O exit "$target"
    fi
    [[ -t 0 && -t 1 ]] || {
      echo 'Authentication requires your terminal. Run: bash scripts/nano4.sh login' >&2; exit 10;
    }
    ssh "${ssh_options[@]}" -o ControlMaster=yes -o ControlPersist=yes -Nf "$target"
    ssh "${ssh_options[@]}" -O check "$target"
    ssh "${ssh_options[@]}" -o BatchMode=yes "$target" true
    exit 0 ;;
  check)
    ssh "${ssh_options[@]}" -O check "$target"
    ssh "${ssh_options[@]}" -o BatchMode=yes "$target" true
    exit $? ;;
  logout) ssh "${ssh_options[@]}" -O exit "$target"; exit $? ;;
  exec|prepare|submit|status|fetch) ;;
  *) echo "Unknown command: $command" >&2; exit 2 ;;
esac

ssh "${ssh_options[@]}" -O check "$target" >/dev/null 2>&1 || {
  echo 'Authentication needed. Run bash scripts/nano4.sh login in your terminal, then retry.' >&2
  exit 10
}
# BatchMode prevents unexpected password prompts if the shared connection expires.
ssh_options+=(-o BatchMode=yes -o ControlMaster=no)
if [[ "$command" == exec ]]; then
  [[ $# -gt 0 ]] || { echo 'exec requires a remote command.' >&2; exit 2; }
  # SSH sends a command string. Quote each argument for the remote shell.
  printf -v remote_command '%q ' "$@"
  ssh "${ssh_options[@]}" "$target" "$remote_command"
  exit $?
fi

if [[ "$command" == prepare ]]; then
  [[ $# -ge 2 && $2 =~ ^[a-zA-Z0-9_.-]+\.sif$ ]] || {
    echo 'Usage: prepare IMAGE_URI SIF_NAME [SRUN_OPTIONS...]' >&2; exit 2;
  }
  image_uri=$1
  image_name=$2
  shift 2
  account=$(printf '%s' "$NCHC_ISERVICE_PROJECT_ID" | tr '[:upper:]' '[:lower:]')
  printf -v remote_command 'mkdir -p %q && cat > %q' "$remote_dir" "$remote_dir/prepare.sh"
  ssh "${ssh_options[@]}" "$target" "$remote_command" < "$repo_dir/cluster/nano4/prepare.sh"
  # Build on an allocated compute node. Caller-supplied srun options follow
  # the defaults so they can override resources without editing this script.
  printf -v remote_command '%q ' srun --account="$account" --partition=dev \
    --nodes=1 --ntasks=1 --gpus-per-node=1 --cpus-per-task=8 --mem=96G \
    --time=00:30:00 "$@" bash "$remote_dir/prepare.sh" "$remote_dir" "$image_uri" "$image_name"
  ssh "${ssh_options[@]}" "$target" "$remote_command"
elif [[ "$command" == submit ]]; then
  [[ $# -ge 1 && -f $1 ]] || { echo 'Usage: submit JOB_SCRIPT [JOB_ARGS...]' >&2; exit 2; }
  job_script=$1
  shift
  # Transfer only this small job script through the existing login connection.
  printf -v remote_command 'mkdir -p %q && cat > %q' "$remote_dir" "$remote_dir/job.slurm"
  ssh "${ssh_options[@]}" "$target" "$remote_command" < "$job_script"
  printf -v remote_command '%q ' bash -s -- "$remote_dir" "$NCHC_ISERVICE_PROJECT_ID" "$@"
  # Quoted heredocs execute remotely without expanding local shell variables.
  ssh "${ssh_options[@]}" "$target" "$remote_command" <<'REMOTE'
set -euo pipefail
cd "$1"
account=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
shift 2
if [[ -f submission/job-id ]]; then
  echo "Already submitted job $(cat submission/job-id). Use status."
  exit 0
fi
# A durable marker prevents automatic duplicate submission after a lost response.
mkdir submission || {
  echo 'Submission outcome is uncertain. Inspect squeue/sacct before retrying.' >&2; exit 3;
}
mkdir -p logs outputs
# Slurm opens output files before the job starts, so their directories must exist.
cp job.slurm submission/job.slurm
if job_id=$(sbatch --parsable --account="$account" job.slurm "$@"); then
  job_id=${job_id%%;*}
  [[ "$job_id" =~ ^[0-9]+$ ]] || { echo 'Unexpected sbatch response. Inspect Slurm before retrying.' >&2; exit 3; }
  printf '%s\n' "$job_id" > submission/job-id
  echo "Submitted job $job_id"
else
  echo 'Submission failed. Inspect Slurm and the submission marker before retrying.' >&2
  exit 3
fi
REMOTE
elif [[ "$command" == status ]]; then
  # Query the recorded job once, including accounting after it leaves the queue.
  printf -v remote_command 'bash -s -- %q' "$remote_dir"
  ssh "${ssh_options[@]}" "$target" "$remote_command" <<'REMOTE'
set -euo pipefail
cd "$1"
[[ -f submission/job-id ]] || { echo 'No recorded job ID. Inspect squeue/sacct if submission was interrupted.' >&2; exit 3; }
job_id=$(cat submission/job-id)
[[ "$job_id" =~ ^[0-9]+$ ]] || exit 3
squeue -j "$job_id"
sacct -j "$job_id" --format=JobID,State,ExitCode
REMOTE
else
  # Download selected paths as a tar stream over the authenticated connection.
  # Keep each job's local results separate and avoid downloading the SIF by default.
  printf -v remote_command 'cat %q' "$remote_dir/submission/job-id"
  job_id=$(ssh "${ssh_options[@]}" "$target" "$remote_command")
  [[ "$job_id" =~ ^[0-9]+$ ]] || { echo 'No valid recorded job ID.' >&2; exit 3; }
  if [[ $# == 0 ]]; then set -- logs outputs submission; fi
  for path in "$@"; do
    [[ -n "$path" && "$path" != /* && "/$path/" != *'/../'* ]] || {
      echo 'fetch paths must be relative to the remote run directory.' >&2; exit 2;
    }
  done
  destination="$repo_dir/results/$job_id"
  mkdir -p "$destination"
  printf -v remote_command '%q ' tar -C "$remote_dir" -cf - -- "$@"
  ssh "${ssh_options[@]}" "$target" "$remote_command" | tar -C "$destination" -xf -
  echo "Downloaded to $destination"
fi
