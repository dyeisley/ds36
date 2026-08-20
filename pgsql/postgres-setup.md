# PostgreSQL Setup Guide

Author: Luis Alvarez Sanchez
Date: 10/20/21
Converted from postgres-setup.txt

Guide for downloading/setting up PostgreSQL on CentOS/RHEL.

## 1. Installation

```bash
# Install RPM repo
sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

# Disable built-in postgresql module
sudo dnf -qy module disable postgresql

# Install postgresql (replace X with version, e.g. postgresql13-server)
sudo dnf install -y postgresqlX-server
```

## 2. Setup

```bash
/usr/bin/postgresql-setup initdb
systemctl start postgresql
systemctl enable postgresql
```

### Confirming installation

```bash
systemctl status postgresql
```

You should see `Active: active (running)`.

```bash
netstat -antup | grep 5432
```

## 3. Set psql password

```bash
sudo su - postgres
psql
\password
\q
```

Set the password to `ds3` — the build scripts and driver assume this.

## 4. Configure for remote access

Edit `/var/lib/pgsql/data/postgresql.conf`:

```
listen_addresses = '*'
max_connections = 1000
```

Edit `/var/lib/pgsql/data/pg_hba.conf`, add to the top of the TYPE/DATABASE/USER/ADDRESS/METHOD section:

```
host    all    all    0.0.0.0/0    md5
host    all    all    ::/0         md5
```

Change the existing `127.0.0.1` line's method to `md5`:

```
host    all    all    127.0.0.1/0    md5
```

## 5. Restart and verify

```bash
systemctl restart postgresql
```

From a different machine:

```bash
psql -h SERVER-IP -p 5432 -U postgres -W
```

If you get "No route to host", see step 6.

## 6. Firewall (optional)

If you get "No route to host" when connecting remotely:

```bash
systemctl stop firewalld
```

This stops the firewall entirely — unsafe in non-test environments.
