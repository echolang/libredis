#!/usr/bin/env bash
#
# Run the cluster tests against a throwaway three-primary Redis cluster in Docker.
#
#   scripts/test-cluster.sh                      # redis:7
#   IMAGE=redis:6.2.6 scripts/test-cluster.sh
#
# All three nodes run in one container, on three free ports mapped one to one, announcing
# 127.0.0.1, so the addresses the cluster hands out work from here. Same users as test-live.sh.

set -euo pipefail

IMAGE=${IMAGE:-redis:7}
NAME=libredis-cluster-$$
# three ports in a row that are free, and their bus ports (+10000)
BASE=${BASE:-$(python3 -c '
import socket, random
while True:
    base = random.randint(20000, 50000)
    ok = True
    for p in (base, base + 1, base + 2, base + 10000, base + 10001, base + 10002):
        s = socket.socket()
        try:
            s.bind(("127.0.0.1", p))
        except OSError:
            ok = False
        s.close()
    if ok:
        print(base)
        break
')}
P0=$BASE; P1=$((BASE + 1)); P2=$((BASE + 2))

cd "$(dirname "$0")/.."
docker run -d --rm --name "$NAME" -p "127.0.0.1:$P0:$P0" -p "127.0.0.1:$P1:$P1" -p "127.0.0.1:$P2:$P2" \
    --entrypoint sh "$IMAGE" -c "
        for p in $P0 $P1 $P2; do
            redis-server --port \$p --cluster-enabled yes --cluster-config-file nodes-\$p.conf \
                --cluster-announce-ip 127.0.0.1 --requirepass rootpw --masterauth rootpw \
                --user app on '>secret' '~*' '&*' '+@all' --save '' --appendonly no --daemonize yes
        done
        sleep 1
        redis-cli -a rootpw --no-auth-warning --cluster create 127.0.0.1:$P0 127.0.0.1:$P1 127.0.0.1:$P2 --cluster-yes
        tail -f /dev/null" >/dev/null
trap 'docker rm -f -v "$NAME" >/dev/null 2>&1 || true' EXIT

echo "waiting for the cluster on 127.0.0.1:$P0-$P2"
# every node has to see the cluster as ok, not only the first
for _ in $(seq 1 60); do
    ready=0
    for p in $P0 $P1 $P2; do
        if docker exec "$NAME" redis-cli -p "$p" -a rootpw --no-auth-warning cluster info 2>/dev/null | grep -q 'cluster_state:ok'; then
            ready=$((ready + 1))
        fi
    done
    if [ "$ready" = 3 ]; then
        break
    fi
    sleep 0.5
done
docker exec "$NAME" redis-cli -p "$P0" -a rootpw --no-auth-warning cluster info | grep cluster_state

export REDIS_CLUSTER_SEEDS="127.0.0.1:$P0,127.0.0.1:$P1"
echoc test --define redis_cluster --timeout 120000 "$@"
