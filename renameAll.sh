#! /bin/bash
docker exec -it server1 ./instancerename.sh iris1
docker exec -it server2 ./instancerename.sh iris2
docker exec -it server3 ./instancerename.sh iris3
