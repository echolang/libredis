# start_server NAME IMAGE PORT: a Redis in Docker on 127.0.0.1:PORT, the default user's password
# `rootpw` and an ACL user `app` (password `secret`), waited for until it answers. Sourced by
# test-live.sh and bench/run.sh.
start_server() {
    local name=$1 image=$2 port=$3
    docker run -d --rm --name "$name" -p "127.0.0.1:$port:6379" "$image" \
        redis-server --requirepass rootpw --user app on '>secret' '~*' '&*' '+@all' --save '' --appendonly no >/dev/null
    echo "waiting for $image on 127.0.0.1:$port"
    for _ in $(seq 1 60); do
        if docker exec "$name" redis-cli -a rootpw --no-auth-warning ping 2>/dev/null | grep -q PONG; then
            break
        fi
        sleep 0.5
    done
    docker exec "$name" redis-cli -a rootpw --no-auth-warning info server | grep -E '^(redis|valkey)_version' || true
}
