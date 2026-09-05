+++
title = "Setting up a Samba share for Haas Classic Controls"
date = "2026-08-31 17:56:37"
draft = true
+++

- Using a Haas Classic Control on a VF-1 from 2013
- This share allows machines with the NGC to talk to it too
- Here's the Samba config
- Here's the config on the Classic Control
  - Hit Enter on `908 REMOTE SHARE PATH` and if all went well you'll see a list of named shares
- Casing doesn't seem to matter

{{ images1(path="/images/netshare-settings-1-cropped.png") }}
{{ images1(path="/images/netshare-settings-2-cropped.png") }}

```
[global]
    workgroup = WORKGROUP
    server string = SMB Server managed by Ansible
    security = user
    map to guest = Bad User
    # local master = yes
    # domain master = yes
    # preferred master = yes
    # https://www.linuxquestions.org/questions/linux-newbie-8/os-level-in-samba-conf-901832/
    os level = 65

    # Really noisy logging
    # log level = 5

    # Required for Haas Classic Controls which only support SMBv1
    client min protocol = NT1
    server min protocol = NT1
    ntlm auth = yes

    # Enable netbios for Haas Classic Control
    netbios name = officemon
    disable netbios = no
    wins support = yes
    # dns proxy = yes
    name resolve order = wins lmhosts bcast

    # Performance tuning
    read raw = yes
    write raw = yes
    use sendfile = yes
    aio read size = 16384
    aio write size = 16384

    # Disable printer sharing (almost never needed on a file server)
    load printers = no
    printing = bsd
    printcap name = /dev/null
    disable spoolss = yes

[gcode]
    comment = GCode for CNC machines
    path = /srv/samba/gcode
    browseable = yes
    writable = yes
    guest ok = yes
    create mask = 0660
    directory mask = 0770
    valid users = @gcode
    force group = gcode
```
