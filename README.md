# Solo for Nix

A Nix flake for [Solo](https://soloterm.com) on x86_64 Linux. It packages the
same Linux release that soloterm.com offers for download and follows it
automatically.

## Install

Try it without installing:

```sh
nix run github:soloterm/nix
```

Install it into your profile:

```sh
nix profile install github:soloterm/nix
```

Or add it to a NixOS or Home Manager configuration:

```nix
{
  inputs.solo.url = "github:soloterm/nix";

  outputs = { nixpkgs, solo, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        {
          environment.systemPackages = [ solo.packages.x86_64-linux.default ];
        }
      ];
    };
  };
}
```

Solo is commercial software, so its license is marked unfree. The flake's own
package is already allowed. If you use `overlays.default` with your own
nixpkgs instead, allow it there:

```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "solo" ];
```

The package installs three programs: `Solo` (the app), `solo` (the command line
tool), and `mcp` (the helper that coding agents use to talk to Solo).

## Updates

Nix manages updates for this package, so Solo's built-in updater stays off.
Run `nix flake update solo` in your configuration, or
`nix profile upgrade --all` for a profile install.

This repository checks soloterm.com every hour. When a new release is
published to everyone, it verifies the release's signature, builds the
package, launches Solo on NixOS, and only then updates `source.json`.

## How it is built

The package extracts the Linux AppImage and relinks Solo's own binaries
against nixpkgs' WebKitGTK and GTK, instead of running the libraries the
AppImage bundles. Solo runs natively, not in a sandbox, so tools like `sudo`
work normally in its terminals.

On NixOS, graphics come from the system's drivers (`hardware.graphics.enable`).
With Nix on another Linux distribution, the app may need a wrapper such as
[nixGL](https://github.com/nix-community/nixGL) to find your GPU drivers.

## Support

Report problems with Solo itself at <https://soloterm.com>. Problems with the
packaging belong in this repository's issues.
