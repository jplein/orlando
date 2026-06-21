{
  description = "Orlando — a Markdown rendering plugin for Neovim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      # Systems home-manager users are likely to be on.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # Build the plugin from this repo. Takes a pkgs so it works both as a
      # package output and from inside the overlay.
      mkOrlando =
        pkgs:
        pkgs.vimUtils.buildVimPlugin {
          pname = "orlando-nvim";
          version = self.shortRev or self.dirtyShortRev or "unstable";
          src = self;
          meta = {
            description = "A Markdown rendering plugin for Neovim";
            homepage = "https://github.com/jplein/orlando";
            license = pkgs.lib.licenses.mit;
          };
        };
    in
    {
      # Per-system package. Use directly in home-manager:
      #   programs.neovim.plugins = [ orlando.packages.${pkgs.system}.default ];
      packages = forAllSystems (pkgs: {
        orlando-nvim = mkOrlando pkgs;
        default = self.packages.${pkgs.system}.orlando-nvim;
      });

      # Overlay so the plugin is available as pkgs.vimPlugins.orlando-nvim after
      # adding it to nixpkgs.overlays. Then:
      #   programs.neovim.plugins = [ pkgs.vimPlugins.orlando-nvim ];
      overlays.default = final: prev: {
        vimPlugins = prev.vimPlugins // {
          orlando-nvim = mkOrlando final;
        };
      };

      # `nix fmt`
      formatter = forAllSystems (pkgs: pkgs.nixfmt-rfc-style);
    };
}
