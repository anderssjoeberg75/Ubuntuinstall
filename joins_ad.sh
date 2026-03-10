#!/bin/bash

# Avbryt om ett fel uppstår
set -e

# Kontrollera att scriptet körs med sudo/root-rättigheter
if [ "$EUID" -ne 0 ]; then
  echo "Fel: Detta script måste köras som root. Använd: sudo $0"
  exit 1
fi

echo "=== AD-integration Ubuntu ==="
read -p "Ange domännamn (t.ex. foretag.local): " DOMAIN
read -p "Ange AD-administratör för anslutningen (t.ex. Administrator): " AD_USER

# SSSD-inställningar
DOMAIN_LOWER=$(echo "$DOMAIN" | tr '[:upper:]' '[:lower:]')
DOMAIN_UPPER=$(echo "$DOMAIN" | tr '[:lower:]' '[:upper:]')

echo "--------------------------------------------------------"
echo "Steg 1/4: Installerar beroenden..."

DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -f
DEBIAN_FRONTEND=noninteractive apt-get install -y \
realmd \
sssd \
sssd-tools \
sssd-ad \
libnss-sss \
libpam-sss \
adcli \
samba-common-bin \
oddjob \
oddjob-mkhomedir \
packagekit \
libpam-u2f \
pamu2fcfg \
yubikey-manager

clear
echo "--------------------------------------------------------"
echo "Installerar Atera..."
cd /tmp
wget -O - "https://HelpdeskSupport1716224482358.servicedesk.atera.com/api/utils/AgentInstallScript/Linux/001Q300000GBMGxIAP?customerId=1" | sudo bash
usermod -aG input $USER
echo 'KERNEL=="uinput", GROUP="input", MODE="0660"' | sudo tee /etc/udev/rules.d/80-uinput.rules
sleep 5
clear
echo "--------------------------------------------------------"
echo "Steg 2/4: Ansluter till domänen $DOMAIN_LOWER..."

# Detta kommando kommer att fråga efter lösenordet för AD-administratören
realm join -U "$AD_USER" "$DOMAIN_LOWER"

echo "--------------------------------------------------------"
echo "Steg 3/4: Konfigurerar SSSD..."



cat << EOF > /etc/sssd/sssd.conf
[sssd]
domains = $DOMAIN_LOWER
config_file_version = 2
services = nss, pam

[domain/$DOMAIN_LOWER]
default_shell = /bin/bash
krb5_store_password_if_offline = True
cache_credentials = True
krb5_realm = $DOMAIN_UPPER
realmd_tags = manages-system joined-with-adcli
id_provider = ad
fallback_homedir = /home/%u
ad_domain = $DOMAIN_LOWER
use_fully_qualified_names = False
ldap_id_mapping = True
access_provider = ad
ad_gpo_ignore_unreadable = True
EOF

chmod 600 /etc/sssd/sssd.conf
systemctl restart sssd

echo "--------------------------------------------------------"
echo "Konfigurerar systemet för youbikey..."

cp /etc/pam.d/gdm-password /etc/pam.d/gdm-password.bak
cp /etc/pam.d/login /etc/pam.d/login.bak
sudo mkdir -p /etc/Yubico

cat << EOF > /etc/udev/rules.d/90-yubikey-lock.rules
ACTION=="remove", ATTRS{idVendor}=="1050", RUN+="/usr/local/bin/yubikey-lock.sh"
EOF

cat << EOF > /usr/local/bin/yubikey-lock.sh
#!/bin/bash
USER=$(loginctl list-sessions | awk 'NR==2 {print $3}')
SESSION=$(loginctl list-sessions | awk 'NR==2 {print $1}')
loginctl lock-session "$SESSION"
EOF

echo "%#800223789 ALL=(ALL:ALL) ALL" >> /etc/sudoers
echo "Defaults match_group_by_gid" >> /etc/sudoers

echo "sudoers: files" >> /etc/nsswitch.conf

sleep 5
clear
echo "--------------------------------------------------------"
echo "Steg 4/4: Aktiverar automatisk skapande av hemkatalog vid inloggning..."
pam-auth-update --enable mkhomedir

echo "--------------------------------------------------------"
echo "KLART!"
echo "Datorn är nu ansluten till $DOMAIN_LOWER."
echo "Användare kan nu logga in med sina AD-konton."
echo " "
echo "--------------------------------------------------------"
echo "Datorn startar om själv när allt är klart.
sleep 5
reboot

