# KDE Store listing

Copy into [KDE Store](https://store.kde.org/). Details: [github.com/shrippen/Kurrent](https://github.com/shrippen/Kurrent)

## Short description

Plasma 6 task widget (Akonadi / Nextcloud CalDAV). Store package = UI only — install the backend from GitHub.

## Long description

**The `.plasmoid` zip is not enough.** Kurrent needs a compiled Akonadi plugin (`libkurrentplugin.so`) that is **not** included in the Store package. Without it you see “backend not installed”.

**Requirements:** KDE Plasma 6, Akonadi with VTODO (Merkuro/KOrganizer + CalDAV).

**Install (UI + plugin):**

```
curl -fsSL https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh | sudo bash
```

Add **Kurrent** to panel or desktop if it is not there yet.

**Updates:** “Get New Widgets” refreshes only the UI zip, not the plugin. Re-run the one-liner (or `./install.sh` from a clone). A Store UI update without a matching plugin shows a version mismatch warning until you reinstall.

Releases: [github.com/shrippen/Kurrent/releases](https://github.com/shrippen/Kurrent/releases) · GPL-3.0-or-later
