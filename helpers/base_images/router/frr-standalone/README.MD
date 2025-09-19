For a standalone FRR, please use an official FRR image. More examples are available in Fabric demo: https://github.com/sdn-sense/vpp-frr/tree/main/frr
```
services:
  frr:
    image: frrouting/frr
    container_name: frr
    network_mode: "host"
    privileged: true
    cap_add:
      - ALL
    volumes:
      - ./etc/frr/daemons:/etc/frr/daemons
      - ./etc/frr/frr.conf:/etc/frr/frr.conf
      - ./etc/frr/vtysh.conf:/etc/frr/vtysh.conf
```