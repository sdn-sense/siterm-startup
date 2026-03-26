#!/usr/bin/env bash

CONFIG_TEMPLATE="/etc/vpp/startup.conf-template"
CONFIG_OUTPUT="/etc/vpp/startup.conf"

# Function to configure interface
configure_interface() {
    local interface=$1
    # Check if interface variable is defined and not empty
    if [ -z "$interface" ]; then
        echo "Skipping undefined interface variable."
        return
    fi

    # Set interface down
    ip link set down "$interface"
    # Apply hardware-specific optimizations
    ethtool -K "$interface" rx off
    ethtool -K "$interface" tx off
    ethtool -K "$interface" sg off
    ethtool -K "$interface" tso off
    ethtool -K "$interface" ufo off
    ethtool -K "$interface" gso off
    ethtool -K "$interface" gro off
    ethtool -K "$interface" lro off
    ethtool -K "$interface" rxvlan off
    ethtool -K "$interface" txvlan off
    ethtool -K "$interface" ntuple off
    ethtool -K "$interface" rxhash off
    ethtool --set-eee "$interface" eee off
    ethtool -C "$interface" adaptive-rx off
    ethtool -C "$interface" rx-usecs 1000
    local max_rx
    local max_tx
    max_rx=$(ethtool -g "$interface" | grep 'RX:' | awk '{print $2}' | head -1)
    max_tx=$(ethtool -g "$interface" | grep 'TX:' | awk '{print $2}' | head -1)
    ethtool -G "$interface" rx "$max_rx" tx "$max_tx"
}

# Array of interfaces to configure
interfaces=("$ENV_PUBLIC_INTF" "$ENV_PRIVATE_INTF")

# Loop through each interface and configure it
for interface in "${interfaces[@]}"; do
    configure_interface "$interface"
done

# Update configuration file to match correct PCI device inside VPP
cp "$CONFIG_TEMPLATE" "$CONFIG_OUTPUT"

# Replace all variables in the configuration file
sed -i "s/ENV_MAIN_CORE/$ENV_MAIN_CORE/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_CORELIST_WORKERS/$ENV_CORELIST_WORKERS/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_BUFFERS_PER_NUMA/$ENV_BUFFERS_PER_NUMA/g" "$CONFIG_OUTPUT"
# Interface 1 (net1)
sed -i "s/ENV_PUBLIC_INTF_RXQ/$ENV_PUBLIC_INTF_RXQ/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PUBLIC_INTF_TXQ/$ENV_PUBLIC_INTF_TXQ/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PUBLIC_INTF_RXDESC/$ENV_PUBLIC_INTF_RXDESC/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PUBLIC_INTF_TXDESC/$ENV_PUBLIC_INTF_TXDESC/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PUBLIC_INTF_PCI/$ENV_PUBLIC_INTF_PCI/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PUBLIC_INTF/$ENV_PUBLIC_INTF/g" "$CONFIG_OUTPUT"

# Interface 2 (net2)
sed -i "s/ENV_PRIVATE_INTF_RXQ/$ENV_PRIVATE_INTF_RXQ/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PRIVATE_INTF_TXQ/$ENV_PRIVATE_INTF_TXQ/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PRIVATE_INTF_RXDESC/$ENV_PRIVATE_INTF_RXDESC/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PRIVATE_INTF_TXDESC/$ENV_PRIVATE_INTF_TXDESC/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PRIVATE_INTF_PCI/$ENV_PRIVATE_INTF_PCI/g" "$CONFIG_OUTPUT"
sed -i "s/ENV_PRIVATE_INTF/$ENV_PRIVATE_INTF/g" "$CONFIG_OUTPUT"

echo "Configuration generated at $CONFIG_OUTPUT"
cat "$CONFIG_OUTPUT"

echo "Start VPP"
exec /usr/bin/vpp -c /etc/vpp/startup.conf
