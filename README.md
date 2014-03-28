SuperSecureDebain
=================

A huge bash script for installing and securing debian based multi purpose webserver

The scripts lets you **interactively** perform the **installation** of a **full web-server stack** including the most common **security packages**, **monitoring tools**, etc. for **debian** (wheezy).

It is intended to be use as the basement for a "real full stack" node.js line of business application framework i am currently working on.

The script is still in pre alpha phase.

There are certainly a lot of improvements to do, so please try it, use it and maybe contribute to it.

Security is a big issue and no one can cope with it on his/ her own.

So please, don't leave me alone in my cold, dark chamber and provide some feedback.

Thanks guys.

Usage
=====

Install a minimal debian (wheezy) system on a virtual or dedicated host (only ssh and system tools).
connect with winscp or putty, login as root.
put the `configureserver.sh` script in your root folder and

    chmod 777 configureserver.sh
    ./configureserver.sh

_tip: enable `export LS_OPTIONS='--color=auto'` in your `.bashrc` file to get colored output_

_tip: the root folder contains some nice .rc files_

Features
========

- avoid bash language issues by switching locals to en-us for better support on search matching and english command options
- provides a huge black-list of suspicious servers/ domains
- chooses the fastest mirror
- reminds you on setting the "A" & "MX" record, ssl ports, etc.
- takes you step by step through a whole production setup:
	* Ajenti
	* FreeSWICH
	* NFSD
	* PHP Tools
	* SELinux
	* Tripwire
	* Zpanel
	* adminer
	* apache
	* apparmor
	* apt-cacher
	* apt-listchanges
	* bash-completition
	* bind9
	* cache (not yet)
	* clamav
	* courier
	* ddclient
	* denyhosts
	* exim
	* force strong passwords
	* fwbuilder
	* icinga-web
	* iptables
	* java
	* l7-protocols
	* libapache-mod-evasive
	* libapache-mod-security
	* libvirt + kvm
	* logrotate
	* logwatch
	* lxc
	* mailman
	* memcached
	* misc. packers
	* moint
	* mono
	* munin
	* mysql/ mariadb - secures mysql automatically, removes annonimous users, disables remote login, etc.
	* nginx
	* nmap
	* npm
	* opcode
	* openssh - ease adding users to groups
	* openvpn
	* perl
	* php
	* php5-mysqld
	* phpmyadmin
	* postfix
	* proftpd
	* psad
	* puppet
	* pure-ftpd
	* python
	* rkhunter
	* ruby rake rack gems bundler
	* samba
	* shorewall
	* smartmontools
	* spamassassin
	* subversion
	* sudo
	* systemd
	* unattended-upgrades
	* update-manager
	* user quota (may have issues)
	* vim
	* virtualbox
	* webfonts
	* webmin


ToDo
====

- testing
- better separation of daemons -> own users
- review and setting of minimal privileges/ access rights
- more detailed configuration
    * esp. domain & mail related stuff
- rephrase some hints
- add more comments to source
- improve vlan and ip v6 support
- (better) error logging, esp. easily overridden errors on sed, grep etc.
- more color

