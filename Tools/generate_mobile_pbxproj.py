#!/usr/bin/env python3
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_DIR = os.path.join(ROOT, "SalmanCleanerMobile")
TEST_DIR = os.path.join(ROOT, "SalmanCleanerMobileTests")
PROJECT_DIR = os.path.join(ROOT, "SalmanCleanerMobile.xcodeproj")
PBXPROJ = os.path.join(PROJECT_DIR, "project.pbxproj")

PROJECT_ID = "600000000000000000000001"
APP_TARGET_ID = "600000000000000000000002"
TEST_TARGET_ID = "600000000000000000000003"

IGNORE_DIRS = {"en.lproj", "Assets.xcassets", "xcuserdata"}
RESOURCE_FILES = {"Assets.xcassets"}

def next_id(counter: list) -> str:
    counter[0] += 1
    return f"EE{counter[0]:024d}"

def collect_swift_files() -> tuple[list[str], list[str]]:
    app_files: list[str] = []
    test_files: list[str] = []
    for base, out in ((APP_DIR, app_files), (TEST_DIR, test_files)):
        if os.path.exists(base):
            for dirpath, dirnames, filenames in os.walk(base):
                dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS]
                for name in sorted(filenames):
                    if name.endswith(".swift"):
                        rel = os.path.relpath(os.path.join(dirpath, name), ROOT)
                        out.append(rel.replace("\\", "/"))
    return app_files, test_files

