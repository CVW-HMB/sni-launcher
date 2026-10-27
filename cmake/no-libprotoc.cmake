# Current vcpkg builds protoc only for the host triplet, so the static target triplet has no
# libprotoc. SNFM links it but never uses it; an empty target satisfies the link.
if(NOT TARGET protobuf::libprotoc)
    add_library(protobuf::libprotoc INTERFACE IMPORTED)
endif()
