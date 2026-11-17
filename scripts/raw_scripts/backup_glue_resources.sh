if [ $# -lt 2 ]; then
  echo "Usage: $0 <profile> <region>" >&2
  exit 1
fi

PROFILE=$1
REGION=$2
mkdir -p glue-backup

aws glue get-jobs \
  --region "$REGION" \
  --profile "$PROFILE" \
  > glue-backup/jobs.json

aws glue get-crawlers \
  --region "$REGION" \
  --profile "$PROFILE" \
  > glue-backup/crawlers.json

# There is no get-workflows API: list the names, then batch-get them (max 25 per call).
aws glue list-workflows \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Workflows[]' \
  --output text | tr '\t' '\n' | sed '/^$/d' > glue-backup/workflow-names.txt

if [ -s glue-backup/workflow-names.txt ]; then
  xargs -n 25 < glue-backup/workflow-names.txt | while read -r NAMES; do
    # shellcheck disable=SC2086
    aws glue batch-get-workflows \
      --region "$REGION" \
      --profile "$PROFILE" \
      --include-graph \
      --names $NAMES
  done | jq -s '{Workflows: (map(.Workflows) | add), MissingWorkflows: (map(.MissingWorkflows) | add)}' \
    > glue-backup/workflows.json
else
  echo '{"Workflows": [], "MissingWorkflows": []}' > glue-backup/workflows.json
fi
rm -f glue-backup/workflow-names.txt

aws glue get-triggers \
  --region "$REGION" \
  --profile "$PROFILE" \
  > glue-backup/triggers.json

aws glue get-connections \
  --region "$REGION" \
  --profile "$PROFILE" \
  > glue-backup/connections.json

aws glue get-security-configurations \
  --region "$REGION" \
  --profile "$PROFILE" \
  > glue-backup/security-configurations.json

aws glue get-databases \
  --region "$REGION" \
  --profile "$PROFILE" \
  > glue-backup/databases.json