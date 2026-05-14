_: {
  registryMirrors = {
    "docker.io" = [
      "dockerproxy.net"
      "docker.1ms.run"
    ];
    "ghcr.io" = [
      "ghcr.dockerproxy.net"
      "ghcr.nju.edu.cn"
    ];
    "quay.io" = [
      "quay.dockerproxy.net"
      "quay.nju.edu.cn"
    ];
  };

  mirrorRetries = 3;

}
