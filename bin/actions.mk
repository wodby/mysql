SHELL := /bin/bash

check_defined = \
	$(strip $(foreach 1,$1, \
		$(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
	$(if $(value $1),, \
		$(error Required parameter is missing: $1$(if $2, ($2))))

user ?= $(MYSQL_USER)
password ?= $(MYSQL_PASSWORD)
db ?= $(MYSQL_DATABASE)
root_password ?= $(MYSQL_ROOT_PASSWORD)
host ?= localhost
max_try ?= 1
wait_seconds ?= 1
delay_seconds ?= 0
ignore ?=
charset ?= utf8mb4
collation ?= utf8mb4_0900_ai_ci

default: query

import:
	$(call check_defined,source db user root_password host)
	import "$(user)" "$(root_password)" "$(host)" "$(db)" "$(source)"
.PHONY: import

backup:
	$(call check_defined,filepath db root_password host)
	backup "$(root_password)" "$(host)" "$(db)" "$(filepath)" "$(ignore)"
.PHONY: backup

backup-stream:
	$(call check_defined,stream_path status_path db root_password host)
	backup_stream "$(root_password)" "$(host)" "$(db)" "$(stream_path)" "$(status_path)" "$(ignore)"
.PHONY: backup-stream

query:
	$(call check_defined,query db user password host)
	MYSQL_PWD="$(password)" mysql --protocol=TCP --host="$(host)" --user="$(user)" --execute="$(query)" "$(db)"
.PHONY: query

query-silent:
	$(call check_defined,query db user password host)
	@MYSQL_PWD="$(password)" mysql --protocol=TCP --host="$(host)" --user="$(user)" --batch --skip-column-names --execute="$(query)" "$(db)"
.PHONY: query-silent

query-root:
	$(call check_defined,query root_password host)
	MYSQL_PWD="$(root_password)" mysql --protocol=TCP --host="$(host)" --user=root --execute="$(query)" $(if $(db),"$(db)")
.PHONY: query-root

create-db:
	$(call check_defined,name charset collation root_password host)
	mysql-manage create-db "$(name)" "$(charset)" "$(collation)" "$(root_password)" "$(host)"
.PHONY: create-db

drop-db:
	$(call check_defined,name root_password host)
	mysql-manage drop-db "$(name)" "$(root_password)" "$(host)"
.PHONY: drop-db

create-user:
	$(call check_defined,username password root_password host)
	mysql-manage create-user "$(username)" "$(password)" "$(root_password)" "$(host)"
.PHONY: create-user

drop-user:
	$(call check_defined,username root_password host)
	mysql-manage drop-user "$(username)" "$(root_password)" "$(host)"
.PHONY: drop-user

grant-user-db:
	$(call check_defined,username db root_password host)
	mysql-manage grant-user-db "$(username)" "$(db)" "$(root_password)" "$(host)"
.PHONY: grant-user-db

revoke-user-db:
	$(call check_defined,username db root_password host)
	mysql-manage revoke-user-db "$(username)" "$(db)" "$(root_password)" "$(host)"
.PHONY: revoke-user-db

mysql-check:
	$(call check_defined,db root_password host)
	mysql-check "$(root_password)" "$(host)" "$(db)"
.PHONY: mysql-check

check-ready:
	$(call check_defined,root_password host max_try wait_seconds delay_seconds)
	wait_for_mysql "$(root_password)" "$(host)" "$(max_try)" "$(wait_seconds)" "$(delay_seconds)"
.PHONY: check-ready

check-live:
	$(call check_defined,root_password host)
	MYSQL_PWD="$(root_password)" mysqladmin --protocol=TCP --host="$(host)" --user=root ping --silent
.PHONY: check-live
