# Caldera Installation Guide

---

## Ubuntu

- Add the latest Python 3.9 repository to your system
    ```
    sudo add-apt-repository ppa:deadsnakes/ppa
    ```

- Update local package index
    ```
    sudo apt update
    ```
  
- Install tools to manage software repositories
    ```
    sudo apt install software-properties-common -y
    ```
  
- Install Python 3.9 along with support for virtual environments and distutils
    ```
    sudo apt install python3.9 python3.9-venv python3.9-distutils -y
    ```
- Installs curl, which helps fetch remote scripts
  ```
  sudo apt install curl
  ```
  
- Install pip (Python package manager) for managing dependencies
  ```
  curl -sS https://bootstrap.pypa.io/get-pip.py | sudo python3.9
  ```
- Install Go to compile agents in real time
  ```commandline
  sudo apt install golang-go
  ```
- Download and install the Node.js v16 setup script
  ```commandline
  curl -fsSl <https://deb.nodesource.com/setup_16.x> | sudo -E bash 
  ```
  
- Install Git to clone the CALDERA GitHub repo
  ```commandline
  sudo apt install git
  ```
  
- Clone the CALDERA repository
  ```commandline
  git clone --recursive <https://github.com/mitre/caldera.git>
  ```

- Navigate to the project directory
  ```commandline
  cd caldera
  ```
  
- Create a virtual environment with Python 3.9
  ```commandline
  python3.9 -m venv venv
  ```
  
- Activate the virtual environment
  ```
  source venv/bin/activate
  ```
 
- Install npm for building the UI components (VueJS-based) 
  ```commandline
  sudo apt install npm
  ```
  
- Start the CALDERA server with insecure mode
  ```commandline
  python3 server.py --insecure --build
  ```
  
- You can now access the CALDERA web UI via http://127.0.0.1:8888 (by default).

---

## Reasources

- [GitHub Repo](https://github.com/mitre/caldera?tab=readme-ov-file)