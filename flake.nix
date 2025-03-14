{
    inputs.nixpkgs.url = "nixpkgs";

    outputs = { nixpkgs, self}: {
        packages.x86_64-linux = builtins.mapAttrs (name: value: value.config.system.build.vm) self.nixosConfigurations;

        nixosConfigurations.test-base = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                self.nixosModules.vm-basics
            ];
        };

        nixosConfigurations.test-base-graphics = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                self.nixosModules.vm-basics
                self.nixosModules.minimal-graphic
            ];
        };

        nixosConfigurations.test-memlimit = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                self.nixosModules.vm-basics
                self.nixosModules.mem-limit
            ];
        };

        nixosConfigurations.test-zram = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                self.nixosModules.vm-basics
            ];
        };

        nixosModules.vm-basics = {pkgs, lib, modulesPath, ...}: {
            imports = [
                "${modulesPath}/virtualisation/qemu-vm.nix"
                self.nixosModules.mem-test-tools
            ];

            virtualisation.graphics = lib.mkDefault false;
            virtualisation.diskImage = null;
            virtualisation.cores = lib.mkDefault 8;
            virtualisation.memorySize = lib.mkDefault 1024;

            # Somehow we end up with "/" using mode=777 when using tmpfs.
            # But then sshd won't let us log in
            virtualisation.fileSystems."/" = {
                options = lib.mkForce [ "mode=755" "uid=0" "gid=0" ];
            };

            services.getty.autologinUser = "test";

            # users.mutableUsers = false;
            users.users.test = {
                isNormalUser = true;
                group = "users";
                extraGroups = ["wheel"];
                password = "";
                openssh.authorizedKeys.keys = [
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrvdnfRte2aM39d+GdUVt+KI6HqP8opmmuxYXKdBMzF birk@erebus"
                    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuZp5Quo2ubCkxqX6D1DIqKVf+p98ffcNg6f9M6Nc9X birk@granite"
                ];
            };

            users.groups.users = {};

            security.sudo.wheelNeedsPassword = false;

            virtualisation.forwardPorts = [
                { from = "host"; host.port = 2222; guest.port = 22; }
            ];
            networking.firewall.enable = false;
            services.openssh.enable = true;
            # services.openssh.settings.PermitEmptyPasswords = "yes";

            environment.systemPackages = with pkgs; [
                htop
                tmux
                xterm
            ];

            environment.sessionVariables.TERM = "xterm-256color";

            system.stateVersion = "24.11";
        };

        nixosModules.mem-limit = {pkgs, ...}: {
            systemd.slices."user".sliceConfig = {
                MemoryMax="600M";
            };
        };

        nixosModules.minimal-graphic = {pkgs, ...}: {
            virtualisation.graphics = true;
            virtualisation.memorySize = 2 * 1024;

            services.xserver.enable = true;
            services.displayManager.autoLogin = {
                enable = true;
                user = "test";
            };
            services.xserver.windowManager.openbox.enable = true;
            environment.systemPackages = with pkgs; [
                firefox
            ];
        };

        nixosModules.mem-test-tools = {pkgs, ...}: let
            mem-stress-test = pkgs.writers.writePython3Bin "mem-stress-test" {} ''
                import time
                import sys

                num_allocs = int(sys.argv[1])

                print(f"Allocating {num_allocs} MiB")

                allocs = [bytearray(1024*1024) for i in range(num_allocs)]

                print("\nWait")

                while True:
                    for pos in range(20):
                        s = ' ' * pos + "#" + ' ' * (20 - pos)
                        print(s, end="\r")
                        time.sleep(1)
            '';

            mem-ripgrep-test = pkgs.writeShellScriptBin "mem-ripgrep-test" ''
                cargo install ripgrep
            '';
        in {
            environment.systemPackages = with pkgs; [
                mem-stress-test
                mem-ripgrep-test
                cargo
                rustc
                gcc
                fish
            ];
        };
    };
}

