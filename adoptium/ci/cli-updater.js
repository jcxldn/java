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
    return asset.binary.jvm_impl == jvm_impl
        && asset.binary.os == os
        && asset.binary.heap_size == heap_size
        && asset.binary.architecture == architecture
        && asset.binary.image_type == image_type.replace("-adoptium-glibc", "").replace("-adoptium-musl", "") ;
};

const dockerArchToAdoptArch = (arch) => {
    switch (arch) {
        case "linux/amd64":
            return "x64"
        case "linux/arm64":
            return "aarch64"
        case "linux/armhf":
          return "arm"
        case "linux/ppc64le":
          return "ppc64le"
        case "linux/riscv64":
          return "riscv64"
        case "linux/s390x":
            return "s390x"
    }
}

(async () => {
    // Main async loop
    const output = {}

    // 1. Parse "platform-matrix.yml"
    const platformMatrix = yaml.parse(
      await fs.readFile("../platform-matrix-template.yml", { encoding: "utf-8" })
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
          
          debugger;

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
              
              let image_type = variant.split("-slim")[0]

              // Although the decision to stop building JREs has been reversed,
              //Java 16 builds (being EoL) do not have a JRE.
              let hasJre = true;
              if (vendor == "adoptium" && platform == "16") {
                log.warn("edgecase", "Termurin 16 does not have a JRE! Using jdk for image_type...");
                image_type = "jdk"
                hasJre = false;
              }

              // Find something
              const found = data.find((query) =>
                  findAsset(query, {
                    os: image_type.includes("musl") ? "alpine-linux" : "linux",
                  architecture: adoptArch,
                  image_type,
                })
              );
              
              // Now we can update the values
              const key = `${platform}-${variant}`;
              if (platformMatrix[key]["updater-ignore"]) {
                log.warn("platforms.vendors.variants.arch", `Platform ${key} has updater-ignore set. Moving to next item in the loop...`);
                return; // Since we're in a forEach loop, return is functionally equivalent to continue; in a for loop.
              }
                if (!output[key]) output[key] = {}
                if (!output[key]["esums"]) output[key]["esums"] = {}
                
                // If this variant does not have a JRE, set a flag in the yml
                // to instruct the builder to run jlink and create a JRE.
                // (See above definition for more details)
                output[key]["needs-jlink"] = (!hasJre) && (variant == "jre") ? "yes" : "no"
              
                // Set esum (checksum) for each platform
                output[key]["esums"][(arch.split("/")[1]).replace("armhf", "armv7")] = found.binary.package.checksum

                // Set tag
                const tag = encodeURIComponent(found.release_name)
                // Make sure we aren't overwriting an already set tag with other data
              if (output[key].tag != undefined && output[key].tag != tag) {
                debugger;
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

    const header = await fs.readFile("../platform-matrix-header.txt", { encoding: "utf-8" })
    // Overwrite the yml file with new data
    await fs.writeFile("../platform-matrix.yml", header + yaml.stringify(mergedData))
    
})()
