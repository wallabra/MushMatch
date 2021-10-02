#!/bin/sh
curl 'http://ut-files.com/index.php?dir=Entire_Server_Download/&file=ut-server-linux-436.tar.gz' -OL -C- --output-dir /var/tmp --create-dirs --retry 5
curl 'https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469b/OldUnreal-UTPatch469b-Linux.tar.bz2'  -OL -C- --output-dir /var/tmp --create-dirs --retry 5
tar -xzf /var/tmp/ut-server-linux-436.tar.gz -C /opt
tar -xjpf /var/tmp/OldUnreal-UTPatch469b-Linux.tar.bz2 -C /opt/ut-server
rm 'http://ut-files.com/index.php?dir=Entire_Server_Download/&file=ut-server-linux-436.tar.gz' 'https://github.com/OldUnreal/UnrealTournamentPatches/releases/download/v469b/OldUnreal-UTPatch469b-Linux.tar.bz2'
