# Boots NixOS with an X session and launches Solo as a desktop user. Solo writes
# the startup receipt only once the app is ready, its backend is healthy and the
# main window is visible, so a blank or crashed web view fails the test.
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
      environment.systemPackages = [
        solo
        pkgs.jq
      ];
    };

  testScript = ''
    machine.wait_for_x()
    machine.succeed("su - alice -c 'mkdir -p /tmp/solo-launch'")
    machine.succeed(
        "su - alice -c 'DISPLAY=:0 "
        "SOLOTERM_STARTUP_RECEIPT=/tmp/solo-launch/startup.json "
        "SOLOTERM_STARTUP_NONCE=nixos-launch-test "
        "setsid -f Solo >/tmp/solo-launch/solo.log 2>&1'"
    )
    try:
        machine.wait_until_succeeds(
            "jq -e '.version == 1 and .nonce == \"nixos-launch-test\" "
            "and .app_ready == true and .backend_ready == true "
            "and .main_window_visible == true' /tmp/solo-launch/startup.json",
            timeout=180,
        )
    finally:
        print(machine.execute("cat /tmp/solo-launch/solo.log /tmp/solo-launch/startup.json")[1])
    # The receipt's pid must still be Solo a few seconds after app-ready.
    machine.sleep(3)
    machine.succeed("kill -0 $(jq -r .pid /tmp/solo-launch/startup.json)")
    machine.screenshot("solo")
  '';
}
