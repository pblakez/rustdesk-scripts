# RustDesk "No displays" / Wayland workarounds (headless / unattended)

On a Wayland session — or a box with no logged-in console user — the RustDesk client errors with **`Error: No displays`**. The service-mode capture path needs an Xorg session it can attach to; on Wayland the portal can't grant it without a user clicking through a prompt, and with no user logged in there's nothing to grab at all.

## Path A — quick: switch the console to Xorg

Use this if a person *will* log in at the console after the change. Disables Wayland in GDM so the next login lands on Xorg, where RustDesk's capture works.

```bash
sudo sed -i 's/^#\?WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
grep WaylandEnable /etc/gdm3/custom.conf      # confirm
sudo systemctl restart gdm3                   # SSH-safe; only kills console sessions
```

Then have a user log in at the console and reconnect with RustDesk.

## Path B — full headless (no console user, no monitor)

Official `allow-linux-headless` flow. Heavier — replaces GDM with LightDM and adds the dummy X driver so RustDesk has something to render into when nobody is logged in.

> **Test on a local Pop!_OS / Ubuntu box first.** Swapping the display manager on a remote-only host without verifying the LightDM greeter comes up cleanly can lock you out at the console. RustDesk officially "tested on Ubuntu, GNOME desktop" only — Pop!_OS works in practice but isn't on the supported matrix.

```bash
# 1. Install dummy X driver + lightdm
sudo apt update
sudo apt install -y xserver-xorg-video-dummy lightdm

# 2. Make LightDM the default display manager (interactive prompt)
sudo dpkg-reconfigure lightdm
#    pick "lightdm" when asked

# 3. Tell RustDesk it's allowed to serve when no displays are attached
sudo systemctl restart rustdesk
sudo rustdesk --option allow-linux-headless Y
sudo rustdesk --option allow-linux-headless          # read back; should print "Y"
sudo systemctl restart rustdesk
```

Reboot (or restart `lightdm`) so the new DM takes over, then connect with RustDesk — the "No displays" error should be gone even with no user logged in.

To roll back: `sudo dpkg-reconfigure lightdm` and pick `gdm3` again, or `sudo apt purge lightdm xserver-xorg-video-dummy && sudo dpkg-reconfigure gdm3`.

## Path C — also useful regardless

In RustDesk → Settings → Display, enable **Allow remote connection if there are no displays**. This is the GUI toggle for the same `allow-linux-headless` option above.