def build_pbxproj(app_files: list[str], test_files: list[str]) -> str:
    counter = [0]
    file_refs: dict[str, str] = {}
    build_files: dict[str, str] = {}
    groups: dict[str, str] = {}

    fr_entries: list[str] = []
    bf_entries: list[str] = []
    for rel in app_files + test_files:
        fr = next_id(counter)
        bf = next_id(counter)
        file_refs[rel] = fr
        build_files[rel] = bf
        fr_entries.append(f'\t\t{fr} /* {os.path.basename(rel)} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {os.path.basename(rel)}; sourceTree = "<group>"; }};')
        bf_entries.append(f'\t\t{bf} /* {os.path.basename(rel)} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr} /* {os.path.basename(rel)} */; }};')

    assets_fr = next_id(counter)
    assets_bf = next_id(counter)
    fr_entries.append(f'\t\t{assets_fr} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};')
    bf_entries.append(f'\t\t{assets_bf} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {assets_fr} /* Assets.xcassets */; }};')

    plist_fr = next_id(counter)
    entitlements_fr = next_id(counter)
    fr_entries.append(f'\t\t{plist_fr} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};')
    fr_entries.append(f'\t\t{entitlements_fr} /* SalmanCleanerMobile.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = SalmanCleanerMobile.entitlements; sourceTree = "<group>"; }};')

    app_product_fr = next_id(counter)
    test_product_fr = next_id(counter)
    fr_entries.append(f'\t\t{app_product_fr} /* SalmanCleanerMobile.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = SalmanCleanerMobile.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
    fr_entries.append(f'\t\t{test_product_fr} /* SalmanCleanerMobileTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = SalmanCleanerMobileTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};')

    def group_id(key: str) -> str:
        if key not in groups:
            groups[key] = next_id(counter)
        return groups[key]

    def group_children(rel_dir: str) -> list[str]:
        children: list[str] = []
        subdirs: dict[str, str] = {}
        for rel in app_files + test_files:
            if not rel.startswith(rel_dir):
                continue
            rest = rel[len(rel_dir):].lstrip("/")
            if "/" in rest:
                sub = rest.split("/")[0]
                subdirs.setdefault(sub, group_id(rel_dir.rstrip("/") + "/" + sub))
            else:
                children.append(f'{file_refs[rel]} /* {os.path.basename(rel)} */')
        for sub, gid in sorted(subdirs.items()):
            children.append(f'{gid} /* {sub} */')
        return children

    def group_entry(key: str, name: str, path: str, children: list[str]) -> str:
        gid = group_id(key)
        child_lines = "\n".join(f"\t\t\t\t{child}," for child in children)
        path_str = f"\t\t\tpath = {path};\n" if path else ""
        return f"\t\t{gid} /* {name} */ = {{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = (\n{child_lines}\n\t\t\t);\n{path_str}\t\t\tsourceTree = \"<group>\";\n\t\t}};"

    root_gid = next_id(counter)
    app_group_gid = group_id("SalmanCleanerMobile")
    test_group_gid = group_id("SalmanCleanerMobileTests")
    products_gid = group_id("Products")

    subgroup_entries: list[str] = []
    subdir_set = set()
    for rel in app_files + test_files:
        parts = rel.split("/")
        for depth in range(2, len(parts)):
            subdir_set.add("/".join(parts[:depth]))
    for sub in sorted(subdir_set):
        name = sub.split("/")[-1]
        children = group_children(sub + "/")
        subgroup_entries.append(group_entry(sub, name, name, children))

    app_children: list[str] = []
    for rel in app_files:
        parts = rel.split("/")
        if len(parts) == 2:
            app_children.append(f'{file_refs[rel]} /* {os.path.basename(rel)} */')
    app_children.append(f'{plist_fr} /* Info.plist */')
    app_children.append(f'{entitlements_fr} /* SalmanCleanerMobile.entitlements */')
    app_children.append(f'{assets_fr} /* Assets.xcassets */')
    for sub in sorted(subdir_set):
        if sub.count("/") == 1 and sub.startswith("SalmanCleanerMobile/"):
            app_children.append(f'{group_id(sub)} /* {sub.split("/")[-1]} */')

    test_children: list[str] = []
    for rel in test_files:
        parts = rel.split("/")
        if len(parts) == 2:
            test_children.append(f'{file_refs[rel]} /* {os.path.basename(rel)} */')
    for sub in sorted(subdir_set):
        if sub.count("/") == 1 and sub.startswith("SalmanCleanerMobileTests/"):
            test_children.append(f'{group_id(sub)} /* {sub.split("/")[-1]} */')

    group_entries = [
        group_entry("SalmanCleanerMobile", "SalmanCleanerMobile", "SalmanCleanerMobile", app_children),
        group_entry("SalmanCleanerMobileTests", "SalmanCleanerMobileTests", "SalmanCleanerMobileTests", test_children),
        group_entry("Products", "Products", None, [f'{app_product_fr} /* SalmanCleanerMobile.app */', f'{test_product_fr} /* SalmanCleanerMobileTests.xctest */']),
    ]
    group_entries[2] = group_entries[2].replace(
        'sourceTree = "<group>";', 'name = Products;\n\t\t\tsourceTree = "<group>";'
    )
    group_entries.extend(subgroup_entries)

    app_sources = "\n".join(f'\t\t\t\t{build_files[rel]} /* {os.path.basename(rel)} in Sources */,' for rel in app_files)
    test_sources = "\n".join(f'\t\t\t\t{build_files[rel]} /* {os.path.basename(rel)} in Sources */,' for rel in test_files)

    pbx = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(bf_entries)}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		200000000000000000000001 /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {PROJECT_ID} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {APP_TARGET_ID};
			remoteInfo = SalmanCleanerMobile;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
{chr(10).join(fr_entries)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		500000000000000000000001 /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		500000000000000000000002 /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{root_gid} = {{
			isa = PBXGroup;
			children = (
				{app_group_gid} /* SalmanCleanerMobile */,
				{test_group_gid} /* SalmanCleanerMobileTests */,
				{products_gid} /* Products */,
			);
			sourceTree = "<group>";
		}};
{chr(10).join(group_entries)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{APP_TARGET_ID} /* SalmanCleanerMobile */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = 800000000000000000000002 /* Build configuration list for PBXNativeTarget "SalmanCleanerMobile" */;
			buildPhases = (
				500000000000000000000003 /* Sources */,
				500000000000000000000001 /* Frameworks */,
				500000000000000000000005 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = SalmanCleanerMobile;
			productName = SalmanCleanerMobile;
			productReference = {app_product_fr} /* SalmanCleanerMobile.app */;
			productType = "com.apple.product-type.application";
		}};
		{TEST_TARGET_ID} /* SalmanCleanerMobileTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = 800000000000000000000003 /* Build configuration list for PBXNativeTarget "SalmanCleanerMobileTests" */;
			buildPhases = (
				500000000000000000000004 /* Sources */,
				500000000000000000000002 /* Frameworks */,
				500000000000000000000006 /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				700000000000000000000001 /* PBXTargetDependency */,
			);
			name = SalmanCleanerMobileTests;
			productName = SalmanCleanerMobileTests;
			productReference = {test_product_fr} /* SalmanCleanerMobileTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{PROJECT_ID} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{APP_TARGET_ID} = {{
						CreatedOnToolsVersion = 15.0;
					}};
					{TEST_TARGET_ID} = {{
						CreatedOnToolsVersion = 15.0;
						TestTargetID = {APP_TARGET_ID};
					}};
				}};
			}};
			buildConfigurationList = 800000000000000000000001 /* Build configuration list for PBXProject "SalmanCleanerMobile" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {root_gid};
			productRefGroup = {products_gid} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{APP_TARGET_ID} /* SalmanCleanerMobile */,
				{TEST_TARGET_ID} /* SalmanCleanerMobileTests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		500000000000000000000005 /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{assets_bf} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		500000000000000000000006 /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		500000000000000000000003 /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{app_sources}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		500000000000000000000004 /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{test_sources}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		A00000000000000000000001 /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
                SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
                TARGETED_DEVICE_FAMILY = "1,2";
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
			}};
			name = Debug;
		}};
		A00000000000000000000002 /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				CLANG_ENABLE_OBJC_WEAK = YES;
				CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;
				CLANG_WARN_BOOL_CONVERSION = YES;
				CLANG_WARN_COMMA = YES;
				CLANG_WARN_CONSTANT_CONVERSION = YES;
				CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;
				CLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;
				CLANG_WARN_DOCUMENTATION_COMMENTS = YES;
				CLANG_WARN_EMPTY_BODY = YES;
				CLANG_WARN_ENUM_CONVERSION = YES;
				CLANG_WARN_INFINITE_RECURSION = YES;
				CLANG_WARN_INT_CONVERSION = YES;
				CLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;
				CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF = YES;
				CLANG_WARN_OBJC_LITERAL_CONVERSION = YES;
				CLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;
				CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER = YES;
				CLANG_WARN_RANGE_LOOP_ANALYSIS = YES;
				CLANG_WARN_STRICT_PROTOTYPES = YES;
				CLANG_WARN_SUSPICIOUS_MOVE = YES;
				CLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;
				CLANG_WARN_UNREACHABLE_CODE = YES;
				CLANG_WARN__DUPLICATE_METHOD_MATCH = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				GCC_WARN_64_TO_32_BIT_CONVERSION = YES;
				GCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;
				GCC_WARN_UNDECLARED_SELECTOR = YES;
				GCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;
				GCC_WARN_UNUSED_FUNCTION = YES;
				GCC_WARN_UNUSED_VARIABLE = YES;
				LOCALIZATION_PREFERS_STRING_CATALOGS = YES;
				MTL_ENABLE_DEBUG_INFO = NO;
				MTL_FAST_MATH = YES;
				SDKROOT = iphoneos;
                SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
                TARGETED_DEVICE_FAMILY = "1,2";
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
			}};
			name = Release;
		}};
		A00000000000000000000003 /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = SalmanCleanerMobile/SalmanCleanerMobile.entitlements;
				CODE_SIGN_IDENTITY = "iPhone Developer";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = SalmanCleanerMobile/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.salman.SalmanCleanerMobile;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.9;
			}};
			name = Debug;
		}};
		A00000000000000000000004 /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = SalmanCleanerMobile/SalmanCleanerMobile.entitlements;
				CODE_SIGN_IDENTITY = "iPhone Developer";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = NO;
				INFOPLIST_FILE = SalmanCleanerMobile/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.salman.SalmanCleanerMobile;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.9;
			}};
			name = Release;
		}};
		A00000000000000000000005 /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.salman.SalmanCleanerMobileTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.9;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SalmanCleanerMobile.app/SalmanCleanerMobile";
			}};
			name = Debug;
		}};
		A00000000000000000000006 /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				GENERATE_INFOPLIST_FILE = YES;
				IPHONEOS_DEPLOYMENT_TARGET = 16.0;
				MARKETING_VERSION = 1.0.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.salman.SalmanCleanerMobileTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = NO;
				SWIFT_VERSION = 5.9;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/SalmanCleanerMobile.app/SalmanCleanerMobile";
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		800000000000000000000001 /* Build configuration list for PBXProject "SalmanCleanerMobile" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				A00000000000000000000001 /* Debug */,
				A00000000000000000000002 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		800000000000000000000002 /* Build configuration list for PBXNativeTarget "SalmanCleanerMobile" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				A00000000000000000000003 /* Debug */,
				A00000000000000000000004 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		800000000000000000000003 /* Build configuration list for PBXNativeTarget "SalmanCleanerMobileTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				A00000000000000000000005 /* Debug */,
				A00000000000000000000006 /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {PROJECT_ID} /* Project object */;
}}
"""
    return pbx

def main():
    app_files, test_files = collect_swift_files()
    pbx = build_pbxproj(app_files, test_files)
    os.makedirs(PROJECT_DIR, exist_ok=True)
    with open(PBXPROJ, "w", encoding="utf-8") as f:
        f.write(pbx)
    
    scheme_dir = os.path.join(PROJECT_DIR, "xcshareddata", "xcschemes")
    os.makedirs(scheme_dir, exist_ok=True)
    scheme_path = os.path.join(scheme_dir, "SalmanCleanerMobile.xcscheme")
    with open(scheme_path, "w", encoding="utf-8") as handle:
        handle.write("""<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1500" version="1.3">
   <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
      <BuildActionEntries>
         <BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{0}" BuildableName="SalmanCleanerMobile.app" BlueprintName="SalmanCleanerMobile" ReferencedContainer="container:SalmanCleanerMobile.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.DebuggerFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES">
      <Testables>
         <TestableReference skipped="NO">
            <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{1}" BuildableName="SalmanCleanerMobileTests.xctest" BlueprintName="SalmanCleanerMobileTests" ReferencedContainer="container:SalmanCleanerMobile.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
</Scheme>""".format(APP_TARGET_ID, TEST_TARGET_ID))
    print(f"Generated {PBXPROJ} and scheme")

if __name__ == "__main__":
    main()
