#!/bin/bash
# Very basic backup script
#
# Simplified BSD Licence
#----------------------------
# Copyright (c) 2012, Makina Corpus
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#    Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#    Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

# DATADIR=/opt/PostgreSQL/11/data
DATADIR=/var/lib/postgresql/11/main/
PGPORT=5432
PGPORT=5435
ARCHIVEDIR=/mnt/serveur/archive
BACKUPDIR=/mnt/serveur/backup

# demarrage du backup
echo "running select pg_start_backup('hot_backup')"
psql --username=postgres -d postgres -h localhost -p ${PGPORT} \
  -c "select pg_start_backup('hot_backup');"
# backup binaire
echo "running tar command"
tar -cf ${BACKUPDIR}/backup.tar ${DATADIR}
# fin du backup
echo "running select pg_stop_backup()"
psql --username=postgres -d postgres -h localhost  -p ${PGPORT} \
  -c "select pg_stop_backup();"
