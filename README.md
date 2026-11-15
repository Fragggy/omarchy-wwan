# Omarchy WWAN

A standalone, theme-aware Quickshell bar widget for mobile broadband on Omarchy. It does **not** modify or replace Omarchy's built-in network widget.

It shows modem registration, cellular technology, signal, connection state, and live download/upload rates. Its popup connects or disconnects a saved NetworkManager profile and opens the existing NetworkManager connection editor for APN or SIM configuration.

## Requirements

- Omarchy with Quickshell
- NetworkManager and `nmcli`
- ModemManager and `mmcli`
- A saved mobile-broadband NetworkManager connection, such as `O2`

## Install

```bash
git clone https://github.com/Fragggy/omarchy-wwan ~/Git/omarchy-wwan
cd ~/Git/omarchy-wwan
./install.sh
```

Add the widget to the `right` bar layout in `~/.config/omarchy/shell.json`:

```json
{
  "id": "munzlind.wwan",
  "profile": "O2",
  "displayMode": "full",
  "hideWhenUnavailable": true
}
```

The source working tree remains in `/home/munzlind/Git/omarchy-wwan`. Omarchy does not accept symbolic-link plugin folders, so `./install.sh` mirrors the tracked source into `~/.config/omarchy/plugins/munzlind.wwan/`. Run it after edits to install the current version.

## Usage

- Click the bar item to open the WWAN panel.
- Click **Connect** or **Disconnect** to control the configured profile.
- Click **Settings** to open `nm-connection-editor` for APN and connection changes.
- Use the Omarchy plugin configuration to change the NetworkManager profile or switch the bar between full and compact modes.

The widget never displays modem identifiers, SIM identifiers, or connection credentials.

## Development

```bash
npm test
omarchy plugin validate .
```

The helper can be inspected without connecting the modem:

```bash
WWAN_PROFILE=O2 ./scripts/wwan-status
```
