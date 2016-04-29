## Provisioning scripts
This folder holds a collection of PowerCLI scripts designed to automate the bulk provisioning of virtual environments, including the following;

1. Storage
  1. Create flexvols
  2. Configure NFS exports
  3. Set advanced options
2. vCenter tasks
  1. Create VMFS datastores
  2. Create VM folders
  3. Create VMs, including additional hardware (NICs, hard disks etc)
3. Guest OS configuration
  1. For Windows servers, set boot.ini timeouts, join an AD domain, configure the pagefile, configure networking (IP, gateway, DNS etc)
  2. For Linux servers, configure networking (IP, gateway, DNS etc), /etc/fstab and mount NFS storage
  
The scripts are driven by an Excel spreadsheet which acts as the master configuration sheet.
