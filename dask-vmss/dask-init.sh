#!/bin/sh

USERNAME=$1
CONDA_ENV=$2
WHEEL=$3
DASK_SCHEDULER_IP=$4
TYPE=$5

echo "Installing wheel..."
sudo -u $USERNAME -i /bin/bash -l -c "conda init bash"
sudo -u $USERNAME -i /bin/bash -l -c "conda activate $CONDA_ENV; pip install $WHEEL"

echo "Setting up service scripts..."
cat > /home/$USERNAME/dask-head.sh << EOM
#!/bin/bash
conda activate $CONDA_ENV

ulimit -n 65536
export DASK_SCHEDULER_ADDRESS=tcp://localhost:8786

cd /home/$USERNAME
dask-scheduler --version

dask-scheduler --port 8786
EOM


cat > /home/$USERNAME/dask-worker.sh << EOM
#!/bin/bash
conda activate $CONDA_ENV

ulimit -n 65536

cd /home/$USERNAME
dask-worker --version

while true
do
   dask-worker tcp://$DASK_SCHEDULER_IP:8786 --nanny-port 8001
   echo Dask exited. Auto-restarting in 1 second...
   sleep 1
done
EOM



chmod +x /home/$USERNAME/dask-head.sh
chmod +x /home/$USERNAME/dask-worker.sh

cat > /lib/systemd/system/dask.service << EOM
[Unit]
   Description=Dask
[Service]
   Type=simple
   User=$USERNAME
   ExecStart=/bin/bash -l /home/$USERNAME/dask-$TYPE.sh
[Install]
WantedBy=multi-user.target
EOM

echo "Configure dask to start at boot..."
systemctl enable dask

echo "Starting dask..."
systemctl start dask

if [ "$TYPE" = "head" ]; then
   echo "Cloning dask-example repo..."
   git clone https://github.com/dask/dask-docker.git   /home/$USERNAME/notebooks/dask
   chmod -R 755 /home/$USERNAME/notebooks/dask
fi