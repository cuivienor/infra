# MergerFS Storage Rebalancing

**Status**: Future task
**Created**: 2025-11-11

## Goal

Rebalance existing data across MergerFS pool. Currently most data sits on disk1, while disk2/disk3 are nearly empty.

## Current State (as of 2025-11-11)

- disk1 (9.1T): ~4.1T used (48%) - nearly all existing data
- disk2 (9.1T): ~470M used (1%) - nearly empty
- disk3 (17T): ~24G used (1%) - nearly empty

MergerFS is configured with `eppfrd` policy so **new** files automatically distribute across disks. This task is about moving **existing** data.

## Approach

Use rsync to gradually move complete directories (movies, TV series) from disk1 to disk2/disk3:

```bash
rsync -avhP --remove-source-files /mnt/disk1/path/ /mnt/disk2/path/
rmdir /mnt/disk1/path/  # after verifying
```

Key points:
- Use rsync (not mv) - verifies files before deleting source
- Move complete directories to keep related files together
- Run `snapraid sync` after significant moves
- Jellyfin works through MergerFS, doesn't care which physical disk

## Target

Balance until disk1 is ~15-20% usage. After that, new files auto-distribute.
