# Portainer restore attempts — 2025‑02‑11

Context: after migrating Nextcloud’s data directory from the standalone SSD (`/mnt/ncdata` → bind mount of `/srv/nextcloud-data` on NVMe) we tried to bring Portainer back online and ran into the “Failed loading environment: local unreachable” banner. Below is the breadcrumb trail so we can resume cleanly later.

## Actions completed
1. **Nextcloud datadir relocation**
   - Copied `/mnt/ncdata` to `/srv/nextcloud-data`, ensured `.ocdata` exists, ownership `33:33`, perms 750/640.
   - Unmounted the SSD (`/dev/sda1`), commented its `/etc/fstab` entry, and added `/srv/nextcloud-data /mnt/ncdata none bind 0 0`.
   - Restarted Nextcloud AIO, ran `occ files:scan --all`, maintenance mode off; instance back to normal on NVMe.

2. **Portainer troubleshooting**
   - Verified `/var/run/docker.sock` exists (`srw-rw---- root docker`) and is mounted into the Portainer container (`docker inspect …` + helper `busybox`).
   - Deleting/re-adding the “local” environment from the UI did not clear the “unreachable” state.
   - Tried to peek/edit `portainer.db` via `nouchka/sqlite3`, discovered the DB was corrupt (`file is not a database` errors).
   - Nuked Portainer (`docker stop portainer && docker rm portainer && docker volume rm portainer_portainer_data`) and re‑deployed via compose; the fresh UI wizard completes but the new “local” endpoint still flips to unreachable immediately.

## Current state (pause point)
- Nextcloud is healthy, running from `/srv/nextcloud-data`.
- Portainer is a fresh deploy, but the only environment (“local”/Docker Standalone) still reports **unreachable** despite the Docker socket bind being present and readable from helper containers.
- No working `portainer.db` backup is available; all previous metadata was lost during the purge.

## Next steps when resuming
1. Check the actual Portainer logs right after hitting “Reconnect” to capture the precise error (permission denied vs invalid URL). Command: `docker logs portainer --since 2m`.
2. Ensure the container uses the documented bind path `/opt/portainer/data:/data` (per `homelab.md:430‑437`) instead of an unnamed Docker volume, so file access is predictable.
3. If logs point to an endpoint misconfiguration, re-run `docker run --rm -v /opt/portainer/data:/data nouchka/sqlite3 /data/portainer.db "SELECT …"`; because the new DB should be valid, we can edit the endpoint record in place.
4. Once Portainer can reach the socket, re-import or recreate the stacks.

## Follow-up — 2025‑02‑12

New facts:
- `portainer` container is healthy (`docker ps`) and still fronted by Caddy (`homelabbing/configs/caddy/Caddyfile:85‑90`), so the reverse proxy is not in the failure path.
- The container runs with the documented socket bind but stores its DB inside the managed Docker volume `portainer_portainer_data`, making on-host inspection harder than `/opt/portainer/data` would.
- Fresh logs captured immediately after clicking “Reconnect” show `snapshot.go` complaining that the *Podman* environment type was selected for the `local` endpoint even though the target is Docker.
- Attempts to read `portainer.db` with sqlite fail because the file is BoltDB, not SQLite.

Action items to unblock:
1. Either delete the current data volume (`docker stop portainer && docker rm portainer && docker volume rm portainer_portainer_data`) or mount `/opt/portainer/data:/data` so we can inspect the BoltDB file directly (using a bbolt-aware tool) before re-running the wizard and picking **Docker → Socket**.
2. If keeping the existing DB, query the `endpoints` bucket with a bbolt helper container to confirm `Type` is set to Podman and flip it back to Docker (or delete the record entirely before restarting Portainer).
3. After Portainer restarts, immediately re-test with `docker logs portainer --tail 50`; the Podman error must disappear before recreating stacks.

## Follow-up — 2025‑02‑13

- Re-applied the compose spec from `homelabbing/configs/portainer/docker-compose.yml`, now binding `/opt/portainer/data:/data`, removed the old container/volume, and re-ran the first-run wizard (Docker → Socket). The UI still flips “local” to unreachable and logs the same Podman-only snapshot error.
- `strings /data/portainer.db | grep -i podman` confirmed the BoltDB keeps recreating the endpoint with `Type=Podman`, so the failure is not tied to the data location.
- Cross-referenced [portainer/portainer#12925](https://github.com/portainer/portainer/issues/12925): dozens of users on Docker **29.0.0** + Portainer **2.33.x** report the identical “Podman environment” error. Portainer staff (Nick-Portainer) stated Docker 29 is not yet supported and advised staying on the versions listed in their compatibility matrix. Community workarounds include downgrading to Portainer `2.20.2` or setting `Environment=DOCKER_MIN_API_VERSION=1.24` (or `DOCKER_API_VERSION=1.44`) in `docker.service`, then restarting Docker before redeploying Portainer.

Next concrete steps:
1. Decide between (a) pinning Docker to ≤28.x or (b) exporting `DOCKER_MIN_API_VERSION=1.24` in `docker.service` (follow the systemd `systemctl edit docker.service` instructions from issue #12925). Either change should make Docker speak an API level Portainer 2.33.x understands.
2. After the daemon tweak, restart Docker, redeploy Portainer with the `/opt/portainer/data:/data` bind, and re-run the wizard so a fresh DB is generated.
3. Verify `docker logs portainer --tail 50` no longer mentions Podman; only then proceed to recreate stacks/endpoints.

## Follow-up — 2025‑02‑14

- Created `/etc/systemd/system/docker.service.d/override.conf` with:
  ```
  [Service]
  Environment=DOCKER_MIN_API_VERSION=1.24
  ```
  then ran `systemctl daemon-reload && systemctl restart docker`. `systemctl show docker --property=Environment` now reports the override.
- Redeployed Portainer using `homelabbing/configs/portainer/docker-compose.yml` (`/opt/portainer/data:/data` bind intact), completed the first-run wizard (Docker → Socket), and the dashboard immediately showed the local endpoint as **up** with no Podman errors in `docker logs`.
- Portainer is fully functional again; the lingering issue was the Docker 29 vs. Portainer 2.33.x API mismatch documented in portainer/portainer#12925, resolved by forcing `DOCKER_MIN_API_VERSION=1.24`.

This file marks the stop point so we can pick up the investigation later without re-discovering the ground already covered.
