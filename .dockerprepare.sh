#!/bin/sh

curl 'http://ut-files.com/index.php?dir=Entire_Server_Download/&file=ut-server-linux-436.tar.gz' -L -o'/var/tmp/ut-server-linux-436.tar.gz'
curl 'https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469b/OldUnreal-UTPatch469b-Linux.tar.bz2' -L -o'/var/tmp/OldUnreal-UTPatch469b-Linux.tar.bz2'
tar -xzf /var/tmp/ut-server-linux-436.tar.gz -C /opt
tar -xjpf /var/tmp/OldUnreal-UTPatch469b-Linux.tar.bz2 -C /opt/ut-server
rm /var/tmp/ut-server-linux-436.tar.gz /var/tmp/OldUnreal-UTPatch469b-Linux.tar.bz2
