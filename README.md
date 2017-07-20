# eLectures Capture Agents

This repository documents the various versions of capture agents that the University of Münster uses to capture and livestream lectures for the [eLectures project](https://https://www.uni-muenster.de/studium/orga/electures.html.

## TOC

* [Scope](#scope)
* [System Requirements](#system-requirements)
* [Hardware](#hardware)
  * [Version 1](#version-1)
  * [Version 1a](#version-1a)
  * [Version 1b](#version-1b)
* [Software](#software)
* [Notes](#notes)


## Scope

This documentation covers the hardware selection & reasoning, as well as a overview of the software architecture used to glue everything together. Our capture agents are highly customized to the specific needs of the University of Münster, so the documentation is kept terse in places that are specific to our usecase. If you do need more details you are very welcome to [contact us](https://www.uni-muenster.de/studium/orga/electures.html).

## System Requirements

At the beginning of the project the following system requirements have been defined:

* High durability
* No user interaction required
* Very low maintenance, preferably complete remote management
* Installable in 19" Racks with minimal space Requirements
* At least one HDMI input, preferably with automatic input scaling
* At least one additional Camera input
* Ability to record dual streams
* One (stereo) analog audio input
* As silent as possible

Trying to fulfill all these requirements quickly led us to the conclusion that a complete custom build of the hardware was the best choice, even though there are alot of commercial offerings available - these either did not fit our needs or were too expensive.

## Hardware

### Version 1

#### Base Hardware

This hardware is pretty regular. Except for the IPMI feature on the mainboard, you can probably swap out everything else, provided that the CPU is fast enough.

* SuperMicro X10SLL-F
  * A basic Socket 1150 Micro-ATX Mainboard with an IPMI BMC. This was crucial, as it allows to monitor hardware sensors (temperatures, fan speed, voltages) remotely, provides a virtual KVM over Ethernet and allows us to mount a ISO image over the network and boot from it. Using these features we can do all common tasks including complete reinstallations from our office, which is a huge timesaver.
* Intel Xeon E3-1275Lv3
  * Fast, but low TDP CPU. This CPU can still be quietly cooled in a 2U rack, but is powerful enough to be future proof
* 16 GByte DDR3 RAM Kit
* 480 GByte Intel 535 SSD
* Seasonic 80+ Bronze 300 Watts PSU
* Chenbro RM24200
  * This case just barely fits our space requirements, but on the other hand is very spacious to allow for ample airflow with low fan speeds. Also it has three half-height PCI slots, which was crucial for our very first revision

#### Capture Hardware

* Blackmagic Design DeckLink Mini Recorder
  * We had some previous experience with a Blackmagic Design capture card and were optimistic that this inexpensive card would fit our needs. It does not have any integrated input scaling, but that was handled by the existing AV hardware in the lecture rooms.
* Creative SoundBlaster Audigy FX
  * The cheapest half-height PCIe soundcard that we could find, because the SuperMicro mainboards do not have an onboard soundcard - they're intended for server use after all.
* Axis P1428-E 4K fixed network security camera
  * These cameras were a perfect choice for us because they are very cheap compared to a complete SDI based solution, allowed us to use digital tracking instead of doing manual PTZ for camera operation and took a lot of load off the Capture Agent by providing an already encoded 4K h.264 video stream.

This configuration worked pretty well, but we soon noticed that the software support from Blackmagic Design was lacking. We were forced to compile drivers by hand and use a customized ffmpeg version to do the capturing. The cards were very picky about the input signal - if it did not exactly match the specified input resolution & rate, the recording would fail. Also, no simultaneous capture from multiple processes was possible, which was required later on for livestreaming capabilities.

The remote management capability paid off, the capture agents are running very silent, cool and rock stable.

### Version 1a

After the first semester has passed, we saw a post on the Opencast Users mailing list, mentioning the Magewell capture cards. After a quick inspection these cards seemed to provide a remedy for all our problems:

* External solutions for input scaling was very expensive
* We were limited to one capturing process at a time for the HDMI input
* Lacking driver support and high maintenance because Blackmagic made automated rebuilding of our needed software very hard
* Only one card can be used reliably at a time

So, for the next round of capture agents we replaced the Blackmagic Design DeckLink Mini Recorder and the Soundblaster soundcard with a Magewell Pro Capture HDMI capture card.

### Version 1b

We replaced the Blackmagic Design and Soundblaster cards with a Magewell Pro Capture HDMI capture card. This capture card has an integrated hardware input scaler and an analog audio input. The driver provides a standard V4L2 interface that allows multiple processes capture from the device. Although it costs a tiny bit more overall, it's well worth the money.

## Version 2

In a lot of rooms the space requirements were even more strict, so we had to quickly come up with an even smaller solution. For this we settled on:

* SuperMicro X11SSL-F (mini-itx, socket 1151)
* Intel Xeon E3-1240Lv5 (25 watt tdp)
* Supermicro SNK-P0046P CPU cooler (passive)
* SuperMicro Superchassis 504-203B (1HE, 25cm depth, 200w PSU)
  * The included fans are quite loud. Of the three fans we are only using one fan to keep the noise down as much as possible. Temperatures are high, but sustainable.
* 240 Gbyte Intel 540s SSD
* 16 Gbyte DDR4 RAM Kit
* Magewell Pro Capture HDMI
* Axis P1428-E

This is a really powerful hardware combination in a very small form factor. This also means that it runs quite a bit hotter (up to 75°c on CPU load, 35°c idle) than version 1, and makes more noise. This is on the verge of being tolerable.

In the next few weeks we will investigate replacing the 40mm fan with multiple noctua 40mm fans to (hopefully) reduce noise while keeping the temperatures at the same level.

We noticed that we do not really that much local disk space, so we reduced the SSD size. RAM is cheap, so we kept the 16 GByte for future use.

Because this version can only take one capture card we're a bit more limited in how many inputs this capture agent can process. Luckily it's a full-height slot, so if you would really need to you can install a quad-capture card from Magewell and some external USB soundcard for audio capture, or inject audio into the hdmi signals.

## Software

First we tried to use Galicaster Pro version 1.4. We quickly found that the requirement to use an outdated Ubuntu version, as well as lots of software bugs made this software unsuitable for our use.

We then turned to the minimal [pyCA](https://github.com/opencast/pyCA) software. After some experimenting our software stack looks like this:

* Custom Arch Linux installation ISO with an automatically starting shell-script that does the installation per our needs and prepares the system to be configured via Ansible
  * This is inserted as virtual media via IPMI/iKVM and booted.

* Ansible Playbook that configures...
  * Zabbix Agent for monitoring & custom checks, registering the device in Zabbix
  * Magewell drivers
  * pyCA for capturing
    * custom shell script to handle the capturing of the inputs with ffmpeg. This script also checks that the magewell inputs are configured correctly.
  * shell script that keeps disk usage in check: try to have 100 Gbyte of free disk space, but always keep at least the last 3 recordings for desaster recovery. This script is triggered every 2 hours (usually in between recordings) via systemd.
  * shell script that starts ffmpeg with a picture-in-picutre video mix for livestreaming to our Wowza server. The lifecycle of this script is managed via systemd.
  * shell script that checks against our central livestream service if the livestream should be active or not.
  * Configure camera security and add to snmp checks to Zabbix

The Playbook will do a basic "inventory" of detected hardware & serial numbers and write it out to YAML files for us. 

We intentionally chose [Arch Linux](https://archlinux.org) for the following reasons:

* Very lightweight, uncomplicated system - not a lot that can go wrong.
* Very up to date, security fixes are quickly distributed.
* Rolling release - but we only update between semesters. This frees us from (unreliable) dist-upgrade cycles.
* The person developing the CAs is very proficient with this distribution. :)

## Networking

Because we use a network camera some thought has to be done for the networking part. It is absolutely crucial to provide a stable, fast, uninterrupted connection with very low jitter between the capture agent and camera. For this reason we instructed the personal installing the hardware to connect camera and capture agent on the same network switch, though this was not possible in all cases. 

Furthermore we isolated all capture agents and cameras in a VLAN that can only be accessed from a few other machines. This increases security (After all, the Network Cameras are vulnerable to typical IoT security exploits as [recently seen](http://blog.senr.io/devilsivy.html)) by adding another layer, and reduces unwanted network traffic (broadcasts).

## Notes

Some hurdles we had to overcome along the way, which might be helpful to anyone out there:

### Selecting the Input on a Blackmagic card

The Blackmagic DeckLink Mini Recorders default to the SDI Input, which we did not use. This was problematic, because the only official way to change is is via a GUI application. Our capture agents were running headless, so we would have to install a X server to make this switch. We did not want to do that, because it also meant that this is not automatable. The Blackmagic support did not want to help us with this issue. After some digging around and some testing we found out that the driver actualy places a XML file in the `/etc` directory that contains the input selection. Changing the value to HDMI selected the HDMI input.

Magewell provides really good, informative and easy-to-use cli tools for that.

### Fan noise with SuperMicro mainboards

When using slowly-spinning fans (< 2000 rpm) the onboard fan controller does not work correctly out of the box. It is programmed for fast-spinning (~10k rpm) server fans. We needed to decrease the lower thresholds for the fan via `ipmitool` to keep the fans from oscillating between 0 an 1500 rpm.

