# Make executable
chmod +x install-packages.sh
chmod +x harvest.sh

# Run it - everything is automated
sudo bash install-packages.sh
sudo bash harvest.sh



# to stop
sudo systemctl unmask dhcpcd
sudo systemctl start dhcpcd
sudo reboot
