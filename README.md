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
    <blockquote>This repository now provides the following CHOST (branches):<br/>
     <a href="https://github.com/night-every/gentoo-binhost/tree/x86_64-pc-linux-gnu(desktop)/" target="_self" >x86_64-pc-linux-gnu(desktop)</a><br/>
     <a href="https://github.com/night-every/gentoo-binhost/tree/x86_64-pc-linux-gnu(desktop/plasma)/" target="_self" >x86_64-pc-linux-gnu(desktop/plasma)</a></blockquote>
     <br/>
</div>

## Concept

- Package upload is done through a small upload script executed by portage hooks.
  
- For each package merged via portage, the Gentoo Packages manifest file is committed to Git.
  
- Binary packages are not stored in the repository but are uploaded as GitHub release artifacts.

- **UPDATES (06-06-2023)**: The script will check if the network is accessible before it start, if not, it will store the information of the binary packages that need to be uploaded in the same directory as offline_mode.json (which will be created automatically). Once it has access to the network it will automatically upload the packages that have not yet been uploaded.
  

To make everything work, the following nomenclature has to apply:

| Gentoo Idiom | GitHub entity |
| --- | --- |
| [CATEGORY/PN](https://devmanual.gentoo.org/ebuild-writing/variables/) | GitHub release |
| [PF](https://devmanual.gentoo.org/ebuild-writing/variables/) | GitHub release asset |
| [CHOST(PROFILE)](https://wiki.gentoo.org/wiki/CHOST) | Git branch name |
| [CHOST(PROFILE)/CATEGORY/PN](https://devmanual.gentoo.org/ebuild-writing/variables/) | Git release tag |

> CHOST(PROFILE): Your branch name will be automatically generated based on the host's chost and profile (if this branch does not exist in the repo).
> 
> For example:
> 
> CHOST = x86_64-pc-linux-gnu
> 
> PROFILE = default/linux/amd64/17.1/desktop (stable)
> 
> Git branch name = x86_64-pc-linux-gnu(desktop)

![Git branch name](https://cdn.jsdelivr.net/gh/night-every/blogs-images-bed@main/blogs/images/202304241006542.png?raw=true)

---

## Usage

Setup a gentoo binhost Github and provide the following.

---

## Dependencies

This upload script requires the dependencies listed below.

- **app-alternatives/sh**
  
- **app-misc/jq**
  
- **sys-apps/diffutils**
  
- **net-misc/curl**
  
- **dev-vcs/git**
  
- **virtual/perl-MIME-Base64**
  
- **sys-apps/coreutils**

---

## Setup

### /etc/portage/make.conf

Add the following lines to enable gentoo-binhost.

```shell
FEATURES="${FEATURES} buildpkg -collision-protect protect-owned"
# -collision-protect protect-owned : The default configuration on Gentoo systems is FEATURES="protect-owned"which works similarly to FEATURES="collision-protect" but it allows collisions between orphaned files.
ACCEPT_LICENSE="-* @BINARY-REDISTRIBUTABLE"
# The repo you want to use as gentoo-binhost. Example: night-every/gentoo-binhost 
PORTAGE_BINHOST_HEADER_URI="https://github.com/<repo>/releases/download/${CHOST}"
BINHOST="bindist"
USE="${BINHOST}"
## You can also write it like this
## USE="${USE} bindist"
```

> In script, PORTAGE_BINHOST_HEADER_URI will be modified. Set it up like this first

### /etc/portage/bashrc

Add the following lines in /etc/portage/bashrc

```shell
# Refer https://wiki.gentoo.org/wiki//etc/portage/bashrc#Hook_functions
function post_pkg_postinst() {
  # grep "buildpkg" absolutely
  grep -Fq ' buildpkg ' <<< {$PORTAGE_FEATURES}
  if [ $? -eq 0 ]; then
    # Change this according to your settings.
    # Add your repository taht you want to use as gentoo-binhost, your personal GitHub access token and your email.
    # To proceed, you must generate a GitHub access token with permissions to access the repository and create releases.
    /etc/portage/github_upload.sh -r '<repo>' -t '<token>' -e '<email>'
  fi
}
```

> The script will first check the [PKGDIR](https://wiki.gentoo.org/wiki/PKGDIR) for the binary package built for the ebuild being processed this time. If not it will exit immediately.
> When it encounters software specified in -B or --buildpkg-exclude, it will simply skip.

### /etc/portage/github_upload.sh

Put github_upload.sh under /etc/portage/

And **REMEMEBER !!!!**

```shell
sudo chmod +x /etc/portage/github_upload.sh
```


---

## DISCLAIMER

Although the source code of this software is released under the [MIT](http://opensource.org/licenses/MIT) license, it's important to note that the binary packages included in the distribution may have different licenses. Please refer to the Packages Manifest file for details on the specific licenses of each package. Additionally, please consult the [Gentoo license](https://devmanual.gentoo.org/general-concepts/licenses/index.html) and [License groups - Gentoo Wiki](https://wiki.gentoo.org/wiki/License_groups) for further information on the licensing terms and conditions that apply.
