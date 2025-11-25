# Media Scripts

Scripts for media processing. Deployed to containers via Ansible.

## Scripts

All scripts use standard CLI: `-t <type> -n <name> [-s <season>]`

| Script | Container | Purpose |
|--------|-----------|---------|
| `rip-disc.sh` | ripper | Rip Blu-ray/DVD with MakeMKV |
| `remux.sh` | analyzer | Filter tracks (eng/bul), preserve extras |
| `transcode.sh` | transcoder | HEVC encoding with Intel QSV |
| `filebot.sh` | analyzer | Rename and organize to library |

## Usage

```bash
# Rip a movie
ssh ripper
nohup ./rip-disc.sh -t movie -n "The Matrix" &

# Remux TV season
ssh analyzer
./remux.sh -t show -n "Breaking Bad" -s 1

# Transcode (long-running)
ssh transcoder
nohup ./transcode.sh -t movie -n "The Matrix" &

# Organize to library
ssh analyzer
./filebot.sh -t movie -n "The Matrix" --preview
./filebot.sh -t movie -n "The Matrix"
```

## Monitoring

```bash
ls ~/active-jobs/              # Active jobs
cat ~/active-jobs/*/status     # Check status
tail -f ~/active-jobs/*/*.log  # Follow logs
```

## See Also

- [Ripping Guide](../../docs/guides/ripping-guide.md)
