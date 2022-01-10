import fetch from "node-fetch"
import yaml from "yaml"
import fs from "fs/promises"
import log from "npmlog"

log.addLevel('loop', 2250, { bold: true })

const API_VENDORS = {
    "adoptium": "https://api.adoptium.net/v3",
    "AdoptOpenJDK": "https://api.adoptopenjdk.net/v3"
}

const findAsset = (
  asset,
  { os = "linux", jvm_impl = "hotspot", heap_size="normal", architecture, image_type }
) => {
  //console.log(asset.binary);
    return asset.binary.jvm_impl == jvm_impl
        && asset.binary.os == os
        && asset.binary.heap_size == heap_size
        && asset.binary.architecture == architecture
        && asset.binary.image_type == image_type;
};

const dockerArchToAdoptArch = (arch) => {
    switch (arch) {
        case "linux/amd64":
            return "x64"
        case "linux/arm64":
            return "aarch64"
        case "linux/armhf":
            return "arm"
        case "linux/s390x":
            return "s390x"
    }
}


(async () => {
    // Main async loop

    // 1. Parse "platform-matrix.yml"
    const platformMatrix = yaml.parse(
      await fs.readFile("../../platform-matrix.yml", { encoding: "utf-8" })
    );
    //console.log(platformMatrix)

    
    let platforms = {};
    
    Object.keys(platformMatrix).forEach((platform) => {
        const split = platform.split("-");
        const release = split[0];
        const type = split.slice(1).join("-");
        // Get the GitHub org for this platform (string)
        const org = platformMatrix[platform].org;

        platforms[release] ? null : (platforms[release] = []); // Add empty array if needed to platforms[release]
        platforms[release][org] ? null : (platforms[release][org] = []); // Add empty array if needed to platforms[release]
        platforms[release][org].push(type);
    });
    //console.log(platforms)

    // Iterate through each java release (8, 11, 16, etc)
    for (const platform in platforms) {
        log.loop('platforms', `Found platform: ${platform}`)
    //Object.keys(platforms).forEach(platform => {

        // Iterate through each vendor (adoptopenjdk, adoptium)
        for (const vendor in platforms[platform]) {
        //vendors.forEach(async vendor => {
            log.loop('platforms.vendors',`Platform: Java ${platform} on ${vendor}`);
            const base_url = API_VENDORS[vendor]
            log.info('platforms.vendors', `Using API: ${base_url}`);

            // 1. Query the API for assets for this release
            const res = await fetch(`${base_url}/assets/latest/${platform}/hotspot`);
            const data = await res.json();

            //console.log(data)

          // 2.. Iterate through each variant (jre, jdk, jdk-slim)
          platforms[platform][vendor].forEach((variant) => {
            log.loop('platforms.vendors.variants', `Variant: ${variant}`);

            // 1: Get list of arches for this variant
            // Remove -slim suffix from the variant name
            const archStr = platformMatrix[`${platform}-${variant.split("-slim")[0]}`].arch;
            const archArr = archStr.split(",");

            log.verbose('platforms.vendors.variants.arch.list', archArr);

            // Iterate through each arch
            archArr.forEach((arch) => {
              const adoptArch = dockerArchToAdoptArch(arch);
              log.info('platforms.vendors.variants.arch', `Arch: ${adoptArch} (${arch})`);

              // Find something
              const found = data.find((query) =>
                findAsset(query, {
                  architecture: adoptArch,
                  image_type: variant.split("-slim")[0],
                })
              );

              //console.log("FOUND DATA");
              //console.log(found.binary.package.checksum);
              //console.log(encodeURIComponent(found.release_name));
            });
          });
        }
    }
})()