# Build the macOS development client

This personal backend targets Apple Silicon macOS. It requires Qt 6.11, CMake, Conan and a local Apple Development signing identity. Build with `bash mx/build-helper.sh`; run isolated tests through `mx/tests/CMakeLists.txt`.

Packaging scripts in this directory audit dependencies, sign nested components and preserve the privileged helper's exact client-identity pin. Review them before using a signing identity. Use environment variables for local paths and identities; never commit certificates, private keys or provider profiles.

Apple Development signing is not Developer ID distribution or notarization. Do not disable OS security controls to install a build. Other-Mac installation is unverified.

Linux personal builds currently fail the backend-selection guard; no Linux .deb is available.
