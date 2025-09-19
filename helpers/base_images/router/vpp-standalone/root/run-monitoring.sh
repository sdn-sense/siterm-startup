#!/usr/bin/env bash
sleep 5
vpp_prometheus_export port 1234 v2 ^/sys/heartbeat ^/sys/last_stats_clear ^/sys/boottime ^/sys/vector_rate ^/sys/vector_rate_per_worker ^/sys/loops_per_worker ^/sys/num_worker_threads ^/sys/last_update ^/sys/input_rate ^/mem/ ^/nodes/ ^/interfaces/ ^/buffer-pools/ ^/err/
