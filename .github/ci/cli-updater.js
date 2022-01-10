import fetch from "node-fetch"
import yaml from "yaml"
import fs from "fs/promises"
import log from "npmlog"
import merge from "lodash/merge.js"

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
    const output = {}

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

              // Determine image type
              let image_type = undefined
              if (vendor == "AdoptOpenJDK") {
                image_type = variant.split("-slim")[0]
              } else if (vendor == "adoptium") {
                image_type = "jdk" // adoptium does not build a JRE.
              }

              // Find something
              const found = data.find((query) =>
                findAsset(query, {
                  architecture: adoptArch,
                  image_type,
                })
                );
                
                const key = `${platform}-${variant}`
                if (!output[key]) output[key] = {}
                if (!output[key]["esums"]) output[key]["esums"] = {}
              
                // Set esum (checksum) for each platform
                output[key]["esums"][(arch.split("/")[1]).replace("armhf", "armv7")] = found.binary.package.checksum

                // Set tag
                const tag = encodeURIComponent(found.release_name)
                // Make sure we aren't overwriting an already set tag with other data
                if (output[key].tag != undefined && output[key].tag != tag) {
                    log.error("tag mismatch detected!")
                    console.log(tag)
                    process.exit(1)
                }
                output[key].tag = tag
                
                // Get version (from download url)
                const version = found.binary.package.name.split("hotspot_")[1].split(".tar.gz")[0]

                // Set version
                // Make sure we aren't overwriting anything
                if (output[key].version != undefined && output[key].version != version) {
                    log.error("version mismatch detected!")
                    process.exit(2)
                }

                output[key].version = version
            });
          });
        }
    }
    // Merge the data from the original yml file and our new data.
    const mergedData = merge(platformMatrix, output);
    // Done! Let's write the output object back to the yml file
    //console.log(JSON.stringify(mergedData))
    console.log(yaml.stringify(mergedData))

    const header = await fs.readFile("../../platform-matrix-header.txt", { encoding: "utf-8" })
    // Overwrite the yml file with new data
    await fs.writeFile("../../platform-matrix.yml", header + yaml.stringify(mergedData))
    
})()