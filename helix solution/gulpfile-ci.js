var gulp = require("gulp");
var msbuild = require("gulp-msbuild");
var util = require("gulp-util");
var foreach = require("gulp-foreach");
var rimrafDir = require("rimraf");
var rimraf = require("gulp-rimraf");
var runSequence = require("run-sequence");
var fs = require("fs");
var path = require("path");
var rename = require("gulp-rename");
var xmlpoke = require("xmlpoke");
var config = require("./gulpfile.js").config;
var unicorn = require("./scripts/unicorn.js");
var webTransformationsToBuildFrom = path.resolve("./ConfigsToBuildFrom/Website");
var webCDTransformationsToBuildFrom = path.resolve("./ConfigsToBuildFrom/WebsiteCD");
//var dataFolder = path.resolve("./Deploy/Data/App_Data");
var newUnicornRoot = "./Deploy/Website/App_Data/unicorn"
var tempWebsite = path.resolve("./Deploy/Website");
var tempWebsiteCD = path.resolve("./Deploy/WebsiteCD");
var websiteRoot = "./Website";
var unicornRoot = websiteRoot + "/App_Data/unicorn"

gulp.task("CI-Publish", function (callback) {
    //config.websiteRoot = path.resolve(websiteRoot);
    config.websiteRoot = tempWebsite;
    config.buildConfiguration = "Release";
    //config.runWebCompiler = "false";
    //config.runBundleMinify = "false";
    //fs.mkdirSync(config.websiteRoot);
    runSequence(
      "Build-Solution",
      "Publish-Foundation-Projects",
      "Publish-Feature-Projects",
      "Publish-Project-Projects", callback);
});

gulp.task("CI-Prepare-Package-Files", function (callback) {
    var excludeList = [
      config.websiteRoot + "\\bin\\{Sitecore,Lucene,Newtonsoft,System,Microsoft.Web.Infrastructure}*dll",
      //config.websiteRoot + "\\compilerconfig.json.defaults",
      config.websiteRoot + "\\packages.config",
      config.websiteRoot + "\\web.config.transform",
      //config.websiteRoot + "\\bundleconfig.json.bindings",
      config.websiteRoot + "\\App_Config\\Include\\Unicorn\\*.DataProvider.config",
      config.websiteRoot + "\\App_Config\\Include\\{Feature,Foundation,Project}\\z.*DevSettings.config",
      "!" + config.websiteRoot + "\\bin\\Sitecore.Support*dll",
      "!" + config.websiteRoot + "\\bin\\SSAB.GCP.{Feature,Foundation,Website}*dll"
    ];
    console.log(excludeList);

    return gulp.src(excludeList, { read: false }).pipe(rimraf({ force: true }));
});

gulp.task("CI-Copy-Items", function() {
    return gulp.src("./src/**/serialization/**/*.yml")
    .pipe(rename(function (path) {
        path.dirname = path.dirname.replace(/^(.+[\\\/])?(serialization)/, '');
    }))
    .pipe(gulp.dest(unicornRoot));
});

gulp.task("CI-Copy-Users", function () {
    return gulp.src("./src/**/users/**/*.user")
        .pipe(gulp.dest(unicornRoot));
});

gulp.task("CI-Copy-Roles", function () {
    return gulp.src("./src/**/roles/**/*.role")
        .pipe(gulp.dest(unicornRoot));
});

gulp.task("CI-Clean", function (callback) {
    rimrafDir.sync(path.resolve(websiteRoot));
    callback();
});

gulp.task("CI-Do-magic", function (callback) {
    runSequence(
        "CI-Clean",
        "CI-Publish",
        "CI-Prepare-Package-Files",
        "CI-Copy-Items",
        //"CI-Copy-Users",
        //"CI-Copy-Roles",
        callback);
});

gulp.task("CI-Copy-Items-For-Unicorn", function () {
    return gulp.src("./src/**/serialization/**/*.yml")
        .pipe(rename(function (path) {
            path.dirname = path.dirname.replace(/^(.+[\\\/])?(serialization)/, '');
        }))
        .pipe(gulp.dest(newUnicornRoot));
});

