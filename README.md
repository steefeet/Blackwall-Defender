# Blackwall Defender

A local, read-only computer-health dashboard for Windows. Review recent system errors, basic drive health, recorded changes, and Windows repair-log history in one window.

Early prototype. This is a diagnostic overview, not antivirus software or a complete hardware diagnostic.

## Run

1. Download the project ZIP and extract the whole folder.
2. Double-click `Start-Blackwall-Defender.cmd`.
3. Click **Scan this PC**.

Keep the program files and `Assets` folder together. Create a desktop shortcut to the launcher if desired; moving the launcher alone will break it.

Windows PowerShell 5.1 and the built-in WPF framework are required. Tested on Windows 11. Windows 10 compatibility has not been verified; exact title-bar colors require Windows 11.

No extra packages are required. The unsigned launcher uses a process-only execution-policy override; it does not change your saved execution policy. Organization policies can still block it. Administrator access is optional and may improve access to some checks.

## Features

- Up to 500 recent Windows System-log errors and critical events from the last seven days.
- Plain-language event explanations, suggested next steps, and original evidence.
- Basic system-drive space and physical-drive health status.
- Available recent hotfixes and recorded app install/update dates, newest first.
- Historical corruption and repair clues from the current CBS log.
- New-event comparison with the previous scan and JSON report export.
- Light and dark themes with a saved preference and matching Windows 11 title bar.

## Privacy

The app makes no network requests and uploads nothing. It writes a local comparison report and theme preference under `%LOCALAPPDATA%\PCPulse` (the original internal storage name, retained for compatibility).

Reports contain your computer name and event messages, which may include personal information. Review reports before sharing. Do not commit your reports, CBS logs, or crash dumps to a public repository.

## Limits

- No automatic repair, deletion, system-setting changes, background monitoring, or malware scan.
- System logs only; application and security event logs are not included.
- Basic drive status cannot rule out hardware failure; detailed SMART data and temperatures are not included.
- Update and app-date history is partial. Timing alone does not establish the cause of a failure.
- CBS entries are historical. An old corruption entry may remain after repair, and an absence of matching entries does not verify system-file integrity.
- Missing permissions are reported as unavailable coverage rather than a successful check.

## Project files

- `Blackwall-Defender.ps1`: desktop interface, themes, local report storage, and export.
- `Collect-Health.ps1`: read-only Windows data collection.
- `Start-Blackwall-Defender.cmd`: portable launcher.
- `Assets/Blackwall-Defender.ico`: multi-size desktop/window icon.

The application and icon were developed with AI assistance. The icon was generated from a user-supplied red digital-rain reference. No affiliation with Microsoft or a game publisher is claimed.

## Reporting problems

Include your Windows version, what you clicked, what happened, and the exact error text. Redact personal details before attaching logs or screenshots.
