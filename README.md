# Deploy and Host Jellyfin on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/jellyfin-media?referralCode=sLjDXb&utm_medium=integration&utm_source=button&utm_campaign=jellyfin-media)

[Jellyfin](https://jellyfin.org/) is the free, open-source media server: your own movies, shows and music, streamed to a browser, phone or TV, with no account on anyone else's service. This template adds the two things a cloud host needs that stock Jellyfin leaves out: a way to get files onto the server, and an admin account that exists before the site goes public.

## About Hosting Jellyfin

One service and one volume. Inside are Jellyfin, [dufs](https://github.com/sigoden/dufs) at `/upload`, and Caddy in front of both.

- **Upload from the browser.** Jellyfin has no upload feature, and a Railway volume has no SFTP. Open `/upload`, drop files into `movies`, `shows` or `music`, and Jellyfin picks them up.
- **No open setup wizard.** A fresh Jellyfin hands its wizard, and the admin account, to whoever opens the URL first. Here the wizard is finished before the public port opens, with the login `admin` and a generated password.
- **Libraries ready.** Movies, Shows and Music are created and watch their folders for new files.
- **Real visitor addresses.** The proxy is configured so Jellyfin sees each visitor's address, instead of treating everyone as being on its local network.

## Common Use Cases

- A private film and music library you can reach from anywhere
- Home videos shared with family, each person with their own login and watch history
- A small library of media you've licensed or made yourself

## Dependencies for Jellyfin Hosting

- None. Single service with a volume, no database to run.

### Deployment Dependencies

- [Jellyfin documentation](https://jellyfin.org/docs/)
- [Jellyfin clients](https://jellyfin.org/downloads/clients/)
- [dufs documentation](https://github.com/sigoden/dufs)
- [Template source on GitHub](https://github.com/two-workspaces/jellyfin-media)

### Implementation Details

**Sign in** at your Railway domain with the username `admin` and the `JELLYFIN_ADMIN_PASSWORD` value from the service's Variables tab. The same login works at `/upload`. Jellyfin reads the variable on the first boot only, so change its password inside Jellyfin afterwards. `/upload` reads it on every boot, so change the variable to change that one.

**Adding media.** Use one folder per film (`movies/Big Buck Bunny (2008)/Big Buck Bunny (2008).mp4`) and `shows/Name/Season 01/Name S01E01.mkv` for episodes, as [Jellyfin's naming guide](https://jellyfin.org/docs/general/server/media/movies/) describes.

**Storage and traffic.** Media counts against the volume, and volume size depends on your Railway plan, so grow the volume before a big upload. Railway bills outbound traffic, so streaming a lot of video has a cost of its own.

**No GPU.** Railway has no GPUs, so transcoding runs on the CPU. Files your device can play directly (H.264 with AAC in MP4 is the safest) use almost no CPU. Converting 4K or HEVC on the fly is slow and expensive here: convert it before uploading, or lower the bitrate in the player.

**Your own media only.** Railway's Fair Use Policy doesn't allow pirated media or torrenting.

## Why Deploy Jellyfin on Railway?

Your library stays reachable from anywhere, with TLS on the public domain, no router or port forwarding to configure, and no home server to keep running.
