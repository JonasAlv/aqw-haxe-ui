# VibeSkua-inspired top bar prototype

This folder is an experimental Haxe/Flash port of the *interaction pattern* used by the Avalonia client in [NinjaXz/VibeSkua](https://github.com/NinjaXz/VibeSkua), especially its `Skua.App.Avalonia/Views/MainWindow.axaml` top navigation and `Skua.App.Avalonia/AppStartup/MainMenu.cs` menu definitions.

## Included

- Compact dark top navigation with subtle borders and hover states.
- Dropdown groups for Scripts, Options, Tools & Helpers, Combat, Diagnostics, and Plugins.
- Bank as a direct action.
- Right-side Auto and Jump toggles plus a tools-launcher action.
- Callback hooks so the host client can connect menu actions to existing commands.

## Menu groups

- **Scripts:** Script Loader, Scheduler, Script Repo
- **Options:** Game, Application, CoreBots, Application Themes, HotKeys
- **Tools & Helpers:** Loadouts Manager, Fast Travel, Loader, Grabber, Current Drops, Junk Items
- **Combat:** Skills, Stats, Runtime
- **Bank:** direct action
- **Diagnostics:** Logs, Console, Spammer, Logger, Interceptor
- **Plugins:** Plugin Manager

## Integration status

`TopBarMenuPrototype` is intentionally isolated and is not yet wired into the existing AQW UI root. Set `onAction`, `onAutoToggle`, `onJumpToggle`, and `onToolsRequested` to connect it to real client behavior, then mount it in the existing UI root. This keeps the first pass safe to iterate on without replacing the current interface.

The Haxe source is an original implementation of the visual/interaction approach; it does not copy the Avalonia XAML or C# implementation.
