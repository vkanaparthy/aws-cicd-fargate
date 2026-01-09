#!/bin/bash
# Script to update ECS task definition with new image

set -e

IMAGE_URI=$1
TASK_DEF_FILE=$2
OUTPUT_FILE=$3

if [ -z "$IMAGE_URI" ] || [ -z "$TASK_DEF_FILE" ]; then
  echo "Usage: $0 <image-uri> <task-definition-file> [output-file]"
  exit 1
fi

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$TASK_DEF_FILE"
fi

# Update image in task definition
jq --arg IMAGE "$IMAGE_URI" \
  '.containerDefinitions[0].image = $IMAGE' \
  "$TASK_DEF_FILE" > "$OUTPUT_FILE.tmp" && mv "$OUTPUT_FILE.tmp" "$OUTPUT_FILE"

echo "Updated task definition with image: $IMAGE_URI"
