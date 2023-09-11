
These are trace files from VM sqlrun.

A 6ms network latency was introduced

```text
[root@sqlrun ~]# tc qdisc add dev enp0s3 root netem delay 6ms 1ms 25%


[root@sqlrun ~]# tc qdisc
qdisc netem 8002: dev enp0s3 root refcnt 2 limit 1000 delay 6.0ms  1.0ms 25%
qdisc pfifo_fast 0: dev virbr0-nic root refcnt 2 bands 3 priomap  1 2 2 2 1 2 0 0 1 1 1 1 1 1 1 1


[root@sqlrun ~]# ping -c 5 192.168.1.1
PING 192.168.1.1 (192.168.1.1) 56(84) bytes of data.
64 bytes from 192.168.1.1: icmp_seq=1 ttl=64 time=32.3 ms
64 bytes from 192.168.1.1: icmp_seq=2 ttl=64 time=9.36 ms
64 bytes from 192.168.1.1: icmp_seq=3 ttl=64 time=5.40 ms
64 bytes from 192.168.1.1: icmp_seq=4 ttl=64 time=19.1 ms
64 bytes from 192.168.1.1: icmp_seq=5 ttl=64 time=11.8 ms

--- 192.168.1.1 ping statistics ---
5 packets transmitted, 5 received, 0% packet loss, time 4005ms
rtt min/avg/max/mdev = 5.406/15.624/32.344/9.489 ms
```


