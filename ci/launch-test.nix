# Boots NixOS with an X session and launches Solo as a desktop user. Solo writes
# the startup receipt once the app is ready, its backend is healthy and the main
# window is visible. The test then waits for the window to actually paint, so a
# blank web view fails even when the receipt is written.
solo:
{
  name = "solo-launch";

  nodes.machine =
    { modulesPath, pkgs, ... }:
    {
      imports = [
        "${modulesPath}/../tests/common/user-account.nix"
        "${modulesPath}/../tests/common/x11.nix"
      ];
      test-support.displayManager.auto.user = "alice";
      hardware.graphics.enable = true;
      virtualisation.memorySize = 4096;
      virtualisation.resolution = {
        x = 1600;
        y = 1000;
      };
      environment.systemPackages = [
        solo
        pkgs.jq
        pkgs.imagemagick
      ];
    };

  testScript = ''
    def as_alice(cmd):
        return f"su - alice -c 'DISPLAY=:0 {cmd}'"

    machine.wait_for_x()
    machine.succeed("su - alice -c 'mkdir -p /tmp/solo-launch'")
    machine.succeed(as_alice(
        "SOLOTERM_STARTUP_RECEIPT=/tmp/solo-launch/startup.json "
        "SOLOTERM_STARTUP_NONCE=nixos-launch-test "
        "setsid -f Solo >/tmp/solo-launch/solo.log 2>&1"
    ))
    try:
        machine.wait_until_succeeds(
            "jq -e '.version == 1 and .nonce == \"nixos-launch-test\" "
            "and .app_ready == true and .backend_ready == true "
            "and .main_window_visible == true' /tmp/solo-launch/startup.json",
            timeout=180,
        )
        # The empty IceWM desktop is one color. Solo's UI has hundreds once it
        # paints, which takes a few seconds on a cold start without a GPU.
        machine.wait_until_succeeds(
            as_alice("test $(import -window root png:- | identify -format %k -) -gt 200"),
            timeout=60,
        )
    finally:
        print(machine.execute("cat /tmp/solo-launch/solo.log /tmp/solo-launch/startup.json")[1])
        machine.screenshot("solo")
    # The receipt's pid must still be Solo after it has painted.
    machine.succeed("kill -0 $(jq -r .pid /tmp/solo-launch/startup.json)")
  '';
}
