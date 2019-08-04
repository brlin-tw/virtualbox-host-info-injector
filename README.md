# VirtualBox Host Info Injector
This utility injects the info of the host machine(mostly DMI), into a VirtualBox VM so that they look like the host system as much as possible(though technically the Operating System can always figure out if the running "hardware" is emulated or not due to their distinctive characteristics).

The main usage is on a Microsoft Windows VM, which may enforce activation requirement if the hardware change too much(if you migrate the entire system into a virtual machine even when the host system is the same).

## License
WTFPL