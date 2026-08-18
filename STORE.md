# Kurrent — KDE Store listing

Copy the **Short description** and **Long description** into the [KDE Store](https://store.kde.org/) entry.

---

## Short description

Plasma 6 task widget for Akonadi / Nextcloud CalDAV. The Store package is the UI only — also run the GitHub install-linux.sh one-liner (or ./install.sh) for the plugin.

---

## Long description

**This widget cannot run from the KDE Store package alone.**

Kurrent is a Plasma 6 task manager that uses your existing Akonadi setup (Merkuro or KOrganizer, including Nextcloud CalDAV). There is no separate login.

The Store / “Get New Widgets” package is **only the QML interface**. Tasks are loaded by a compiled plugin (`libkurrentplugin.so`) that talks to Akonadi. That plugin is architecture-specific and is **not** inside the `.plasmoid` zip. If you install from the Store and stop there, the widget will open and tell you the backend is missing.

To actually use Kurrent you install from GitHub. That copies both the widget and the plugin.

Source and releases: [https://github.com/shrippen/Kurrent](https://github.com/shrippen/Kurrent)

### What you need

- KDE Plasma 6
- Akonadi with a task-capable calendar (DAV groupware / Nextcloud VTODO)
- Build tools (the one-liner installs these on Arch, Fedora, Debian/Ubuntu, and openSUSE)

### First install

If you already added Kurrent from the Store, leave it. The one-liner replaces the UI and installs the plugin:

```
curl -fsSL https://github.com/shrippen/Kurrent/releases/latest/download/install-linux.sh | sudo bash
```

That installs runtime packages, downloads the Linux plugin tarball from the latest GitHub Release, copies it to `~/.local`, and restarts Plasma. From a clone you can run `./install.sh` instead. Then:

1. Right-click the panel or desktop → **Add Widgets** → **Kurrent** (skip if it is already there).
2. Confirm Akonadi is up: `akonadictl status`
3. If you have no tasks yet, add a DAV resource in **Merkuro** or **KOrganizer** (Nextcloud / CalDAV) and enable the task lists.

After a successful install you should see Inbox / Today / projects instead of the “backend not installed” message.

### Update

Do **not** rely on “Get New Widgets” / Store updates for a working Kurrent. That only refreshes the UI zip and will not update the plugin. Run the same one-liner again, or from a git checkout:

```
cd Kurrent
git pull
./install.sh
```

If you deleted the clone, the one-liner is enough — it overwrites the previous user install.

To install a **specific release** instead of `main` / `1.0`:

```
cd Kurrent
git fetch --tags
git checkout v0.2.0
./install.sh
```

Check the latest tag on the [Releases page](https://github.com/shrippen/Kurrent/releases).

### If something looks stale after an update

`./install.sh` restarts plasmashell. If the widget still shows old UI or “backend not installed”:

```
kquitapp6 plasmashell; plasmashell --replace &
```

Log out and back in only if that does not pick up `~/.local`.

### Uninstall (user install)

```
kpackagetool6 -t Plasma/Applet -r com.github.shrippen.kurrent
rm -rf ~/.local/lib/qml/com/github/shrippen/kurrent \
       ~/.local/share/qt6/qml/com/github/shrippen/kurrent \
       ~/.local/share/plasma/plasmoids/com.github.shrippen.kurrent
rm -f ~/.config/plasma-workspace/env/kurrent-qml.sh
```

Then restart Plasma.

---

This project is a personal tool shared as-is (GPL-3.0-or-later). Issues: [https://github.com/shrippen/Kurrent/issues](https://github.com/shrippen/Kurrent/issues)
