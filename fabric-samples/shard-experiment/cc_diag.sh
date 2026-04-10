#!/usr/bin/env bash
set -euo pipefail

pattern='dev-peer0.*ev-cc-shard'
echo "== containers (ps -a) =="
docker ps -a --filter "name=${pattern}" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

echo
for c in $(docker ps -a --filter "name=${pattern}" --format "{{.Names}}"); do
  echo "=============================="
  echo "== INSPECT: $c =="
  docker inspect "$c" --format 'State={{.State.Status}} ExitCode={{.State.ExitCode}} Error={{.State.Error}} StartedAt={{.State.StartedAt}} FinishedAt={{.State.FinishedAt}}'
  echo "-- Cmd/Entrypoint --"
  docker inspect "$c" --format 'Entrypoint={{json .Config.Entrypoint}} Cmd={{json .Config.Cmd}}'
  echo "-- Last 80 logs --"
  docker logs "$c" --tail 80 || true
  echo
done

echo "== peer0.org1 (errors) =="
docker logs peer0.org1.example.com --tail 500 | egrep -i "chaincode|endorse|proposal|launch|connect|error|failed" | tail -n 120 || true
echo
echo "== peer0.org2 (errors) =="
docker logs peer0.org2.example.com --tail 500 | egrep -i "chaincode|endorse|proposal|launch|connect|error|failed" | tail -n 120 || true