gulp.task("CI-And-Prepare-Files-CM-CD", function (callback) {
    runSequence(
        "CI-Clean-New",
        "CI-Copy-Configs-CM",
        "CI-Publish",
        "CI-Copy-Website-CD",
        "CI-Copy-Configs-CD",
        "CI-Prepare-Files-CM",
        "CI-Prepare-Files-CD",
        "CI-Apply-Xml-Transform-CM",
        "CI-Apply-Xml-Transform-CD",
        "CI-Copy-Items-For-Unicorn",
        callback);
});

gulp.task("CI-Clean-New", function (callback) {
    rimrafDir.sync(path.resolve("./Deploy"));
    callback();
});

gulp.task("CI-Copy-Configs-CM", function () {
    return gulp.src(webTransformationsToBuildFrom + "/**")
        .pipe(gulp.dest(tempWebsite));
});

gulp.task("CI-Copy-Website-CD", function () {
    return gulp.src(tempWebsite + "/**")
        .pipe(gulp.dest(tempWebsiteCD));
});

gulp.task("CI-Copy-Configs-CD", function () {
    return gulp.src(webCDTransformationsToBuildFrom + "/**")
        .pipe(gulp.dest(tempWebsiteCD));
});

gulp.task("CI-Prepare-Files-CM", function (callback) {
    var excludeList = [
        tempWebsite + "\\bin\\{Sitecore,Lucene,Newtonsoft,System,Microsoft.Web.Infrastructure}*dll",
        tempWebsite + "\\bin\\*.pdb",
        tempWebsite + "\\bin\\*dll.config",
        tempWebsite + "\\compilerconfig.json.defaults",
        tempWebsite + "\\packages.config",
        tempWebsite + "\\App_Config\\Include\\Unicorn\\*.DataProvider.config",
        tempWebsite + "\\App_Config\\Include\\{Feature,Foundation,Project}\\z.*DevSettings.config",
        tempWebsite + "\\App_Data\\*",
        "!" + tempWebsite + "\\bin\\Sitecore.Support*dll",
        "!" + tempWebsite + "\\bin\\SSAB.GCP.{Feature,Foundation,Project}*dll",
        tempWebsite + "\\bin\\{Sitecore.Foundation.Installer}*",
        tempWebsite + "\\App_Config\\Include\\Foundation\\Foundation.Installer.config",
        tempWebsite + "\\App_Config\\Include\\Foundation\\Foundation.SitecoreExtensions.ThreadPool.config",
        tempWebsite + "\\README.md",
        tempWebsite + "\\bin\\HtmlAgilityPack*dll",
        tempWebsite + "\\bin\\ICSharpCode.SharpZipLib*dll",
        tempWebsite + "\\bin\\Microsoft.Extensions.DependencyInjection*dll",
        tempWebsite + "\\bin\\MongoDB.Driver*dll",
        tempWebsite + "\\bin\\Microsoft.Web.XmlTransform*dll"
    ];
    console.log(excludeList);

    return gulp.src(excludeList, { read: false }).pipe(rimraf({ force: true }));
});

