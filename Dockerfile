# JCX Matrix-Compatible Dockerfile

FROM alpine:3.15

# Set env variables for java to work properly
ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:$PATH" \
	GLIBC_VERSION="2.31-r1"

ARG ARM64_ESUM
ARG ARMV7_ESUM
ARG PPC64LE_ESUM
ARG S390X_ESUM
ARG AMD64_ESUM
ARG ORG
ARG REPO
ARG TYPE
ARG TAG
ARG VERSION
ARG SLIM
ARG JDK78FIX
ARG NEEDSJLINK



RUN mkdir -p /lib /lib64 /usr/glibc-compat/lib/locale /usr/glibc-compat/lib64 /etc; \
	apk add --no-cache --virtual .fetch-deps curl binutils; \
		ARCH="$(apk --print-arch)"; \
		case "${ARCH}" in \
		aarch64|arm64) \
			ESUM=$ARM64_ESUM; \
			BINARY_URL="https://github.com/${ORG}/${REPO}/releases/download/${TAG}/${TYPE}_aarch64_linux_hotspot_${VERSION}.tar.gz"; \
			ZLIB_URL='http://ports.ubuntu.com/ubuntu-ports/pool/main/z/zlib/zlib1g_1.2.11.dfsg-2ubuntu1_arm64.deb'; \
			GLIBC_ARCH='aarch64'; \
			glibc_setup () { \
				ln -s /usr/glibc-compat/lib/ld-linux-aarch64.so.1 /lib/ld-linux-aarch64.so.1; \
				ln -s /usr/glibc-compat/lib/ld-linux-aarch64.so.1 /lib64/ld-linux-aarch64.so.1; \
				ln -s /usr/glibc-compat/lib/ld-linux-aarch64.so.1 /usr/glibc-compat/lib64/ld-linux-aarch64.so.1; \
				ln -s /usr/glibc-compat/etc/ld.so.cache /etc/ld.so.cache; \
				# ln -sfn /lib/libc.musl-x86_64.so.1 /usr/glibc-compat/lib; \
			}; \
			;; \
			# Download glibc and link
		armhf|armv7l|armv7) \
			ESUM=$ARMV7_ESUM; \
			BINARY_URL="https://github.com/${ORG}/${REPO}/releases/download/${TAG}/${TYPE}_arm_linux_hotspot_${VERSION}.tar.gz"; \
			ZLIB_URL='http://ports.ubuntu.com/ubuntu-ports/pool/main/z/zlib/zlib1g_1.2.11.dfsg-2ubuntu1_armhf.deb'; \
			# Override GLIBC Version - since 2.28 there is a bug blocking it being used on QEMU
			# https://bugs.launchpad.net/qemu/+bug/1805913
			GLIBC_VERSION="2.27-r1"; \
			GLIBC_ARCH='arm-linux-gnueabihf'; \
			glibc_setup () { \
				ln -s /usr/glibc-compat/lib/ld-linux-armhf.so.3 /lib/ld-linux-armhf.so.3; \
				ln -s /usr/glibc-compat/lib/ld-linux-armhf.so.3 /lib64/ld-linux-armhf.so.3; \
				ln -s /usr/glibc-compat/lib/ld-linux-armhf.so.3 /usr/glibc-compat/lib64/ld-linux-armhf.so.3; \
				ln -s /usr/glibc-compat/etc/ld.so.cache /etc/ld.so.cache; \
                # Set an env variable to trigger the java78fix function
                if [ "$JDK78FIX" = "yes" ]; then DOJDK78FIX="yes"; fi; \
            }; \
            java78fix () { \
                # Download stuff
                echo "[OpenJDK 7/8] Linking libffi, libgcc to fix build..."; \
                # Link musl
				ln -sfn /lib/libc.musl-armv7.so.1 /usr/glibc-compat/lib; \
				# OpenJDK 7 + 8 | s390x, armv7 - install libffi, libgcc
				apk add --no-cache libffi libgcc; \
				ln -s /usr/lib/libffi.so.8 /usr/lib/libffi.so.6; \
				ln -s /usr/lib/libffi.so.8 /usr/lib/libffi.so.7; \
				ln -s /usr/lib/libffi.so.8 /usr/glibc-compat/lib/libffi.so.6; \
				ln -s /usr/lib/libgcc_s.so.1 /usr/glibc-compat/lib/libgcc_s.so.1; \
                echo "[OpenJDK 7/8] Done!"; \
			}; \
			;; \
		ppc64el|ppc64le) \
			ESUM=$PPC64LE_ESUM; \
			BINARY_URL="https://github.com/${ORG}/${REPO}/releases/download/${TAG}/${TYPE}_ppc64le_linux_hotspot_${VERSION}.tar.gz"; \
			ZLIB_URL='http://ports.ubuntu.com/ubuntu-ports/pool/main/z/zlib/zlib1g_1.2.11.dfsg-2ubuntu1_ppc64el.deb'; \
			GLIBC_ARCH='ppc64le'; \
			glibc_setup () { \
				ln -s /usr/glibc-compat/lib/ld-linux-powerpc64le.so.2 /lib/ld-linux-powerpc64le.so.2; \
				ln -s /usr/glibc-compat/lib/ld-linux-powerpc64le.so.2 /lib64/ld-linux-powerpc64le.so.2; \
				ln -s /usr/glibc-compat/lib/ld-linux-powerpc64le.so.2 /usr/glibc-compat/lib64/ld-linux-powerpc64le.so.2; \
				ln -s /usr/glibc-compat/etc/ld.so.cache /etc/ld.so.cache; \
				# ln -sfn /lib/libc.musl-x86_64.so.1 /usr/glibc-compat/lib; \
				# Special case for ppc64le.
				ln -s /usr/glibc-compat/lib/ld64.so.2 /lib/ld64.so.2; \
				ln -s /usr/glibc-compat/lib/ld64.so.2 /lib64/ld64.so.2; \
			}; \
			;; \
		s390x) \
			ESUM=$S390X_ESUM; \
			BINARY_URL="https://github.com/${ORG}/${REPO}/releases/download/${TAG}/${TYPE}_s390x_linux_hotspot_${VERSION}.tar.gz"; \
			ZLIB_URL='http://ports.ubuntu.com/ubuntu-ports/pool/main/z/zlib/zlib1g_1.2.11.dfsg-2ubuntu1_s390x.deb'; \
			GLIBC_ARCH='s390x'; \
			glibc_setup () { \
				ln -s /usr/glibc-compat/lib/ld-linux-s390x.so.2 /lib/ld-linux-s390x.so.2; \
				ln -s /usr/glibc-compat/lib/ld-linux-s390x.so.2 /lib64/ld-linux-s390x.so.2; \
				ln -s /usr/glibc-compat/lib/ld-linux-s390x.so.2/usr/glibc-compat/lib64/ld-linux-s390x.so.2; \
				ln -s /usr/glibc-compat/etc/ld.so.cache /etc/ld.so.cache; \
				# ln -sfn /lib/libc.musl-x86_64.so.1 /usr/glibc-compat/lib; \
				# Special case for s390x.
				ln -s /usr/glibc-compat/lib/ld64.so.1 /lib/ld64.so.1; \
				ln -s /usr/glibc-compat/lib/ld64.so.1 /lib64/ld64.so.1; \
                # Set an env variable to trigger the java78fix function
                if [ "$JDK78FIX" = "yes" ]; then DOJDK78FIX="yes"; fi; \
            }; \
            java78fix () { \
                # Download stuff
                echo "[OpenJDK 7/8] Linking libffi, libgcc to fix build..."; \
                # Link musl
				ln -sfn /lib/libc.musl-s390x.so.1 /usr/glibc-compat/lib; \
				# OpenJDK 7 + 8 | s390x, armv7 - install libffi, libgcc
				apk add --no-cache libffi libgcc; \
				ln -s /usr/lib/libffi.so.8 /usr/lib/libffi.so.6; \
				ln -s /usr/lib/libffi.so.8 /usr/lib/libffi.so.7; \
				ln -s /usr/lib/libffi.so.8 /usr/glibc-compat/lib/libffi.so.6; \
				ln -s /usr/lib/libgcc_s.so.1 /usr/glibc-compat/lib/libgcc_s.so.1; \
                echo "[OpenJDK 7/8] Done!"; \
			}; \
			;; \
		amd64|x86_64) \
			ESUM=$AMD64_ESUM; \
			BINARY_URL="https://github.com/${ORG}/${REPO}/releases/download/${TAG}/${TYPE}_x64_linux_hotspot_${VERSION}.tar.gz"; \
			ZLIB_URL='http://archive.ubuntu.com/ubuntu/pool/main/z/zlib/zlib1g_1.2.11.dfsg-2ubuntu1_amd64.deb'; \
			GLIBC_ARCH='x86_64'; \
			glibc_setup () { \
				ln -s /usr/glibc-compat/lib/ld-linux-x86-64.so.2 /lib/ld-linux-x86-64.so.2; \
				ln -s /usr/glibc-compat/lib/ld-linux-x86-64.so.2 /lib64/ld-linux-x86-64.so.2; \
				ln -s /usr/glibc-compat/lib/ld-linux-x86-64.so.2 /usr/glibc-compat/lib64/ld-linux-x86-64.so.2; \
				ln -s /usr/glibc-compat/etc/ld.so.cache /etc/ld.so.cache; \
				ln -sfn /lib/libc.musl-x86_64.so.1 /usr/glibc-compat/lib; \
			}; \
			;; \
		*) \
			echo "Unsupported arch: ${ARCH}"; \
			exit 1; \
			;; \
		esac; \
		# Download glibc from repo
		wget -O- https://github.com/Prouser123/docker-glibc-multiarch-builder/releases/download/jcx-${GLIBC_VERSION}/glibc-bin-${GLIBC_VERSION}-${GLIBC_ARCH}.tar.gz | tar zxvf - -C /; \
		# Link glibc
		glibc_setup; \
        
        # Java 7/8 Fix (see above)
        if [ "$DOJDK78FIX" = "yes" ]; then java78fix; fi; \
		
		# Download additional files
		wget https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/ld.so.conf -O /usr/glibc-compat/etc/ld.so.conf; \
	wget https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/nsswitch.conf -O /etc/nsswitch.conf; \
		
		# Download OpenJDK
        echo "Downloading OpenJDK with URL: $BINARY_URL"; \
		curl -LfsSo /tmp/openjdk.tar.gz $BINARY_URL; \
        echo "Verifing download with checksum: $ESUM"; \
		echo "${ESUM} */tmp/openjdk.tar.gz" | sha256sum -c -; \
		mkdir -p /opt/java/openjdk; \
		cd /opt/java/openjdk; \
		tar -xf /tmp/openjdk.tar.gz --strip-components=1; \
		
		# Download zlib
		mkdir -p /tmp/zlib; \
		cd /tmp/zlib; \
		wget -O zlib.deb ${ZLIB_URL}; \
		ar vx zlib.deb; \
		tar xvf data.tar.xz; \
		mv lib/$(ls lib)/* /usr/glibc-compat/lib/; \

		# ---------- NEEDSJLINK START ----------
		# $NEEDSJLINK
		# Some images (namely Termurin 16) do not have a JRE, so we need to run jlink to generate one
		# You may recall that Temurin / Adoptium were due to stop making JRE builds, but this was reverted.
		# See platform-matrix-header.txt for details.
		if [ "$NEEDSJLINK" = "yes" ]; \
		then \
		echo "[jlink] Building... (with set -x)"; \
		set -x; \
		# We are going to try to recreate the 'legacy' JRE builds that Adoptium create.
		# https://blog.adoptium.net/2021/10/jlink-to-produce-own-runtime/#:~:text=shown%20in%20the-,following%20command%3A,-jdk%2D17%2B35
		# Excluding: 
		# - jdk.internal.vm.ci (not available on all platforms)
		# - jdk.internal.vm.compiler (not found - not present in upstream build?)
		#   - jdk.internal.vm.compiler.management
		_JAVA_OPTIONS="-Djdk.lang.Process.launchMechanism=vfork" jlink --add-modules java.base,java.compiler,java.datatransfer,java.desktop,java.instrument,java.logging,java.management,java.management.rmi,java.naming,java.net.http,java.prefs,java.rmi,java.scripting,java.se,java.security.jgss,java.security.sasl,java.smartcardio,java.sql,java.sql.rowset,java.transaction.xa,java.xml,java.xml.crypto,jdk.accessibility,jdk.charsets,jdk.crypto.cryptoki,jdk.crypto.ec,jdk.dynalink,jdk.httpserver,jdk.incubator.foreign,jdk.incubator.vector,jdk.jdwp.agent,jdk.jfr,jdk.jsobject,jdk.localedata,jdk.management,jdk.management.agent,jdk.management.jfr,jdk.naming.dns,jdk.naming.rmi,jdk.net,jdk.nio.mapmode,jdk.sctp,jdk.security.auth,jdk.security.jgss,jdk.unsupported,jdk.xml.dom,jdk.zipfs \
			  --output /opt/java/openjdk-jre \
			  --strip-debug \
			  --no-man-pages \
			  --no-header-files \
			  --compress=2; \
		
		# Now we delete the old (jdk) and replace it with the new JRE equivalent.
		rm -rf /opt/java/openjdk/; \
		mv /opt/java/openjdk-jre /opt/java/openjdk; \
		set +x; \
		fi; \
		# ---------- NEEDSJLINK END -------
		
		# Run strip on stuff
		strip /usr/glibc-compat/sbin/**; \
		strip /usr/glibc-compat/lib64/**; \
		strip /usr/glibc-compat/lib/** || echo 'Probably done with errors'; \
		strip /usr/glibc-compat/lib/*/* || echo 'Probably done with errors'; \
		
		# Remove unused files (https://github.com/sgerrand/alpine-pkg-glibc/blob/master/APKBUILD)
		rm "$pkgdir"/usr/glibc-compat/etc/rpc; \
		rm -rf /usr/glibc-compat/bin; \
		rm -rf /usr/glibc-compat/sbin; \
		rm -rf /usr/glibc-compat/lib/gconv; \
		rm -rf /usr/glibc-compat/lib/getconf; \
		rm -rf /usr/glibc-compat/lib/audit; \
		rm -rf /usr/glibc-compat/share; \
		rm -rf /usr/glibc-compat/var; \
		
		# Remove object files and static libraries. (https://blog.gilliard.lol/2018/11/05/alpine-jdk11-images.html)
		rm -rf /usr/glibc-compat/*.o; \
		rm -rf /usr/glibc-compat/*.a; \
		rm -rf /usr/glibc-compat/*/*.o; \
		rm -rf /usr/glibc-compat/*/*.a; \
		
		# Cleaning up...
		apk del --purge .fetch-deps; \
		rm -rf /var/cache/apk/*; \
		rm -rf /tmp/openjdk.tar.gz; \
		rm -rf /tmp/zlib; \
		echo "Done!"; \
		cd /; \
		java -version;