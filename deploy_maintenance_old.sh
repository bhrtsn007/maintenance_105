#!/bin/bash
echo "####################################################################"
echo "Installation Started"
echo "####################################################################"
echo ""
echo ""
echo "Renaming file"
rm -r /home/gor/easy_console/maintenance
mv /home/gor/easy_console/maintenance_105 /home/gor/easy_console/maintenance
echo "making all file executable"
sudo find /home/gor/easy_console/maintenance -type f -iname "*.sh" -exec chmod +x {} \;
sudo find /home/gor/easy_console/maintenance -type f -iname "*.escript" -exec chmod +x {} \;
echo ""
sudo rm /home/gor/easy_console/maintenance/VARIABLE 
echo ""
echo "####################################################################"
echo "Installation Completed"
echo "####################################################################"