gulp.task("CI-Prepare-Files-CD", function (callback) {
    var excludeList = [
        tempWebsiteCD + "\\bin\\{Sitecore,Lucene,Newtonsoft,System,Microsoft.Web.Infrastructure}*dll",
        tempWebsiteCD + "\\bin\\*.pdb",
        tempWebsiteCD + "\\bin\\*dll.config",
        tempWebsiteCD + "\\compilerconfig.json.defaults",
        tempWebsiteCD + "\\packages.config",
        tempWebsiteCD + "\\App_Config\\Include\\{Feature,Foundation,Project}\\z.*DevSettings.config",
        tempWebsiteCD + "\\App_Data\\*",
        "!" + tempWebsiteCD + "\\bin\\Sitecore.Support*dll",
        "!" + tempWebsiteCD + "\\bin\\SSAB.GCP.{Feature,Foundation,Project}*dll",
        tempWebsiteCD + "\\bin\\{Sitecore.Foundation.Installer}*",
        tempWebsiteCD + "\\App_Config\\Include\\Rainbow",
        tempWebsiteCD + "\\App_Config\\Include\\Unicorn",
        tempWebsiteCD + "\\App_Config\\Include\\Rainbow*.config",
        tempWebsiteCD + "\\App_Config\\Include\\Unicorn*.config",
        tempWebsiteCD + "\\App_Config\\Include\\Foundation\\*.Serialization.config",
        tempWebsiteCD + "\\App_Config\\Include\\Feature\\*.Serialization.config",
        tempWebsiteCD + "\\App_Config\\Include\\Project\\*.Serialization.config",
        tempWebsiteCD + "\\App_Config\\Include\\DataFolderUnicornMaster.config",
        tempWebsiteCD + "\\App_Config\\Include\\Foundation\\Foundation.Installer.config",
        tempWebsiteCD + "\\App_Config\\Include\\Foundation\\Foundation.Serialization.Settings.config",
        tempWebsiteCD + "\\README.md",
        tempWebsiteCD + "\\bin\\HtmlAgilityPack*dll",
        tempWebsiteCD + "\\bin\\ICSharpCode.SharpZipLib*dll",
        tempWebsiteCD + "\\bin\\Microsoft.Extensions.DependencyInjection*dll",
        tempWebsiteCD + "\\bin\\MongoDB.Driver*dll",
        tempWebsiteCD + "\\bin\\Microsoft.Web.XmlTransform*dll",
        tempWebsiteCD + "\\bin\\Rainbow*dll",
        tempWebsiteCD + "\\bin\\Unicorn*dll",
        tempWebsiteCD + "\\bin\\Kamsar.WebConsole*dll"
    ];
    console.log(excludeList);

    return gulp.src(excludeList, { read: false }).pipe(rimraf({ force: true }));
});

gulp.task("CI-Apply-Xml-Transform-CM", function () {
    var layerPathFilters = ["./src/Foundation/**/*.cm.transform", "./src/Feature/**/*.cm.transform", "./src/Project/GlobalCustomerPortal/**/*.cm.transform", "!./src/**/obj/**/*.cm.transform", "!./src/**/bin/**/*.cm.transform"];
    return gulp.src(layerPathFilters)
        .pipe(foreach(function (stream, file) {

            var fileToTransform = file.path.replace(/.+code\\(.+)\.cm.transform/, "$1");
            util.log("Applying configuration transform: " + file.path);
            return gulp.src("./scripts/applytransform.targets")
                .pipe(msbuild({
                    targets: ["ApplyTransform"],
                    configuration: "Release",
                    logCommand: false,
                    verbosity: "minimal",
                    stdout: true,
                    errorOnFail: true,
                    maxcpucount: 0,
                    toolsVersion: config.buildToolsVersion,
                    properties: {
                        Platform: config.buildPlatform,
                        WebConfigToTransform: tempWebsite,
                        TransformFile: file.path,
                        FileToTransform: fileToTransform
                    }
                }));
        }));
});

gulp.task("CI-Apply-Xml-Transform-CD", function () {
    var layerPathFilters = ["./src/Foundation/**/*.cd.transform", "./src/Feature/**/*.cd.transform", "./src/Project/GlobalCustomerPortal/**/*.cd.transform", "!./src/**/obj/**/*.cd.transform", "!./src/**/bin/**/*.cd.transform"];
    return gulp.src(layerPathFilters)
        .pipe(foreach(function (stream, file) {

            var fileToTransform = file.path.replace(/.+code\\(.+)\.cd.transform/, "$1");
            util.log("Applying configuration transform: " + file.path);
            return gulp.src("./scripts/applytransform.targets")
                .pipe(msbuild({
                    targets: ["ApplyTransform"],
                    configuration: "Release",
                    logCommand: false,
                    verbosity: "minimal",
                    stdout: true,
                    errorOnFail: true,
                    maxcpucount: 0,
                    toolsVersion: config.buildToolsVersion,
                    properties: {
                        Platform: config.buildPlatform,
                        WebConfigToTransform: tempWebsiteCD,
                        TransformFile: file.path,
                        FileToTransform: fileToTransform
                    }
                }));
        }));
});

gulp.task("CI-Sync-Unicorn-CM", function (callback) {
    var options = {};
    options.siteHostName = habitat.getStageUrl();
    options.authenticationConfigFile = config.websiteRoot + "/App_config/Include/Unicorn.SharedSecret.config";

    unicorn(function () { return callback() }, options);
});