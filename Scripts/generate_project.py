#!/usr/bin/env python3
"""Generate the dependency-free Xcode project from the checked-in source tree."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "PairShift.xcodeproj"
PROJECT.mkdir(exist_ok=True)
objects = {}

report = ROOT / "Sources/PairShiftVerifier/verification-report.json"
if report.exists():
    paths = [entry["solution"] for entry in json.loads(report.read_text())]
    (ROOT / "UITests/Solutions.swift").write_text("// Generated from the solver verification report. Do not edit.\n" + "enum VerifiedPaths {\n    static let solutions: [[String]] = " + json.dumps(paths) + "\n}\n")

def ident(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def q(value):
    return json.dumps(str(value))

def obj(name, isa, fields):
    key = ident(name)
    objects[key] = f"isa = {isa}; {fields}"
    return key

def array(values):
    return "(" + ", ".join(values) + ")"

def config_list(name, settings):
    configs = []
    for mode in ["Debug", "Release"]:
        values = dict(settings)
        values.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O", "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym"})
        if mode == "Debug":
            values["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG $(inherited)"
            values["ENABLE_TESTABILITY"] = "YES"
            values["ONLY_ACTIVE_ARCH"] = "YES"
        fields = " ".join(f"{k} = {q(v)};" for k, v in sorted(values.items()))
        configs.append(obj(name + mode, "XCBuildConfiguration", f"name = {mode}; buildSettings = {{ {fields} }};"))
    return obj(name + "configs", "XCConfigurationList", f"buildConfigurations = {array(configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")

package = obj("localPackage", "XCLocalSwiftPackageReference", 'relativePath = ".";')
core_product = obj("coreProduct", "XCSwiftPackageProductDependency", f"package = {package}; productName = PairShiftCore;")
products = []
groups = []
targets = []
target_names = ["PairShift", "PairShiftTests", "PairShiftUITests"]
folders = ["App", "AppTests", "UITests"]
for index, (name, folder) in enumerate(zip(target_names, folders)):
    sources, resources, children = [], [], []
    files = sorted((ROOT / folder).rglob("*.swift"))
    if index == 0:
        files += sorted((ROOT / folder).rglob("*.xcassets"))
    for path in files:
        relative = path.relative_to(ROOT).as_posix()
        is_swift = path.suffix == ".swift"
        ref = obj("ref:" + relative, "PBXFileReference", f"lastKnownFileType = {'sourcecode.swift' if is_swift else 'folder.assetcatalog'}; path = {q(relative)}; sourceTree = SOURCE_ROOT;")
        build = obj("build:" + relative, "PBXBuildFile", f"fileRef = {ref};")
        children.append(ref)
        (sources if is_swift else resources).append(build)
    groups.append(obj(folder + "group", "PBXGroup", f"name = {q(folder)}; children = {array(children)}; sourceTree = \"<group>\";"))
    source_phase = obj(name + "sources", "PBXSourcesBuildPhase", f"buildActionMask = 2147483647; files = {array(sources)}; runOnlyForDeploymentPostprocessing = 0;")
    resource_phase = obj(name + "resources", "PBXResourcesBuildPhase", f"buildActionMask = 2147483647; files = {array(resources)}; runOnlyForDeploymentPostprocessing = 0;")
    links = []
    if index < 2:
        links.append(obj(name + "linkCore", "PBXBuildFile", f"productRef = {core_product};"))
    framework_phase = obj(name + "frameworks", "PBXFrameworksBuildPhase", f"buildActionMask = 2147483647; files = {array(links)}; runOnlyForDeploymentPostprocessing = 0;")
    product_path = name + (".app" if index == 0 else ".xctest")
    product = obj(name + "product", "PBXFileReference", f"explicitFileType = {'wrapper.application' if index == 0 else 'wrapper.cfbundle'}; includeInIndex = 0; path = {product_path}; sourceTree = BUILT_PRODUCTS_DIR;")
    products.append(product)
    settings = {
        "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "com.pairshift.game" + ("" if index == 0 else "." + name),
        "GENERATE_INFOPLIST_FILE": "YES", "SWIFT_VERSION": "6.0", "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "SDKROOT": "iphoneos", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator", "TARGETED_DEVICE_FAMILY": "1",
        "CODE_SIGN_STYLE": "Automatic", "MARKETING_VERSION": "0.1.0", "CURRENT_PROJECT_VERSION": "1",
        "SWIFT_STRICT_CONCURRENCY": "complete", "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
    }
    if index == 0:
        settings.update({"ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "INFOPLIST_KEY_CFBundleDisplayName": "PairShift", "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES", "INFOPLIST_KEY_UILaunchScreen_Generation": "YES", "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait", "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO"})
    elif index == 1:
        settings.update({"TEST_HOST": "$(BUILT_PRODUCTS_DIR)/PairShift.app/PairShift", "BUNDLE_LOADER": "$(TEST_HOST)"})
    else:
        settings["TEST_TARGET_NAME"] = "PairShift"
    deps = []
    if index:
        proxy = obj(name + "proxy", "PBXContainerItemProxy", f"containerPortal = {ident('project')}; proxyType = 1; remoteGlobalIDString = {ident('PairShifttarget')}; remoteInfo = PairShift;")
        deps.append(obj(name + "dependency", "PBXTargetDependency", f"target = {ident('PairShifttarget')}; targetProxy = {proxy};"))
    configs = config_list(name, settings)
    kind = "application" if index == 0 else ("bundle.unit-test" if index == 1 else "bundle.ui-testing")
    targets.append(obj(name + "target", "PBXNativeTarget", f"name = {name}; productName = {name}; productReference = {product}; productType = {q('com.apple.product-type.' + kind)}; buildConfigurationList = {configs}; buildPhases = {array([source_phase, framework_phase, resource_phase])}; buildRules = (); dependencies = {array(deps)}; packageProductDependencies = {array([core_product] if index < 2 else [])};"))

products_group = obj("products", "PBXGroup", f"children = {array(products)}; name = Products; sourceTree = \"<group>\";")
main_group = obj("mainGroup", "PBXGroup", f"children = {array(groups + [products_group])}; sourceTree = \"<group>\";")
project_configs = config_list("project", {"CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SWIFT_VERSION": "6.0"})
project = obj("project", "PBXProject", f"attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 2610; }}; buildConfigurationList = {project_configs}; compatibilityVersion = \"Xcode 14.0\"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main_group}; productRefGroup = {products_group}; projectDirPath = \"\"; projectRoot = \"\"; targets = {array(targets)}; packageReferences = ({package});")
lines = ["// !$*UTF8*$!", "{", "archiveVersion = 1;", "classes = {};", "objectVersion = 56;", "objects = {"]
lines += [f"{key} = {{ {value} }};" for key, value in objects.items()]
lines += ["};", f"rootObject = {project};", "}"]
(PROJECT / "project.pbxproj").write_text("\n".join(lines) + "\n")
schemes = PROJECT / "xcshareddata/xcschemes"
schemes.mkdir(parents=True, exist_ok=True)
def ref(index):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{targets[index]}" BuildableName="{target_names[index] + (".app" if index == 0 else ".xctest")}" BlueprintName="{target_names[index]}" ReferencedContainer="container:PairShift.xcodeproj"/>'
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2610" version="1.7">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref(0)}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{ref(1)}</TestableReference><TestableReference skipped="NO">{ref(2)}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref(0)}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">{ref(0)}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
(schemes / "PairShift.xcscheme").write_text(scheme)
print(f"Generated {PROJECT} with {sum(len(list((ROOT / f).rglob('*.swift'))) for f in folders)} Swift files")
