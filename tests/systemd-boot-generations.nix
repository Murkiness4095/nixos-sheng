{
  name = "sheng-systemd-boot-generations";
  defaults = {
    virtualisation.useBootLoader = true;
    virtualisation.useEFIBoot = true;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;
    system.switch.enable = true;
    nix.enable = true;
    environment.etc."machine-id".text = "1234567890abcdef1234567890abcdef\n";
  };
  nodes = {
    machine = { nodes, ... }: {
      system.extraDependencies = [ nodes.candidate.system.build.toplevel ];
    };
    candidate.system.nixos.label = "efi-generation-2";
  };
  testScript = { nodes, ... }: ''
    first = "${nodes.machine.system.build.toplevel}"
    second = "${nodes.candidate.system.build.toplevel}"

    def check_boot(system):
        machine.wait_for_unit("multi-user.target")
        machine.succeed("test -d /sys/firmware/efi")
        machine.succeed(f'test "$(readlink -f /run/booted-system)" = "{system}"')

    machine.start()
    check_boot(first)
    profile = "/nix/var/nix/profiles/system"
    machine.succeed(f"nix-env -p {profile} --set {second}")
    machine.succeed(f"{second}/bin/switch-to-configuration boot")
    machine.shutdown()
    machine.start()
    check_boot(second)
    machine.succeed(f"nix-env -p {profile} --rollback")
    machine.succeed(f"{first}/bin/switch-to-configuration boot")
    machine.shutdown()
    machine.start()
    check_boot(first)
  '';
}
