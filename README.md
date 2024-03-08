# Telnet
![image](https://github.com/Smok1e/oc-openos-telnet/assets/33802666/65e47c8a-cfe2-4c04-8198-6ed7c831dcab)

This is telnet client for OpenOS, an operating system for [OpenComputers](https://github.com/MightyPirates/OpenComputers/) Minecraft mod.

This program provides very basic support for [telnet](https://en.wikipedia.org/wiki/Telnet) - old client/server application protocol
that provides access to virtual terminals of remote systems over the internet.

Telnet can be used to access a remote shell, just like ssh. To do that, you'll have to run a telnet server on your host that provides
interface for accessing shell. 

However, telnet can be used for various terminal interfaces; for instance, the dedicated server in 7 Days To Die game utilizes 
telnet for accessing the server command console.

# Command usage:
In OpenOS, type `telnet <address> [<port>]`; Default telnet port is 23.

![image](https://github.com/Smok1e/oc-openos-telnet/assets/33802666/69c223f4-17ab-44b2-b25e-de6ddc8d3451)

# Installation
Simply run this command: `wget -f https://raw.githubusercontent.com/Smok1e/oc-openos-telnet/master/installer.lua /tmp/installer.lua && /tmp/installer.lua`
and wait for installation to complete. After that, you will be able to use telnet command in OpenOS.
