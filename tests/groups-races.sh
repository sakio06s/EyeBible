#!/bin/sh
# Disposable test database only. Two simultaneous joins compete for one user.
set -eu
docker exec eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1 -c "update eyebible_groups set invite_expires_at=now()+interval '30 days'" >/dev/null
group_test_code_a=$(docker exec eyebible-cloud-test psql -U postgres -Atc "select invite_code from eyebible_groups where owner_id='00000000-0000-0000-0000-000000000001'")
group_test_code_b=$(docker exec eyebible-cloud-test psql -U postgres -Atc "select invite_code from eyebible_groups where owner_id='00000000-0000-0000-0000-000000000003'")
group_test_tmp=$(mktemp -d)
trap 'rm -rf "$group_test_tmp"' EXIT
join_test(){ docker exec eyebible-cloud-test psql -U postgres -v ON_ERROR_STOP=1 -c "set role authenticated; set request.jwt.claim.sub='00000000-0000-0000-0000-000000000002'; select group_action('join',jsonb_build_object('code','$1','profile',jsonb_build_object('name','racing Bob')));"; }
set +e
join_test "$group_test_code_a" >"$group_test_tmp/a" 2>&1 &
group_test_pid_a=$!
join_test "$group_test_code_b" >"$group_test_tmp/b" 2>&1 &
group_test_pid_b=$!
wait "$group_test_pid_a"
group_test_result_a=$?
wait "$group_test_pid_b"
group_test_result_b=$?
set -e
if ! { [ "$group_test_result_a" -eq 0 ] && [ "$group_test_result_b" -ne 0 ]; } && ! { [ "$group_test_result_a" -ne 0 ] && [ "$group_test_result_b" -eq 0 ]; }; then cat "$group_test_tmp/a" "$group_test_tmp/b"; exit 1; fi
group_test_count=$(docker exec eyebible-cloud-test psql -U postgres -Atc "select count(*) from eyebible_members where user_id='00000000-0000-0000-0000-000000000002'")
[ "$group_test_count" -eq 1 ]
echo 'PASS concurrent joins: exactly one group membership wins'
