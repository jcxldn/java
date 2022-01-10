import fetch from "node-fetch"
import yaml from "yaml"
import fs from "fs/promises"

const BASE_URL = "https://api.adoptopenjdk.net/v3/";
const getUrl = path => BASE_URL + path;


const archMappings = { arm64: "aarch64", armv7: "armv7", ppc64le: "ppc64le", s390x: "s390x", amd64: "amd64" };

const imageTypes = ["jdk", "jre"];

const osTypes = ["linux"];


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
        
        platforms[release] ? null : (platforms[release] = []); // Add empty array if needed to platforms[release]
        platforms[release].push(type);
    });
    console.log(platforms)


    // DEBUG
    platforms = {"16": ["jre"]}


    // Iterate through each java release (8, 11, 16, etc)
    Object.keys(platforms).forEach(async platform => {
        console.log(`Platform: Java ${platform}`)

        // 1. Query the API for assets for this release
        const res = await fetch(getUrl(`assets/latest/${platform}/hotspot`));
        const data = await res.json();

        //console.log(data)

        // 2.. Iterate through each variant (jre, jdk, jdk-slim)
        platforms[platform].forEach(variant => {
            console.log(`Variant: ${variant}`)

            // 1: Get list of arches for this variant
            const archStr = platformMatrix[`${platform}-${variant}`].arch
            const archArr = archStr.split(",")

            console.log(archArr)

            // Iterate through each arch
            archArr.forEach((arch) => {
                const adoptArch = dockerArchToAdoptArch(arch);
                console.log(`Arch: ${adoptArch} (${arch})`);

                // Find something
                const found = data.find((query) =>
                    findAsset(query, { architecture: adoptArch, image_type: variant })
                );

                console.log("FOUND DATA");
                console.log(found.binary.package.checksum)
                console.log(encodeURIComponent(found.release_name))
            })
        })
    })



/*
    const res = await fetch(getUrl("assets/latest/16/hotspot"));
    const json = await res.json();
    
    // Iterate through each binary
    json.forEach(binaryObj => {
        if (
            imageTypes.includes(binaryObj.binary.image_type) && // Ignore testimages
            osTypes.includes(binaryObj.binary.os) // Only get linux images
        ) {
            //console.log(binaryObj.binary)
        }
    })*/
})()