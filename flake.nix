{
    inputs.nixpkgs.url = "nixpkgs";

    outputs = { nixpkgs, self}: {
        packages.x86_64-linux.test-base = self.nixosConfigurations.test-1.config.system.build.vm;
        nixosConfigurations.test-base = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
                self.nixosModules.vm-basics
                self.nixosModules.mem-stress-test
            ];
        };

        packages.x86_64-linux.test-zram = self.nixosConfigurations.test-1.config.system.build.vm;
        nixosConfigurations.test-zram = nixpkgs.lib.nixosSystem {
            system = "x86_64-linux";
            modules = [
                "${nixpkgs}/nixos/modules/virtualisation/qemu-vm.nix"
                self.nixosModules.vm-basics
                self.nixosModules.mem-stress-test
            ];
        };

        nixosModules.vm-basics = {pkgs, lib, ...}: {
            virtualisation.graphics = false;
            virtualisation.diskImage = null;
            # virtualisation.fileSystems = lib.mkForce { };
            virtualisation.cores = 8;

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
                ];
            };

            users.groups.users = {};

            security.sudo.wheelNeedsPassword = false;

            virtualisation.forwardPorts = [
                { from = "host"; host.port = 2222; guest.port = 22; }
                { from = "host"; host.port = 2221; guest.port = 2221; }
            ];
            networking.firewall.enable = false;
            services.openssh.enable = true;
            # services.openssh.settings.PermitEmptyPasswords = "yes";

            environment.systemPackages = with pkgs; [
                htop
                tmux
                xterm
                cargo
                rustc
                gcc
            ];

            environment.sessionVariables.TERM = "xterm-256color";

            system.stateVersion = "24.11";
        };

        nixosModules.mem-stress-test = {pkgs, ...}: {
            environment.systemPackages = [(pkgs.writers.writePython3Bin "mem-stress-test" {} ''
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
            '')];
        };
    };
}

