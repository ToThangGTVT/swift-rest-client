#!/usr/bin/env python3
import os
import uuid

def gen_id():
    return uuid.uuid4().hex[:24].upper()

def get_file_type(path):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".swift":
        return "sourcecode.swift"
    elif ext == ".xcassets":
        return "folder.assetcatalog"
    elif ext == ".icns":
        return "image.icns"
    elif ext == ".plist":
        return "text.plist.xml"
    return "text"

def main():
    proj_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    xcodeproj_dir = os.path.join(proj_dir, "CocoaRestClient.xcodeproj")
    os.makedirs(xcodeproj_dir, exist_ok=True)
    schemes_dir = os.path.join(xcodeproj_dir, "xcshareddata", "xcschemes")
    os.makedirs(schemes_dir, exist_ok=True)

    # We will build file references and build files
    file_refs = {}      # rel_path -> id
    build_files = {}    # rel_path -> id

    # Track files per target
    core_files = []
    app_files = []
    test_files = []
    resource_files = []

    # Map directories to structure
    # Hierarchy representation: { "dirs": { "sub_dir": {...} }, "files": [ "file1", ... ] }

    def scan_dir(abs_dir, rel_prefix=""):
        node = {"dirs": {}, "files": []}
        entries = sorted(os.listdir(abs_dir))
        for entry in entries:
            if entry.startswith(".") or entry == "project.xcworkspace":
                continue
            entry_abs = os.path.join(abs_dir, entry)
            entry_rel = os.path.join(rel_prefix, entry) if rel_prefix else entry
            
            if entry.endswith(".xcassets"):
                node["files"].append(entry)
                file_refs[entry_rel] = gen_id()
                build_files[entry_rel] = gen_id()
                resource_files.append(entry_rel)
            elif os.path.isdir(entry_abs):
                node["dirs"][entry] = scan_dir(entry_abs, entry_rel)
            else:
                if entry.endswith(".DS_Store"):
                    continue
                node["files"].append(entry)
                file_refs[entry_rel] = gen_id()
                build_files[entry_rel] = gen_id()
                if entry_rel.startswith("Sources/CocoaRestClientCore"):
                    core_files.append(entry_rel)
                elif entry_rel.startswith("Sources/CocoaRestClient"):
                    app_files.append(entry_rel)
                elif entry_rel.startswith("Tests"):
                    test_files.append(entry_rel)
                elif entry_rel.startswith("Resources"):
                    resource_files.append(entry_rel)
        return node

    app_tree = scan_dir(os.path.join(proj_dir, "Sources", "CocoaRestClient"), "Sources/CocoaRestClient")
    core_tree = scan_dir(os.path.join(proj_dir, "Sources", "CocoaRestClientCore"), "Sources/CocoaRestClientCore")
    tests_tree = scan_dir(os.path.join(proj_dir, "Tests", "CocoaRestClientTests"), "Tests/CocoaRestClientTests")
    resources_tree = scan_dir(os.path.join(proj_dir, "Resources"), "Resources")

    # IDs for objects
    proj_id = gen_id()
    main_group_id = gen_id()
    products_group_id = gen_id()

    app_target_id = gen_id()
    core_target_id = gen_id()
    tests_target_id = gen_id()

    app_product_id = gen_id()
    core_product_id = gen_id()
    tests_product_id = gen_id()

    app_sources_build_phase_id = gen_id()
    core_sources_build_phase_id = gen_id()
    tests_sources_build_phase_id = gen_id()

    app_resources_build_phase_id = gen_id()
    app_frameworks_build_phase_id = gen_id()
    core_frameworks_build_phase_id = gen_id()
    tests_frameworks_build_phase_id = gen_id()

    core_lib_build_file_in_app = gen_id()
    core_lib_build_file_in_tests = gen_id()

    app_target_dep_on_core = gen_id()
    tests_target_dep_on_core = gen_id()
    container_proxy_app = gen_id()
    container_proxy_tests = gen_id()

    config_list_proj = gen_id()
    config_list_app = gen_id()
    config_list_core = gen_id()
    config_list_tests = gen_id()

    proj_debug_config = gen_id()
    proj_release_config = gen_id()
    app_debug_config = gen_id()
    app_release_config = gen_id()
    core_debug_config = gen_id()
    core_release_config = gen_id()
    tests_debug_config = gen_id()
    tests_release_config = gen_id()

    # Section lists
    pbx_build_files = []
    pbx_file_refs = []
    pbx_groups = []

    # Populate BuildFiles
    for f in core_files:
        pbx_build_files.append(f"\t\t{build_files[f]} /* {os.path.basename(f)} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {os.path.basename(f)} */; }};")
    for f in app_files:
        pbx_build_files.append(f"\t\t{build_files[f]} /* {os.path.basename(f)} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {os.path.basename(f)} */; }};")
    for f in test_files:
        pbx_build_files.append(f"\t\t{build_files[f]} /* {os.path.basename(f)} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {os.path.basename(f)} */; }};")

    for f in resource_files:
        if f.endswith(".xcassets") or f.endswith(".icns"):
            pbx_build_files.append(f"\t\t{build_files[f]} /* {os.path.basename(f)} in Resources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f]} /* {os.path.basename(f)} */; }};")

    pbx_build_files.append(f"\t\t{core_lib_build_file_in_app} /* libCocoaRestClientCore.a in Frameworks */ = {{isa = PBXBuildFile; fileRef = {core_product_id} /* libCocoaRestClientCore.a */; }};")
    pbx_build_files.append(f"\t\t{core_lib_build_file_in_tests} /* libCocoaRestClientCore.a in Frameworks */ = {{isa = PBXBuildFile; fileRef = {core_product_id} /* libCocoaRestClientCore.a */; }};")

    # Populate FileRefs
    for rel_path, fid in file_refs.items():
        base_name = os.path.basename(rel_path)
        ftype = get_file_type(rel_path)
        pbx_file_refs.append(f"\t\t{fid} /* {base_name} */ = {{isa = PBXFileReference; lastKnownFileType = {ftype}; path = \"{base_name}\"; sourceTree = \"<group>\"; }};")

    pbx_file_refs.append(f"\t\t{app_product_id} /* CocoaRestClient.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = CocoaRestClient.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    pbx_file_refs.append(f"\t\t{core_product_id} /* libCocoaRestClientCore.a */ = {{isa = PBXFileReference; explicitFileType = archive.ar; includeInIndex = 0; path = libCocoaRestClientCore.a; sourceTree = BUILT_PRODUCTS_DIR; }};")
    pbx_file_refs.append(f"\t\t{tests_product_id} /* CocoaRestClientTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = CocoaRestClientTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};")

    # Function to recursively generate PBXGroups
    def generate_pbx_group(group_name, group_path, tree_node, rel_dir):
        group_id = gen_id()
        child_ids = []

        # Subdirectories
        for sub_name, sub_node in sorted(tree_node["dirs"].items()):
            sub_rel = os.path.join(rel_dir, sub_name) if rel_dir else sub_name
            sub_group_id = generate_pbx_group(sub_name, sub_name, sub_node, sub_rel)
            child_ids.append((sub_group_id, sub_name))

        # Files
        for fname in sorted(tree_node["files"]):
            f_rel = os.path.join(rel_dir, fname) if rel_dir else fname
            fid = file_refs[f_rel]
            child_ids.append((fid, fname))

        children_str = "\n".join([f"\t\t\t\t{cid} /* {cname} */," for cid, cname in child_ids])
        
        path_attr = f'path = "{group_path}"; ' if group_path else ""
        name_attr = f'name = "{group_name}"; ' if group_name and group_name != group_path else ""

        pbx_groups.append(f"""\t\t{group_id} /* {group_name} */ = {{
			isa = PBXGroup;
			children = (
{children_str}
			);
			{name_attr}{path_attr}sourceTree = "<group>";
		}};""")
        return group_id

    app_group_id = generate_pbx_group("CocoaRestClient", "Sources/CocoaRestClient", app_tree, "Sources/CocoaRestClient")
    core_group_id = generate_pbx_group("CocoaRestClientCore", "Sources/CocoaRestClientCore", core_tree, "Sources/CocoaRestClientCore")
    tests_group_id = generate_pbx_group("CocoaRestClientTests", "Tests/CocoaRestClientTests", tests_tree, "Tests/CocoaRestClientTests")
    resources_group_id = generate_pbx_group("Resources", "Resources", resources_tree, "Resources")

    # Products Group
    pbx_groups.append(f"""\t\t{products_group_id} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{app_product_id} /* CocoaRestClient.app */,
				{core_product_id} /* libCocoaRestClientCore.a */,
				{tests_product_id} /* CocoaRestClientTests.xctest */,
			);
			name = Products;
			sourceTree = "<group>";
		}};""")

    # Main Group
    pbx_groups.append(f"""\t\t{main_group_id} = {{
			isa = PBXGroup;
			children = (
				{app_group_id} /* CocoaRestClient */,
				{core_group_id} /* CocoaRestClientCore */,
				{resources_group_id} /* Resources */,
				{tests_group_id} /* CocoaRestClientTests */,
				{products_group_id} /* Products */,
			);
			sourceTree = "<group>";
		}};""")

    pbxproj_content = f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(pbx_build_files)}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		{container_proxy_app} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {proj_id} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {core_target_id};
			remoteInfo = CocoaRestClientCore;
		}};
		{container_proxy_tests} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {proj_id} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {core_target_id};
			remoteInfo = CocoaRestClientCore;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXFileReference section */
{chr(10).join(pbx_file_refs)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{core_frameworks_build_phase_id} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{app_frameworks_build_phase_id} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{core_lib_build_file_in_app} /* libCocoaRestClientCore.a in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{tests_frameworks_build_phase_id} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{core_lib_build_file_in_tests} /* libCocoaRestClientCore.a in Frameworks */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
{chr(10).join(pbx_groups)}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{core_target_id} /* CocoaRestClientCore */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {config_list_core} /* Build configuration list for PBXNativeTarget "CocoaRestClientCore" */;
			buildPhases = (
				{core_sources_build_phase_id} /* Sources */,
				{core_frameworks_build_phase_id} /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = CocoaRestClientCore;
			productName = CocoaRestClientCore;
			productReference = {core_product_id} /* libCocoaRestClientCore.a */;
			productType = "com.apple.product-type.library.static";
		}};
		{app_target_id} /* CocoaRestClient */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {config_list_app} /* Build configuration list for PBXNativeTarget "CocoaRestClient" */;
			buildPhases = (
				{app_sources_build_phase_id} /* Sources */,
				{app_frameworks_build_phase_id} /* Frameworks */,
				{app_resources_build_phase_id} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{app_target_dep_on_core} /* PBXTargetDependency */,
			);
			name = CocoaRestClient;
			productName = CocoaRestClient;
			productReference = {app_product_id} /* CocoaRestClient.app */;
			productType = "com.apple.product-type.application";
		}};
		{tests_target_id} /* CocoaRestClientTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {config_list_tests} /* Build configuration list for PBXNativeTarget "CocoaRestClientTests" */;
			buildPhases = (
				{tests_sources_build_phase_id} /* Sources */,
				{tests_frameworks_build_phase_id} /* Frameworks */,
			);
			buildRules = (
			);
			dependencies = (
				{tests_target_dep_on_core} /* PBXTargetDependency */,
			);
			name = CocoaRestClientTests;
			productName = CocoaRestClientTests;
			productReference = {tests_product_id} /* CocoaRestClientTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{proj_id} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				TargetAttributes = {{
					{app_target_id} = {{
						CreatedOnToolsVersion = 15.0;
					}};
					{core_target_id} = {{
						CreatedOnToolsVersion = 15.0;
					}};
					{tests_target_id} = {{
						CreatedOnToolsVersion = 15.0;
					}};
				}};
			}};
			buildConfigurationList = {config_list_proj} /* Build configuration list for PBXProject "CocoaRestClient" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {main_group_id};
			productRefGroup = {products_group_id} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{core_target_id} /* CocoaRestClientCore */,
				{app_target_id} /* CocoaRestClient */,
				{tests_target_id} /* CocoaRestClientTests */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{app_resources_build_phase_id} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{build_files['Resources/Assets.xcassets']} /* Assets.xcassets in Resources */,
				{build_files['Resources/AppIcon.icns']} /* AppIcon.icns in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{core_sources_build_phase_id} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{chr(10).join([f"\t\t\t\t{build_files[f]} /* {os.path.basename(f)} in Sources */," for f in core_files])}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{app_sources_build_phase_id} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{chr(10).join([f"\t\t\t\t{build_files[f]} /* {os.path.basename(f)} in Sources */," for f in app_files])}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{tests_sources_build_phase_id} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{chr(10).join([f"\t\t\t\t{build_files[f]} /* {os.path.basename(f)} in Sources */," for f in test_files])}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{app_target_dep_on_core} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {core_target_id} /* CocoaRestClientCore */;
			targetProxy = {container_proxy_app} /* PBXContainerItemProxy */;
		}};
		{tests_target_dep_on_core} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {core_target_id} /* CocoaRestClientCore */;
			targetProxy = {container_proxy_tests} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		{proj_debug_config} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				MTL_FAST_MATH = YES;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{proj_release_config} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_OPTIMIZATION_LEVEL = s;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_FAST_MATH = YES;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{core_debug_config} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				COMBINE_HIDPI_IMAGES = YES;
				DEFINES_MODULE = YES;
				EXECUTABLE_PREFIX = "lib";
				MACH_O_TYPE = staticlib;
				PRODUCT_BUNDLE_IDENTIFIER = org.restlesscode.CocoaRestClientCore;
				PRODUCT_NAME = "$(TARGET_NAME:c99extidentifier)";
				SKIP_INSTALL = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{core_release_config} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				COMBINE_HIDPI_IMAGES = YES;
				DEFINES_MODULE = YES;
				EXECUTABLE_PREFIX = "lib";
				MACH_O_TYPE = staticlib;
				PRODUCT_BUNDLE_IDENTIFIER = org.restlesscode.CocoaRestClientCore;
				PRODUCT_NAME = "$(TARGET_NAME:c99extidentifier)";
				SKIP_INSTALL = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{app_debug_config} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				ENABLE_HARDENED_RUNTIME = NO;
				INFOPLIST_FILE = "Resources/Info.plist";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = org.restlesscode.CocoaRestClient;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{app_release_config} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				ENABLE_HARDENED_RUNTIME = NO;
				INFOPLIST_FILE = "Resources/Info.plist";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				PRODUCT_BUNDLE_IDENTIFIER = org.restlesscode.CocoaRestClient;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{tests_debug_config} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				ENABLE_HARDENED_RUNTIME = NO;
				GENERATE_INFOPLIST_FILE = YES;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@loader_path/../Frameworks",
				);
				MACH_O_TYPE = mh_bundle;
				OTHER_CODE_SIGN_FLAGS = "--deep";
				PRODUCT_BUNDLE_IDENTIFIER = org.restlesscode.CocoaRestClientTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				WRAPPER_EXTENSION = xctest;
			}};
			name = Debug;
		}};
		{tests_release_config} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_IDENTITY = "-";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				ENABLE_HARDENED_RUNTIME = NO;
				GENERATE_INFOPLIST_FILE = YES;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@loader_path/../Frameworks",
				);
				MACH_O_TYPE = mh_bundle;
				OTHER_CODE_SIGN_FLAGS = "--deep";
				PRODUCT_BUNDLE_IDENTIFIER = org.restlesscode.CocoaRestClientTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				WRAPPER_EXTENSION = xctest;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{config_list_proj} /* Build configuration list for PBXProject "CocoaRestClient" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{proj_debug_config} /* Debug */,
				{proj_release_config} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{config_list_core} /* Build configuration list for PBXNativeTarget "CocoaRestClientCore" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{core_debug_config} /* Debug */,
				{core_release_config} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{config_list_app} /* Build configuration list for PBXNativeTarget "CocoaRestClient" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{app_debug_config} /* Debug */,
				{app_release_config} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{config_list_tests} /* Build configuration list for PBXNativeTarget "CocoaRestClientTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{tests_debug_config} /* Debug */,
				{tests_release_config} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */

	}};
	rootObject = {proj_id} /* Project object */;
}}
"""

    pbxproj_path = os.path.join(xcodeproj_dir, "project.pbxproj")
    with open(pbxproj_path, "w", encoding="utf-8") as f:
        f.write(pbxproj_content)

    scheme_content = f"""<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{app_target_id}"
               BuildableName = "CocoaRestClient.app"
               BlueprintName = "CocoaRestClient"
               ReferencedContainer = "container:CocoaRestClient.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
         <TestableReference
            skipped = "NO">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "{tests_target_id}"
               BuildableName = "CocoaRestClientTests.xctest"
               BlueprintName = "CocoaRestClientTests"
               ReferencedContainer = "container:CocoaRestClient.xcodeproj">
            </BuildableReference>
         </TestableReference>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "CocoaRestClient.app"
            BlueprintName = "CocoaRestClient"
            ReferencedContainer = "container:CocoaRestClient.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "{app_target_id}"
            BuildableName = "CocoaRestClient.app"
            BlueprintName = "CocoaRestClient"
            ReferencedContainer = "container:CocoaRestClient.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""
    scheme_path = os.path.join(schemes_dir, "CocoaRestClient.xcscheme")
    with open(scheme_path, "w", encoding="utf-8") as f:
        f.write(scheme_content)

    print(f"Generated clean PBXGroup hierarchy in {pbxproj_path}")

if __name__ == "__main__":
    main()
