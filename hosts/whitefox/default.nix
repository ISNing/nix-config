{
  config,
  lib,
  pkgs,
  mylib,
  myvars,
  disko,
  k8s-gitops,
  ...
}:
#############################################################
#
#  Whitefox - AMD64 Homelab Server (It's actually a whitebox, but I want to call it whitefox :P)
#
#############################################################
let
  hostName = "whitefox"; # Define your hostname.
  fluxImageFiles = mylib.genFluxImageFiles (
    {
      inherit pkgs;
      inherit k8s-gitops;
      fluxSource = k8s-gitops;
      fluxPath = "clusters/kubevirt-lab-1";
      compressAsZstd = true;
      zstdLevel = 10;
      # Only include images whose source chain contains flux-system/infra-controllers
      customFilter =
        entry:
        let
          sourceChains = entry.sourceChains or [ ];
          includeInfra = builtins.any (
            chain: builtins.any (source: lib.hasPrefix "infra-" source.name) chain
          ) sourceChains;
        in
        includeInfra;
    }
    // lib.optionalAttrs (myvars.mirrors ? registryMirrors) {
      registryMirrors = myvars.mirrors.registryMirrors;
    }
    // lib.optionalAttrs (myvars.mirrors ? mirrorRetries) {
      mirrorRetries = myvars.mirrors.mirrorRetries;
    }
  );

  coreModule = mylib.genKubeVirtHostModule {
    inherit pkgs hostName;
    inherit (myvars) networking;
  };
  k3sModule = mylib.genK3sServerModule {
    inherit pkgs;
    extraImageFiles = [
      config.services.k3s.package.airgap-images
      # Example:
      # /persist/k3s/images/my-app.tar
    ]
    ++ fluxImageFiles;

    kubeconfigFile = "/home/${myvars.username}/.kube/config";
    tokenFile = config.age.secrets."kubevirt-k3s-token".path;
    # the first node in the cluster should be the one to initialize the cluster
    clusterInit = true;
    # use my own domain & kube-vip's virtual IP for the API server
    # so that the API server can always be accessed even if some nodes are down
    masterHost = "kubevirt-cluster-1.isning.moe";
    kubeApiServerExtraArgs = [
      "--authentication-config=${./conf/apiserver-authn.yaml}"
    ];
    kubeletExtraArgs = [
      "--cpu-manager-policy=static"
      # https://kubernetes.io/docs/tasks/administer-cluster/reserve-compute-resources/
      # we have to reserve some resources for for system daemons running as pods or system services
      # when cpu-manager's static policy is enabled
      # the memory we reserved here is also for the kernel, since kernel's memory is not accounted in pods
      "--system-reserved=cpu=1,memory=2Gi,ephemeral-storage=2Gi"
    ];
    k3sExtraArgs = [
      # IPv4 Private CIDR(full) - 172.16.0.0/12
      # IPv4 Pod     CIDR(full) - fdfd:cafe:00:0000::/64 ~ fdfd:cafe:00:7fff::/64
      # IPv4 Service CIDR(full) - fdfd:cafe:00:8000::/64 ~ fdfd:cafe:00:ffff::/64
      "--cluster-cidr=172.16.0.0/16,fdfd:cafe:00:0001::/64"
      "--service-cidr=172.17.0.0/16,fdfd:cafe:00:8001::/112"
    ];
    nodeLabels = [
      "node-purpose=kubevirt"
    ];
    # Use cilium instead of flannel
    disableFlannel = true;
  };
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./graphics.nix
    ./preservation.nix
    ./secureboot.nix
    ./dns.nix
    ./tailscale.nix
    coreModule
    k3sModule
  ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
