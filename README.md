cd /tmp

wget https://github.com/anderssjoeberg75/Ubuntuinstall/archive/refs/heads/main.zip

unzip -o

cd /tmp/Ubuntuinstall-main

chmod +x joins_ad.sh

sudo ./joins_ad.se


Registrera nyckel ersätt username med användarnamnet 

pamu2fcfg -u username | sudo tee -a /etc/Yubico/u2f_keys
