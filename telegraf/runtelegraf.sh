#!/bin/bash
docker run -d --name=telegraf \
      --net="host" \
      -v /home/denzilr/telegraf.conf:/etc/telegraf/telegraf.conf:ro \
      telegraf
