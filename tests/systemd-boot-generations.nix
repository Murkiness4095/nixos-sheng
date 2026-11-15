{
  name = "sheng-systemd-boot-generations";
  node.pkgsReadOnly = false;
  defaults = {
    nixpkgs.overlays = [ (import ../modules/systemd-boot-mixed-generations.nix) ];
    virtualisation.useBootLoader = true;
    virtualisation.useEFIBoot = true;
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = false;
    system.switch.enable = true;
    nix.enable = true;
    environment.etc."machine-id".text = "1234567890abcdef1234567890abcdef\n";
  };
  nodes = {
    machine = { nodes, pkgs, ... }: {
      system.extraDependencies = [ nodes.candidate.system.build.toplevel ];
      environment.systemPackages = [ pkgs.jq ];
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
    # A historical generation with the BootSpec shape emitted without an initrd.
    machine.succeed(f"mkdir -p /var/lib/legacy-bootspec; jq 'del(.\"org.nixos.bootspec.v1\".initrd)' {first}/boot.json >/var/lib/legacy-bootspec/boot.json")
    machine.succeed(f"ln -s /var/lib/legacy-bootspec {profile}-0-link")
    machine.succeed(f"nix-env -p {profile} --set {second}")
    machine.succeed(f"{second}/bin/switch-to-configuration boot")
    machine.shutdown()
    machine.start()
    check_boot(second)
    machine.succeed(f"nix-env -p {profile} --rollback")
    machine.succeed(f"readlink {profile}-0-link | grep -Fx /var/lib/legacy-bootspec")
    machine.succeed(f"{first}/bin/switch-to-configuration boot")
    machine.shutdown()
    machine.start()
    check_boot(first)
  '';
}
