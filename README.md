# Samp-Server
_This is a repository of my gamemode of the server for SAMP that I am developing. Simply put all these files inside the blank base folder of the samp server 📖. <br>

## Starting 🚀

_These instructions will allow you to get a copy of the project running on your local machine for development and testing purposes.._

```
🟠 Linux

curl -O http://files.sa-mp.com/samp037svr_R2-1.tar.gz

tar -xvf samp037svr_R2-1.tar.gz

cd samp03

rm -rf scriptfiles npcmodes include gamemodes

git clone https://github.com/SedaxMx/Samp-Server.git

mv Samp-Server/* ./


🔵 Windows

md sampserver

cd sampserver

cURL -O http://files.sa-mp.com/samp037_svr_R2-1-1_win32.zip

tar -xf samp037_svr_R2-1-1_win32.zip

DEL scriptfiles npcmodes include gamemodes

git clone https://github.com/SedaxMx/Samp-Server.git

```

> 🔵 Last step of Windows: Move all files from the Samp-Server folder to the root directory of your server (sampserver).

## Prerequisites 📋

> Plugins necessary <br>
> 🟠 Linux <br>
> 🔵 Windows <br>

🔗 MySQL 🔵: https://github.com/pBlueG/SA-MP-MySQL/releases/download/R41-4/mysql-R41-4-Debian-static.tar.gz <br>
🔗 MySQL 🟠: https://github.com/pBlueG/SA-MP-MySQL/releases/download/R41-4/mysql-R41-4-win32.zip <br>

🔗 Sscanf 🔵: https://github.com/maddinat0r/sscanf/releases/download/v2.8.3/sscanf-2.8.3-win32.zip <br>
🔗 Sscanf 🟠: https://github.com/maddinat0r/sscanf/releases/download/v2.8.3/sscanf-2.8.3-linux.tar.gz <br>

🔗 Streaner 🔵 🟠: https://github.com/samp-incognito/samp-streamer-plugin/releases/download/v2.9.5/samp-streamer-plugin-2.9.5.zip <br>

> INSERTAR AQUI LAS INTRUCCIONES DE COMO MONTAR LA BASE DE DATOS QUE SE SUBIRA EN EL PRIMER COMMIT

## Running tests ⚙️

_Start the samp-server and wait for it to load, make sure no errors are reported._


## Built with 🛠️

* [Pawno](https://es.wikipedia.org/wiki/Pawn) - The samp programming language

## Versions 📌

For all available versions, see the [tags in this repository](https://github.com/SedaxMx/Samp-Server/tags).

## Authors ✒️ and credits 🎁

* **SedaxMx** - *Development of gamemode, systems, filterscripts, forum and server web panel.* - [SedaxMx](https://github.com/SedaxMx)

You can also check the list of [credits](https://github.com/SedaxMx/Samp-Server/contributors) of the plugins that were used in the development of the gamemode.

## Licencia 📄

This project is licensed under the License (License) - see the file [LICENSE.md](LICENSE.md) for details.

---
With ❤️ [SedaxMx](https://github.com/SedaxMx) 😊
