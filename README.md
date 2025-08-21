# NXCloud (Zenity GUI Edition)

**Version 1.3**  
A libre (`nextcloud-aio-nextcloud`) easier.  
It provides a **Zenity-based menu interface** with progress bars and logs, making updates more transparent and troubleshooting easier.  

---

## ✨ Features
- **Built for Nextcloud AIO** instances (`nextcloud-aio-nextcloud`)  
- **GUI-driven**: Simple Zenity dialogs and menus  
- **Menu options**:
  1. Run Nextcloud Updater  
  2. Maintenance Repair  
  3. Database Optimization (add missing indices)  
  4. Disable Maintenance Mode
  5. update All Nextcloud Apps
  6. View Logs  
  7. Exit  
- **Logs saved automatically** for transparency and debugging  
- **Error handling** with clear messages  

---

## 📌 Requirements

This script is **only compatible with Nextcloud AIO instances**.  

### Dependencies (on your local desktop):
- `zenity` (for GUI dialogs)  
- `ssh` (for remote connection)  
- `sshpass` (for password handling)  

### Remote server must have:
- A running **Nextcloud AIO container** (`nextcloud-aio-nextcloud`)  
- **Docker** installed  
- An SSH user with **sudo privileges**  

---

## ⚙️ Installation

Clone this repository or download the script:  
```bash
git clone https://github.com/minto3792/nxcloud.git
cd nxcloud
chmod +x nxcloud.sh
