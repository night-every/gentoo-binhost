```bash
░██████╗░███████╗███╗░░██╗████████╗░█████╗░░█████╗░░░░░░░██████╗░██╗███╗░░██╗██╗░░██╗░█████╗░░██████╗████████╗
██╔════╝░██╔════╝████╗░██║╚══██╔══╝██╔══██╗██╔══██╗░░░░░░██╔══██╗██║████╗░██║██║░░██║██╔══██╗██╔════╝╚══██╔══╝
██║░░██╗░█████╗░░██╔██╗██║░░░██║░░░██║░░██║██║░░██║█████╗██████╦╝██║██╔██╗██║███████║██║░░██║╚█████╗░░░░██║░░░
██║░░╚██╗██╔══╝░░██║╚████║░░░██║░░░██║░░██║██║░░██║╚════╝██╔══██╗██║██║╚████║██╔══██║██║░░██║░╚═══██╗░░░██║░░░
╚██████╔╝███████╗██║░╚███║░░░██║░░░╚█████╔╝╚█████╔╝░░░░░░██████╦╝██║██║░╚███║██║░░██║╚█████╔╝██████╔╝░░░██║░░░
░╚═════╝░╚══════╝╚═╝░░╚══╝░░░╚═╝░░░░╚════╝░░╚════╝░░░░░░░╚═════╝░╚═╝╚═╝░░╚══╝╚═╝░░╚═╝░╚════╝░╚═════╝░░░░╚═╝░░░
```

<div align="center" style="display: flex; justify-content: center; align-items: center; height: 100vh;">
    <h1 style="font-size:14px; " align="center">GENTOO-BIHOST</h1>
    <p align="center">Providing <a href="https://gentoo.org/" target="_blank" >Gentoo</a> binary packages using <a href="https://github.com/" target="_blank" >Github</a> infrastructure.</p>
</div>

<div align="center" style="display: flex; justify-content: center; align-items: center; height: 100vh;">
    <br/>
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License: MIT"></a>
    <br/>
    <br/>
    <blockquote> Fork from <a href="https://github.com/coldnew/gentoo-binhost/" target="_blank" >GitHub - coldnew/gentoo-binhost: Provide Gentoo binhosts using github infrastructure</a></blockquote>
    <br/>
</div>

---

# x86_64-pc-linux-gnu

Packages for amd64 architecture

> Please install app-arch/lz4 first. All packages using lz4 compression

<div>
 <p><br/><p>
</div>

## Some configurations of the host

### CFLAGS,CXXFLAGS,CPU_FLAGS_X86 and others

```shell
COMMON_FLAGS="-mtune=generic -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
FCFLAGS="${COMMON_FLAGS}"
FFLAGS="${COMMON_FLAGS}"
CPU_FLAGS_X86="mmx sse sse2 sse3 ssse3 sse4_1 sse4_2 popcnt rdrand aes mmxext pclmul sha"
```

### Use Flags

```shell
# USE
DE="-gnome -gnome-shell -gnome-keyring"
SYSTEM="elogind -oss -plymouth -systemd -consolekit -mdev"
SOFTWARE="sudo icu client git openmp minizip udev blkid efi hwdb smack acpi dbus policykit udisks"
AUDIO="alsa pulseaudio pipewire"
NET="network networkmanager connection-sharing wifi http2 nftables wireless iwd zeroconf cups ppp"
VIDEO="X vulkan layers glamor gallium vaapi wayland gles gles2"
ELSE="cjk emoji"
BINHOST="bindist"

USE="${DE} ${SYSTEM} ${SOFTWARE} ${AUDIO} ${NET} ${VIDEO} ${ELSE} ${BINHOST}"
```

### Others

```shell

INPUT_DEVICES="libinput synaptics"

ACCEPT_KEYWORDS="~amd64"
EMERGE_DEFAULT_OPTS="--keep-going --with-bdeps=y --verbose --deep --ask \
	--buildpkg-exclude '*/*-bin' \
	--buildpkg-exclude 'sys-kernel/*-sources' \
	--buildpkg-exclude 'dev-lang/rust' "
AUTO_CLEAN="yes"

# enable binhost
FEATURES="${FEATURES} buildpkg -collision-protect protect-owned"
ACCEPT_LICENSE="-* @BINARY-REDISTRIBUTABLE"
PORTAGE_BINHOST_HEADER_URI="https://github.com/night-every/gentoo-binhost/releases/download/${CHOST}"

BINPKG_COMPRESS="lz4"
BINPKG_FORMAT="gpkg"
VIDEO_CARDS="intel i965 iris"
LLVM_TARGETS="X86"
GRUB_PLATFORMS="efi-64"
```

---

## Usage

To enable binhost, add the following lines to your /etc/portage/make.conf file.

```shell
# enable binhost
# <your profile> means
# if your profile is default/linux/amd64/17.1/desktop/plasma
# then you should write desktop/plasma
# Example : PORTAGE_BINHOST="https://raw.githubusercontent.com/night-every/gentoo-binhost/${CHOST}(desktop/plasma)"
PORTAGE_BINHOST="https://raw.githubusercontent.com/night-every/gentoo-binhost/${CHOST}(<your profile>)"
FEATURES="${FEATURES} getbinpkg"
```

**PORTAGE_BINHOST** variable set in /etc/portage/make.conf **or** set the sync-uri variable in /etc/portage/binrepos.conf.

```shell
[binhost]
sync-uri = https://raw.githubusercontent.com/night-every/gentoo-binhost/${CHOST}(<your profile>)
priority = 9999
# <your profile> means
# if your profile is default/linux/amd64/17.1/desktop/plasma
# then you should write desktop/plasma
# Example : PORTAGE_BINHOST="https://raw.githubusercontent.com/night-every/gentoo-binhost/${CHOST}(desktop/plasma)"
```

> Refer [Pulling_packages_from_a_binary_package_host](https://wiki.gentoo.org/wiki/Binary_package_guide#Pulling_packages_from_a_binary_package_host)

<div>
    <p><br/></p>
</div>

Please refer to [Using_binary_packages](https://wiki.gentoo.org/wiki/Binary_package_guide#Using_binary_packages) before using.

