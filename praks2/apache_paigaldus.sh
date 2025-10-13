#! /bin/bash
# See skript kontrollib kas teenus olemas ja paigaldab kui pole

# Kontroll, kas skript käivitatakse root kasutajana
if [ "$(id -u)" -ne 0 ]; then
  echo "Kasuta sudo või root."
  exit 1
fi

service="apache2"

echo "Kontrollin, kas $service on paigaldatud"

if dpkg -l | grep -q "^ii  $service "; then
  echo "$service on juba paigaldatud."
  echo ""
  echo "Teenuse staatus:"
  systemctl status $service --no-pager
else
  echo "$service ei ole paigaldatud."
  echo "Paigaldan teenuse"
  apt update -y
  apt install -y $service

  if [ $? -eq 0 ]; then
    echo "$service on edukalt paigaldatud!"
    systemctl enable $service
    systemctl start $service
    echo ""
    echo "Teenuse staatus:"
    systemctl status $service --no-pager
  else
    echo "Paigaldamine ebaõnnestus."
    exit 1
  fi
fi
