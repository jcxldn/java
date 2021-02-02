# JCX Matrix-Compatible Dockerfile

FROM alpine:3.12

# Set env variables for java to work properly
ENV JAVA_HOME=/opt/java/openjdk \
    PATH="/opt/java/openjdk/bin:$PATH" \
	GLIBC_VERSION="2.31-r1"



RUN mkdir -p /lib /lib64 /usr/glibc-compat/lib/locale /usr/glibc-compat/lib64 /etc; \
	apk add --no-cache --virtual .fetch-deps curl binutils; \
		ARCH="$(apk --print-arch)"; \
		case "${ARCH}" in \
		aarch64|arm64) \
			ESUM=AARCH64_ESUM; \
			BINARY_URL='https://github.com/AdoptOpenJDK/$REPO/releases/download/$TAG/$TYPE_aarch64_linux_hotspot_$VERSION.tar.gz'; \
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
			ESUM=ARMV7_ESUM; \
			BINARY_URL='https://github.com/AdoptOpenJDK/$REPO/releases/download/$TAG/$TYPE_arm_linux_hotspot_$VERSION.tar.gz'; \
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
				# ln -sfn /lib/libc.musl-x86_64.so.1 /usr/glibc-compat/lib; \
                # ---------- JAVA 7/8 START ----------
                if [ "$JDK78FIX" = "yes" ]; \
                then \
                # Download stuff
                echo "[OpenJDK 7/8] Linking libffi, libgcc to fix build..." \
                # Link musl
				ln -sfn /lib/libc.musl-armv7.so.1 /usr/glibc-compat/lib; \
				# OpenJDK 7 + 8 | s390x, armv7 - install libffi, libgcc
				apk add --no-cache libffi libgcc; \
				ln -s /usr/lib/libffi.so.7 /usr/lib/libffi.so.6; \
				ln -s /usr/lib/libffi.so.6 /usr/glibc-compat/lib/libffi.so.6; \
				ln -s /usr/lib/libgcc_s.so.1 /usr/glibc-compat/lib/libgcc_s.so.1; \
                echo "[OpenJDK 7/8] Done!"
                fi; \
                # ---------- JAVA 7/8 END ----------
			}; \
			;; \
		ppc64el|ppc64le) \
			ESUM=PPC64LE_ESUM; \
			BINARY_URL='https://github.com/AdoptOpenJDK/$REPO/releases/download/$TAG/$TYPE_ppc64le_linux_hotspot_$VERSION.tar.gz'; \
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
			ESUM=S390X_ESUM; \
			BINARY_URL='https://github.com/AdoptOpenJDK/$REPO/releases/download/$TAG/$TYPE_s390x_linux_hotspot_$VERSION.tar.gz'; \
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
                # ---------- JAVA 7/8 START ----------
                if [ "$JDK78FIX" = "yes" ]; \
                then \
                # Download stuff
                echo "[OpenJDK 7/8] Linking libffi, libgcc to fix build..." \
                # Link musl
				ln -sfn /lib/libc.musl-s390x.so.1 /usr/glibc-compat/lib; \
				# OpenJDK 7 + 8 | s390x, armv7 - install libffi, libgcc
				apk add --no-cache libffi libgcc; \
				ln -s /usr/lib/libffi.so.7 /usr/lib/libffi.so.6; \
				ln -s /usr/lib/libffi.so.6 /usr/glibc-compat/lib/libffi.so.6; \
				ln -s /usr/lib/libgcc_s.so.1 /usr/glibc-compat/lib/libgcc_s.so.1; \
                echo "[OpenJDK 7/8] Done!"
                fi; \
                # ---------- JAVA 7/8 END ----------
			}; \
			;; \
		amd64|x86_64) \
			ESUM=AMD64_ESUM; \
			BINARY_URL='https://github.com/AdoptOpenJDK/$REPO/releases/download/$TAG/$TYPE_x64_linux_hotspot_$VERSION.tar.gz'; \
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
		
		# Download additional files
		wget https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/ld.so.conf -O /usr/glibc-compat/etc/ld.so.conf; \
	wget https://raw.githubusercontent.com/sgerrand/alpine-pkg-glibc/master/nsswitch.conf -O /etc/nsswitch.conf; \
		
		# Download OpenJDK
		curl -LfsSo /tmp/openjdk.tar.gz ${BINARY_URL}; \
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

        # ---------- STRIP START ----------
		# OpenJDK - Slim Java
        if [ "$SLIM" = "yes" ]; \
        then \
        # Download stuff
        echo "[Java Slim Build] Downloading..." \
        wget https://raw.githubusercontent.com/Prouser123/openjdk-alpine-docker/master/slim-java-14/slim-java.sh \
        wget https://raw.githubusercontent.com/Prouser123/openjdk-alpine-docker/master/slim-java-14/slim-java_bin_del.list \
        wget https://raw.githubusercontent.com/Prouser123/openjdk-alpine-docker/master/slim-java-14/slim-java_jmod_del.list \
        wget https://raw.githubusercontent.com/Prouser123/openjdk-alpine-docker/master/slim-java-14/slim-java_lib_del.list \
        wget https://raw.githubusercontent.com/Prouser123/openjdk-alpine-docker/master/slim-java-14/slim-java_lib_del.list \
        wget https://raw.githubusercontent.com/Prouser123/openjdk-alpine-docker/master/slim-java-14/slim-java_rtjar_keep.list \
		# Strip java
        echo "[Java Slim Build] Stripping..." \
        chmod +x /usr/local/bin/slim-java.sh; \
		apk add --no-cache --virtual .build-deps bash binutils; \
		/usr/local/bin/slim-java.sh /opt/java/openjdk/; \
		apk del --purge .build-deps; \
        fi; \
        # ---------- STRIP END   ----------
		
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