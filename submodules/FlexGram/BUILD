load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "FlexGram",
    module_name = "FlexGram",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    deps = [
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
        "//submodules/Display:Display",
        "//submodules/TelegramCore:TelegramCore",
        "//submodules/TelegramPresentationData:TelegramPresentationData",
        "//submodules/AccountContext:AccountContext",
        "//submodules/ComponentFlow:ComponentFlow",
        "//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/TelegramUI/Components/Gifts/GiftItemComponent:GiftItemComponent",
    ],
    visibility = ["//visibility:public"],
)
